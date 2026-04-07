import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

enum SoundScene {
  conversation,
  crowd,
  musicEvent,
  traffic,
  machinery,
  quietIndoor,
}

extension SoundSceneLabel on SoundScene {
  String get label {
    switch (this) {
      case SoundScene.conversation:
        return 'Conversation';
      case SoundScene.crowd:
        return 'Crowd';
      case SoundScene.musicEvent:
        return 'Music / Event';
      case SoundScene.traffic:
        return 'Traffic';
      case SoundScene.machinery:
        return 'Machinery';
      case SoundScene.quietIndoor:
        return 'Quiet Indoor';
    }
  }
}

class ScenePrediction {
  final SoundScene scene;
  final String label;
  final double confidence;
  final bool waitingForAudio;
  final bool isManualOverride;
  final bool isStable;
  final double db;
  final double rmsDbFs;
  final Map<String, double> features;
  final Map<String, double> rawScores;
  final Map<String, double> smoothedScores;

  const ScenePrediction({
    required this.scene,
    required this.label,
    required this.confidence,
    required this.waitingForAudio,
    required this.isManualOverride,
    required this.isStable,
    required this.db,
    required this.rmsDbFs,
    required this.features,
    required this.rawScores,
    required this.smoothedScores,
  });

  factory ScenePrediction.waiting() {
    return const ScenePrediction(
      scene: SoundScene.quietIndoor,
      label: 'Waiting for audio',
      confidence: 0.0,
      waitingForAudio: true,
      isManualOverride: false,
      isStable: false,
      db: 0.0,
      rmsDbFs: -120.0,
      features: {},
      rawScores: {},
      smoothedScores: {},
    );
  }
}

class SoundClassificationResult {
  final double currentDb;
  final double smoothedDb;
  final String label;
  final String rawLabel;
  final String scene;
  final double confidence;
  final double rawConfidence;
  final int inferenceTimeMs;
  final bool isStable;
  final List<MapEntry<String, double>> topPredictions;

  const SoundClassificationResult({
    required this.currentDb,
    required this.smoothedDb,
    required this.label,
    required this.rawLabel,
    required this.scene,
    required this.confidence,
    required this.rawConfidence,
    required this.inferenceTimeMs,
    required this.isStable,
    required this.topPredictions,
  });
}

class SoundClassifierService {
  SoundClassifierService._internal();

  static final SoundClassifierService instance =
      SoundClassifierService._internal();

  factory SoundClassifierService() => instance;

  final AudioRecorder _recorder = AudioRecorder();

  final StreamController<ScenePrediction> _predictionController =
      StreamController<ScenePrediction>.broadcast();

  final StreamController<SoundClassificationResult> _legacyController =
      StreamController<SoundClassificationResult>.broadcast();

  Stream<ScenePrediction> get predictionStream => _predictionController.stream;

  ScenePrediction? _latestPrediction;
  ScenePrediction? get latestPrediction => _latestPrediction;

  String? _manualOverrideLabel;
  String? get manualOverrideLabel => _manualOverrideLabel;

  final Map<SoundScene, double> _emaScores = {
    for (final scene in SoundScene.values) scene: 1 / SoundScene.values.length,
  };

  StreamSubscription<Uint8List>? _micSubscription;
  Timer? _noAudioTimer;
  DateTime? _lastChunkAt;

  final List<int> _pendingBytes = <int>[];

  List<double>? _previousSpectrum;
  SoundScene? _stableScene;
  SoundScene? _lastWinningScene;
  int _winningSceneStreak = 0;

  bool _isListening = false;
  int _sampleRate = 16000;
  double _smoothedDb = 0.0;

  DateTime? _lastLegacyEmitAt;
  String? _lastLegacyLabel;
  double _lastLegacySmoothedDb = 0.0;
  bool _hasLegacyEmit = false;

  static const double _emaAlpha = 0.14;
  static const int _requiredFramesToSwitch = 5;
  static const double _dbSmoothingAlpha = 0.18;
  static const int _targetChunkBytes = 2048;

  static const Duration _minSceneHold = Duration(milliseconds: 1800);
  static const double _sceneSwitchMinTopScore = 0.26;
  static const double _sceneSwitchMinMargin = 0.04;
  static const Duration _legacyEmitMinInterval = Duration(milliseconds: 220);

  DateTime? _lastSceneChangeAt;

  Future<void> initialize() async {
    final hasPermission = await _recorder.hasPermission();
    debugPrint('Record package mic permission: $hasPermission');

    if (!hasPermission) {
      throw Exception('Microphone permission not granted');
    }
  }

  Future<Stream<SoundClassificationResult>> startListening({
    int sampleRate = 16000,
  }) async {
    await initialize();

    if (_isListening) {
      return _legacyController.stream;
    }

    _sampleRate = sampleRate;
    _pendingBytes.clear();
    _smoothedDb = 0.0;
    _isListening = true;
    _lastChunkAt = null;

    reset(keepManualOverride: true);
    _emitWaiting();

    final config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: sampleRate,
      numChannels: 1,
      autoGain: true,
      echoCancel: true,
      noiseSuppress: true,
    );

    debugPrint(
      'Starting mic stream: sampleRate=$sampleRate, channels=1, encoder=pcm16bits',
    );

    final stream = await _recorder.startStream(config);

    _noAudioTimer?.cancel();
    _noAudioTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_isListening) return;

      final last = _lastChunkAt;
      if (last == null ||
          DateTime.now().difference(last) > const Duration(seconds: 2)) {
        debugPrint('No microphone chunks received in the last 2 seconds');
      }
    });

    _micSubscription = stream.listen(
      (data) {
        _lastChunkAt = DateTime.now();
        debugPrint('Mic chunk received: ${data.length} bytes');
        _onMicData(data);
      },
      onError: (error, stackTrace) {
        debugPrint('Mic stream error: $error');
        _legacyController.addError(error, stackTrace);
        _predictionController.addError(error, stackTrace);
      },
      onDone: () {
        debugPrint('Mic stream done');
        _isListening = false;
      },
      cancelOnError: false,
    );

    return _legacyController.stream;
  }

  Future<void> stop() async {
    _isListening = false;

    _noAudioTimer?.cancel();
    _noAudioTimer = null;

    await _micSubscription?.cancel();
    _micSubscription = null;

    try {
      await _recorder.stop();
    } catch (_) {}

    _pendingBytes.clear();
    _smoothedDb = 0.0;
    _lastChunkAt = null;

    _lastLegacyEmitAt = null;
    _lastLegacyLabel = null;
    _lastLegacySmoothedDb = 0.0;
    _hasLegacyEmit = false;
  }

  void dispose() {
    _isListening = false;
    _noAudioTimer?.cancel();
    _noAudioTimer = null;
    _micSubscription?.cancel();
    _micSubscription = null;
    _pendingBytes.clear();
    _smoothedDb = 0.0;

    _lastLegacyEmitAt = null;
    _lastLegacyLabel = null;
    _lastLegacySmoothedDb = 0.0;
    _hasLegacyEmit = false;

    try {
      _recorder.dispose();
    } catch (_) {}

    try {
      _predictionController.close();
    } catch (_) {}

    try {
      _legacyController.close();
    } catch (_) {}
  }

  void reset({bool keepManualOverride = false}) {
    if (!keepManualOverride) {
      _manualOverrideLabel = null;
    }

    _previousSpectrum = null;
    _stableScene = null;
    _lastWinningScene = null;
    _winningSceneStreak = 0;
    _lastSceneChangeAt = null;

    _lastLegacyEmitAt = null;
    _lastLegacyLabel = null;
    _lastLegacySmoothedDb = 0.0;
    _hasLegacyEmit = false;

    for (final scene in SoundScene.values) {
      _emaScores[scene] = 1 / SoundScene.values.length;
    }

    _latestPrediction = null;
  }

  void setManualOverride(String? label) {
    if (label == null || label.trim().isEmpty || label == 'Auto') {
      _manualOverrideLabel = null;
      return;
    }

    final normalized = label.trim().toLowerCase();
    if (normalized == 'music' || normalized == 'music / event') {
      _manualOverrideLabel = SoundScene.musicEvent.label;
      return;
    }

    for (final scene in SoundScene.values) {
      if (scene.label.toLowerCase() == normalized) {
        _manualOverrideLabel = scene.label;
        return;
      }
    }
  }

  void _onMicData(Uint8List data) {
    if (!_isListening) return;

    _pendingBytes.addAll(data);

    while (_pendingBytes.length >= _targetChunkBytes) {
      final chunk = Uint8List.fromList(
        _pendingBytes.sublist(0, _targetChunkBytes),
      );
      _pendingBytes.removeRange(0, _targetChunkBytes);

      final rawDb = _estimateDbFromPcm16Bytes(chunk);
      _smoothedDb = _smoothedDb <= 0
          ? rawDb
          : (_smoothedDb + (_dbSmoothingAlpha * (rawDb - _smoothedDb)));

      final stopwatch = Stopwatch()..start();
      final prediction = _classifyPcm16Bytes(
        chunk,
        sampleRate: _sampleRate,
        currentDb: _smoothedDb,
      );
      stopwatch.stop();

      _emitPrediction(
        prediction,
        rawDb: rawDb,
        smoothedDb: _smoothedDb,
        inferenceTimeMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  ScenePrediction processPcm16Bytes(
    Uint8List bytes, {
    int sampleRate = 16000,
    double? currentDb,
  }) {
    final stopwatch = Stopwatch()..start();
    final prediction = _classifyPcm16Bytes(
      bytes,
      sampleRate: sampleRate,
      currentDb: currentDb,
    );
    stopwatch.stop();

    final rawDb = currentDb ?? _estimateDbFromPcm16Bytes(bytes);

    _emitPrediction(
      prediction,
      rawDb: rawDb,
      smoothedDb: currentDb ?? rawDb,
      inferenceTimeMs: stopwatch.elapsedMilliseconds,
    );

    return prediction;
  }

  ScenePrediction processInt16Samples(
    List<int> pcm16, {
    int sampleRate = 16000,
    double? currentDb,
  }) {
    final stopwatch = Stopwatch()..start();
    final prediction = _classifyInt16Samples(
      pcm16,
      sampleRate: sampleRate,
      currentDb: currentDb,
    );
    stopwatch.stop();

    final rawDb = currentDb ?? _estimateDbFromInt16Samples(pcm16);

    _emitPrediction(
      prediction,
      rawDb: rawDb,
      smoothedDb: currentDb ?? rawDb,
      inferenceTimeMs: stopwatch.elapsedMilliseconds,
    );

    return prediction;
  }

  void _emitWaiting() {
    final waiting = ScenePrediction.waiting();
    _latestPrediction = waiting;
    _predictionController.add(waiting);

    _lastLegacyEmitAt = DateTime.now();
    _lastLegacyLabel = 'Waiting for audio';
    _lastLegacySmoothedDb = 0.0;
    _hasLegacyEmit = true;

    _legacyController.add(
      const SoundClassificationResult(
        currentDb: 0,
        smoothedDb: 0,
        label: 'Waiting for audio',
        rawLabel: 'Waiting for audio',
        scene: 'Unknown',
        confidence: 0,
        rawConfidence: 0,
        inferenceTimeMs: 0,
        isStable: false,
        topPredictions: [],
      ),
    );
  }

  void _emitPrediction(
    ScenePrediction prediction, {
    required double rawDb,
    required double smoothedDb,
    required int inferenceTimeMs,
  }) {
    _latestPrediction = prediction;
    _predictionController.add(prediction);

    final rawSorted = prediction.rawScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final smoothSorted = prediction.smoothedScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final rawTop = rawSorted.isNotEmpty
        ? rawSorted.first
        : const MapEntry<String, double>('Waiting for audio', 0.0);

    final label = prediction.waitingForAudio
        ? 'Waiting for audio'
        : prediction.label;

    final now = DateTime.now();
    final labelChanged = _lastLegacyLabel != label;
    final dueByTime =
        _lastLegacyEmitAt == null ||
        now.difference(_lastLegacyEmitAt!) >= _legacyEmitMinInterval;
    final dueByDb =
        !_hasLegacyEmit || (smoothedDb - _lastLegacySmoothedDb).abs() >= 1.5;

    if (!labelChanged && !dueByTime && !dueByDb) {
      return;
    }

    _lastLegacyEmitAt = now;
    _lastLegacyLabel = label;
    _lastLegacySmoothedDb = smoothedDb;
    _hasLegacyEmit = true;

    _legacyController.add(
      SoundClassificationResult(
        currentDb: rawDb,
        smoothedDb: smoothedDb,
        label: label,
        rawLabel: prediction.waitingForAudio ? 'Waiting for audio' : rawTop.key,
        scene: prediction.waitingForAudio ? 'Unknown' : prediction.scene.label,
        confidence: prediction.confidence,
        rawConfidence: prediction.waitingForAudio ? 0.0 : rawTop.value,
        inferenceTimeMs: inferenceTimeMs,
        isStable: prediction.isStable,
        topPredictions: smoothSorted.take(3).toList(),
      ),
    );
  }

  ScenePrediction _classifyPcm16Bytes(
    Uint8List bytes, {
    int sampleRate = 16000,
    double? currentDb,
  }) {
    if (bytes.length < 2) {
      return ScenePrediction.waiting();
    }

    final bd = ByteData.sublistView(bytes);
    final samples = <int>[];
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      samples.add(bd.getInt16(i, Endian.little));
    }

    return _classifyInt16Samples(
      samples,
      sampleRate: sampleRate,
      currentDb: currentDb,
    );
  }

  ScenePrediction _classifyInt16Samples(
    List<int> pcm16, {
    int sampleRate = 16000,
    double? currentDb,
  }) {
    if (pcm16.length < 256) {
      return ScenePrediction.waiting();
    }

    final normalized = _normalizePcm16(pcm16);
    final features = _extractFeatures(
      normalized,
      sampleRate: sampleRate,
      currentDb: currentDb,
    );

    if (features.rms < 0.0008 && (features.db < 28 || features.db == 0)) {
      final quietScores = {
        SoundScene.conversation: 0.03,
        SoundScene.crowd: 0.02,
        SoundScene.musicEvent: 0.02,
        SoundScene.traffic: 0.03,
        SoundScene.machinery: 0.04,
        SoundScene.quietIndoor: 0.86,
      };
      return _finalizePrediction(
        features: features,
        rawSceneScores: quietScores,
      );
    }

    final rawScores = _scoreScenes(features);
    return _finalizePrediction(features: features, rawSceneScores: rawScores);
  }

  ScenePrediction _finalizePrediction({
    required _AudioFeatures features,
    required Map<SoundScene, double> rawSceneScores,
  }) {
    final normalizedRaw = _normalizeSceneScores(rawSceneScores);

    for (final scene in SoundScene.values) {
      final prev = _emaScores[scene] ?? 0.0;
      final next = normalizedRaw[scene] ?? 0.0;
      _emaScores[scene] = prev + (_emaAlpha * (next - prev));
    }

    final normalizedSmooth = _normalizeSceneScores(_emaScores);

    final sorted = normalizedSmooth.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = sorted.first;
    final second = sorted.length > 1 ? sorted[1].value : 0.0;
    final margin = (top.value - second).clamp(0.0, 1.0);
    final now = DateTime.now();

    if (_lastWinningScene == top.key) {
      _winningSceneStreak += 1;
    } else {
      _lastWinningScene = top.key;
      _winningSceneStreak = 1;
    }

    bool switched = false;

    if (_stableScene == null) {
      _stableScene = top.key;
      _lastSceneChangeAt = now;
      switched = true;
    } else if (top.key != _stableScene) {
      final stableScore = normalizedSmooth[_stableScene!] ?? 0.0;
      final heldLongEnough =
          _lastSceneChangeAt == null ||
          now.difference(_lastSceneChangeAt!) >= _minSceneHold;

      final strongEnough =
          top.value >= _sceneSwitchMinTopScore &&
          margin >= _sceneSwitchMinMargin;

      final stableCollapsed = stableScore <= 0.16 && top.value >= 0.20;

      if (heldLongEnough &&
          _winningSceneStreak >= _requiredFramesToSwitch &&
          (strongEnough || stableCollapsed)) {
        _stableScene = top.key;
        _lastSceneChangeAt = now;
        switched = true;
      }
    }

    final chosenScene = _stableScene ?? top.key;
    final chosenScore = normalizedSmooth[chosenScene] ?? 0.0;

    SoundScene finalScene = chosenScene;
    double finalConfidence = _clamp01((chosenScore * 0.90) + (margin * 0.70));

    bool isManual = false;
    if (_manualOverrideLabel != null) {
      final manualScene = _labelToScene(_manualOverrideLabel!);
      if (manualScene != null) {
        finalScene = manualScene;
        finalConfidence = 1.0;
        isManual = true;
      }
    }

    return ScenePrediction(
      scene: finalScene,
      label: finalScene.label,
      confidence: finalConfidence,
      waitingForAudio: false,
      isManualOverride: isManual,
      isStable: !switched,
      db: features.db,
      rmsDbFs: features.rmsDbFs,
      features: {
        'rms': features.rms,
        'db': features.db,
        'rmsDbFs': features.rmsDbFs,
        'zcr': features.zcr,
        'energyVar': features.energyVar,
        'centroidHz': features.centroidHz,
        'rolloffHz': features.rolloffHz,
        'flatness': features.flatness,
        'speechPeriodicity': features.speechPeriodicity,
        'humPeriodicity': features.humPeriodicity,
        'tonalProminence': features.tonalProminence,
        'spectralFlux': features.spectralFlux,
        'broadbandness': features.broadbandness,
        'lowRatio': features.lowRatio,
        'lowMidRatio': features.lowMidRatio,
        'midRatio': features.midRatio,
        'highRatio': features.highRatio,
      },
      rawScores: {for (final e in normalizedRaw.entries) e.key.label: e.value},
      smoothedScores: {
        for (final e in normalizedSmooth.entries) e.key.label: e.value,
      },
    );
  }

  Map<SoundScene, double> _scoreScenes(_AudioFeatures f) {
    final db = f.db;
    final steady = 1.0 - f.energyVar;
    final lowNoise = 1.0 - f.highRatio;
    final speechy = f.speechPeriodicity;
    final hummish = math.max(f.humPeriodicity, f.tonalProminence * 0.9);

    final conversationDb = _triangle(db, 44, 60, 76);
    final crowdDb = _triangle(db, 52, 68, 88);
    final musicDb = _triangle(db, 58, 78, 100);
    final trafficDb = _triangle(db, 54, 72, 92);
    final machineDb = _triangle(db, 56, 76, 98);
    final quietDb = 1.0 - _smoothStep(38, 54, db);

    final speechBoost = _clamp01((speechy - 0.28) / 0.45);
    final humBoost = _clamp01((hummish - 0.22) / 0.55);
    final steadyBoost = _clamp01((steady - 0.40) / 0.60);
    final fluxBoost = _clamp01((f.spectralFlux - 0.05) / 0.30);
    final broadbandBoost = _clamp01((f.broadbandness - 0.30) / 0.55);
    final flatBoost = _clamp01((f.flatness - 0.18) / 0.45);
    final lowBoost = _clamp01((f.lowRatio - 0.18) / 0.35);
    final lowMidBoost = _clamp01((f.lowMidRatio - 0.18) / 0.35);
    final midBoost = _clamp01((f.midRatio - 0.18) / 0.30);
    final highBoost = _clamp01((f.highRatio - 0.12) / 0.35);

    final balancedSpectrum = _clamp01(
      1.0 -
          ((f.lowRatio - 0.28).abs() +
                  (f.lowMidRatio - 0.24).abs() +
                  (f.midRatio - 0.24).abs() +
                  (f.highRatio - 0.24).abs()) *
              1.2,
    );

    double conversation =
        0.34 * conversationDb +
        0.34 * speechBoost +
        0.12 * midBoost +
        0.08 * (1.0 - f.flatness) +
        0.07 * _clamp01((f.energyVar - 0.08) / 0.28) +
        0.05 * _clamp01((1.0 - f.lowRatio) * 1.2);

    double crowd =
        0.30 * crowdDb +
        0.18 * flatBoost +
        0.16 * broadbandBoost +
        0.14 * fluxBoost +
        0.12 * _clamp01((1.0 - speechBoost) * 1.15) +
        0.10 * lowMidBoost;

    double musicEvent =
        0.28 * musicDb +
        0.18 * balancedSpectrum +
        0.16 * broadbandBoost +
        0.14 * highBoost +
        0.12 * _clamp01((f.tonalProminence - 0.12) / 0.45) +
        0.12 * _clamp01((f.energyVar - 0.10) / 0.35);

    double traffic =
        0.28 * trafficDb +
        0.24 * lowBoost +
        0.15 * lowMidBoost +
        0.15 * steadyBoost +
        0.10 * _clamp01((1.0 - humBoost) * 1.1) +
        0.08 * _clamp01((1.0 - speechBoost) * 1.1);

    double machinery =
        0.26 * machineDb +
        0.24 * humBoost +
        0.20 * steadyBoost +
        0.12 * _clamp01((1.0 - f.flatness) * 1.2) +
        0.10 * lowBoost +
        0.08 * _clamp01((1.0 - fluxBoost) * 1.1);

    double quietIndoor =
        0.44 * quietDb +
        0.18 * steadyBoost +
        0.12 * lowNoise +
        0.10 * _clamp01((1.0 - fluxBoost) * 1.1) +
        0.08 * _clamp01((1.0 - speechBoost) * 1.1) +
        0.08 * _clamp01((1.0 - highBoost) * 1.1);

    if (db < 44) {
      quietIndoor += 0.16;
      conversation -= 0.08;
      crowd -= 0.08;
      musicEvent -= 0.10;
    }

    if (speechBoost > 0.55 && db >= 45 && db <= 76) {
      conversation += 0.18;
      crowd -= 0.06;
      traffic -= 0.05;
      machinery -= 0.05;
    }

    if (lowBoost > 0.52 && steadyBoost > 0.52 && humBoost > 0.48) {
      machinery += 0.16;
      traffic -= 0.04;
      crowd -= 0.05;
    }

    if (lowBoost > 0.48 &&
        steadyBoost > 0.42 &&
        humBoost < 0.42 &&
        f.flatness > 0.22) {
      traffic += 0.14;
      machinery -= 0.04;
    }

    if (db > 68 && balancedSpectrum > 0.45 && highBoost > 0.28) {
      musicEvent += 0.14;
    }

    if (db > 62 && flatBoost > 0.35 && broadbandBoost > 0.35) {
      crowd += 0.10;
    }

    if (db > 78) {
      quietIndoor -= 0.25;
    }

    return <SoundScene, double>{
      SoundScene.conversation: math.max(0.01, conversation),
      SoundScene.crowd: math.max(0.01, crowd),
      SoundScene.musicEvent: math.max(0.01, musicEvent),
      SoundScene.traffic: math.max(0.01, traffic),
      SoundScene.machinery: math.max(0.01, machinery),
      SoundScene.quietIndoor: math.max(0.01, quietIndoor),
    };
  }

  _AudioFeatures _extractFeatures(
    List<double> samples, {
    required int sampleRate,
    required double? currentDb,
  }) {
    final n = samples.length;
    final centered = List<double>.from(samples);

    double mean = 0.0;
    for (final v in centered) {
      mean += v;
    }
    mean /= n;

    for (int i = 0; i < n; i++) {
      centered[i] -= mean;
    }

    double sumSq = 0.0;
    double peak = 0.0;
    for (final v in centered) {
      sumSq += v * v;
      final absV = v.abs();
      if (absV > peak) peak = absV;
    }

    final rms = math.sqrt(sumSq / n);
    final rmsDbFs = 20.0 * math.log(math.max(rms, 1e-9)) / math.ln10;
    final derivedDb = _dbFsToApproxAmbientDb(rmsDbFs);
    final db = currentDb ?? derivedDb;

    double zcrCount = 0.0;
    for (int i = 1; i < n; i++) {
      final prev = centered[i - 1];
      final curr = centered[i];
      if ((prev >= 0 && curr < 0) || (prev < 0 && curr >= 0)) {
        zcrCount += 1.0;
      }
    }
    final zcr = zcrCount / math.max(1, n - 1);

    final energyVar = _segmentEnergyVariance(centered, segments: 8);

    final fftInput = _prepareFftInput(centered, size: 256);
    final spectrum = _naiveMagnitudeSpectrum(fftInput);

    final totalMag = spectrum.fold<double>(0.0, (a, b) => a + b) + 1e-9;

    double centroidNum = 0.0;
    double cumulative = 0.0;
    double rolloffHz = 0.0;
    int broadbandBins = 0;
    double maxMag = 0.0;

    double low = 0.0;
    double lowMid = 0.0;
    double mid = 0.0;
    double high = 0.0;

    for (int k = 0; k < spectrum.length; k++) {
      final mag = spectrum[k];
      final freq = (k * sampleRate) / 256.0;

      centroidNum += freq * mag;
      cumulative += mag;

      if (mag > maxMag) maxMag = mag;
      if (mag > (totalMag / spectrum.length) * 1.2) {
        broadbandBins += 1;
      }

      if (rolloffHz == 0.0 && cumulative >= totalMag * 0.95) {
        rolloffHz = freq;
      }

      if (freq >= 40 && freq < 250) {
        low += mag;
      } else if (freq >= 250 && freq < 1000) {
        lowMid += mag;
      } else if (freq >= 1000 && freq < 2500) {
        mid += mag;
      } else if (freq >= 2500 && freq < 6000) {
        high += mag;
      }
    }

    final centroidHz = centroidNum / totalMag;
    final lowRatio = low / totalMag;
    final lowMidRatio = lowMid / totalMag;
    final midRatio = mid / totalMag;
    final highRatio = high / totalMag;
    final broadbandness = broadbandBins / spectrum.length;
    final tonalProminence = maxMag / totalMag;

    double geoMeanLog = 0.0;
    for (final mag in spectrum) {
      geoMeanLog += math.log(mag + 1e-9);
    }
    geoMeanLog /= spectrum.length;
    final geometricMean = math.exp(geoMeanLog);
    final arithmeticMean = totalMag / spectrum.length;
    final flatness = (geometricMean / math.max(arithmeticMean, 1e-9)).clamp(
      0.0,
      1.0,
    );

    final spectrumNorm = spectrum.map((e) => e / totalMag).toList();
    double spectralFlux = 0.0;
    if (_previousSpectrum != null &&
        _previousSpectrum!.length == spectrumNorm.length) {
      for (int i = 0; i < spectrumNorm.length; i++) {
        final d = spectrumNorm[i] - _previousSpectrum![i];
        spectralFlux += d * d;
      }
      spectralFlux = _clamp01(spectralFlux * 8.0);
    }
    _previousSpectrum = spectrumNorm;

    final speechPeriodicity = _maxNormalizedAutocorrelation(
      centered,
      minLag: math.max(20, (sampleRate / 300).floor()),
      maxLag: math.min(centered.length - 2, (sampleRate / 80).floor()),
    );

    final humPeriodicity = _maxNormalizedAutocorrelation(
      centered,
      minLag: math.max(20, (sampleRate / 120).floor()),
      maxLag: math.min(centered.length - 2, (sampleRate / 40).floor()),
    );

    return _AudioFeatures(
      db: db,
      rmsDbFs: rmsDbFs,
      rms: rms,
      peak: peak,
      zcr: zcr,
      energyVar: energyVar,
      centroidHz: centroidHz,
      rolloffHz: rolloffHz,
      flatness: flatness,
      lowRatio: lowRatio,
      lowMidRatio: lowMidRatio,
      midRatio: midRatio,
      highRatio: highRatio,
      speechPeriodicity: speechPeriodicity,
      humPeriodicity: humPeriodicity,
      tonalProminence: tonalProminence,
      spectralFlux: spectralFlux,
      broadbandness: broadbandness,
    );
  }

  List<double> _normalizePcm16(List<int> pcm16) {
    return pcm16.map((s) {
      final v = s / 32768.0;
      return v.clamp(-1.0, 1.0);
    }).toList();
  }

  List<double> _prepareFftInput(List<double> input, {required int size}) {
    final out = List<double>.filled(size, 0.0);
    if (input.isEmpty) return out;

    final take = math.min(size, input.length);
    final start = input.length - take;

    for (int i = 0; i < take; i++) {
      final w = 0.5 - 0.5 * math.cos((2 * math.pi * i) / math.max(1, take - 1));
      out[i] = input[start + i] * w;
    }
    return out;
  }

  List<double> _naiveMagnitudeSpectrum(List<double> x) {
    final n = x.length;
    final bins = n ~/ 2;
    final mags = List<double>.filled(bins, 0.0);

    for (int k = 0; k < bins; k++) {
      double re = 0.0;
      double im = 0.0;
      for (int i = 0; i < n; i++) {
        final angle = (2.0 * math.pi * k * i) / n;
        re += x[i] * math.cos(angle);
        im -= x[i] * math.sin(angle);
      }
      mags[k] = math.sqrt((re * re) + (im * im));
    }

    return mags;
  }

  double _segmentEnergyVariance(List<double> samples, {int segments = 8}) {
    if (samples.isEmpty) return 0.0;

    final segSize = math.max(1, samples.length ~/ segments);
    final energies = <double>[];

    for (int s = 0; s < segments; s++) {
      final start = s * segSize;
      if (start >= samples.length) break;
      final end = math.min(samples.length, start + segSize);

      double sumSq = 0.0;
      for (int i = start; i < end; i++) {
        sumSq += samples[i] * samples[i];
      }
      energies.add(sumSq / math.max(1, end - start));
    }

    if (energies.isEmpty) return 0.0;
    final mean = energies.reduce((a, b) => a + b) / energies.length;

    if (mean <= 1e-12) return 0.0;

    double variance = 0.0;
    for (final e in energies) {
      final d = e - mean;
      variance += d * d;
    }
    variance /= energies.length;

    return _clamp01(math.sqrt(variance) / mean);
  }

  double _maxNormalizedAutocorrelation(
    List<double> x, {
    required int minLag,
    required int maxLag,
  }) {
    if (x.length < 32) return 0.0;
    if (minLag >= maxLag) return 0.0;
    if (minLag >= x.length - 2) return 0.0;

    maxLag = math.min(maxLag, x.length - 2);

    double best = 0.0;

    for (int lag = minLag; lag <= maxLag; lag++) {
      double num = 0.0;
      double denA = 0.0;
      double denB = 0.0;

      for (int i = 0; i < x.length - lag; i++) {
        final a = x[i];
        final b = x[i + lag];
        num += a * b;
        denA += a * a;
        denB += b * b;
      }

      final denom = math.sqrt(denA * denB) + 1e-9;
      final score = num / denom;
      if (score > best) best = score;
    }

    return _clamp01(best);
  }

  Map<SoundScene, double> _normalizeSceneScores(
    Map<SoundScene, double> scores,
  ) {
    final sum = scores.values.fold<double>(0.0, (a, b) => a + b) + 1e-9;
    return {for (final e in scores.entries) e.key: e.value / sum};
  }

  SoundScene? _labelToScene(String label) {
    final normalized = label.trim().toLowerCase();
    for (final scene in SoundScene.values) {
      if (scene.label.toLowerCase() == normalized) {
        return scene;
      }
    }
    if (normalized == 'music') return SoundScene.musicEvent;
    return null;
  }

  double _estimateDbFromPcm16Bytes(Uint8List bytes) {
    if (bytes.length < 2) return 0.0;

    final bd = ByteData.sublistView(bytes);
    double sumSq = 0.0;
    int count = 0;

    for (int i = 0; i + 1 < bytes.length; i += 2) {
      final s = bd.getInt16(i, Endian.little) / 32768.0;
      sumSq += s * s;
      count++;
    }

    if (count == 0) return 0.0;

    final rms = math.sqrt(sumSq / count);
    final rmsDbFs = 20.0 * math.log(math.max(rms, 1e-9)) / math.ln10;
    return _dbFsToApproxAmbientDb(rmsDbFs);
  }

  double _estimateDbFromInt16Samples(List<int> pcm16) {
    if (pcm16.isEmpty) return 0.0;

    double sumSq = 0.0;
    for (final s in pcm16) {
      final v = s / 32768.0;
      sumSq += v * v;
    }

    final rms = math.sqrt(sumSq / pcm16.length);
    final rmsDbFs = 20.0 * math.log(math.max(rms, 1e-9)) / math.ln10;
    return _dbFsToApproxAmbientDb(rmsDbFs);
  }

  double _dbFsToApproxAmbientDb(double dbFs) {
    return (35.0 + ((dbFs + 60.0) * 1.15)).clamp(20.0, 110.0);
  }

  double _clamp01(double v) => v.clamp(0.0, 1.0);

  double _triangle(double x, double left, double mid, double right) {
    if (x <= left || x >= right) return 0.0;
    if (x == mid) return 1.0;
    if (x < mid) return (x - left) / (mid - left);
    return (right - x) / (right - mid);
  }

  double _smoothStep(double edge0, double edge1, double x) {
    final t = _clamp01((x - edge0) / (edge1 - edge0));
    return t * t * (3.0 - 2.0 * t);
  }
}

class _AudioFeatures {
  final double db;
  final double rmsDbFs;
  final double rms;
  final double peak;
  final double zcr;
  final double energyVar;
  final double centroidHz;
  final double rolloffHz;
  final double flatness;
  final double lowRatio;
  final double lowMidRatio;
  final double midRatio;
  final double highRatio;
  final double speechPeriodicity;
  final double humPeriodicity;
  final double tonalProminence;
  final double spectralFlux;
  final double broadbandness;

  const _AudioFeatures({
    required this.db,
    required this.rmsDbFs,
    required this.rms,
    required this.peak,
    required this.zcr,
    required this.energyVar,
    required this.centroidHz,
    required this.rolloffHz,
    required this.flatness,
    required this.lowRatio,
    required this.lowMidRatio,
    required this.midRatio,
    required this.highRatio,
    required this.speechPeriodicity,
    required this.humPeriodicity,
    required this.tonalProminence,
    required this.spectralFlux,
    required this.broadbandness,
  });
}
