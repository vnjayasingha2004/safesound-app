import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app/monitor_settings.dart';
import '../data/notification_store.dart';
import '../data/session_store.dart';
import '../models/app_notification_model.dart';
import '../models/session_model.dart';
import '../services/local_notification_service.dart';
import '../services/sound_classifier_service.dart';
import 'location_picker_screen.dart';

class LiveMonitorScreen extends StatefulWidget {
  const LiveMonitorScreen({super.key});

  @override
  State<LiveMonitorScreen> createState() => _LiveMonitorScreenState();
}

class _LiveMonitorScreenState extends State<LiveMonitorScreen> {
  Timer? _durationTimer;
  Timer? _unsafeExposureTimer;
  StreamSubscription<SoundClassificationResult>? _aiSubscription;

  final SoundClassifierService _soundClassifierService =
      SoundClassifierService.instance;

  bool _isMonitoring = false;
  int _secondsElapsed = 0;
  int _unsafeAlertCount = 0;

  DateTime? _lastUnsafeAlertAt;
  bool _isAlertDialogOpen = false;
  bool _aiFallbackNoticeShown = false;

  static const Duration _unsafeExposureDelay = Duration(seconds: 3);
  static const Duration _unsafeAlertCooldown = Duration(seconds: 15);

  double _currentDb = 0;
  double _smoothedStatusDb = 0;
  double _coachDisplayDb = 0;
  final List<double> _recordedLevels = [];

  String? _selectedLocationLabel;
  String? _manualSoundTypeOverride;

  String _aiDetectedLabel = 'Waiting for audio';
  double _aiConfidence = 0.0;
  bool _aiIsStable = false;
  bool _usingAiScene = false;
  List<MapEntry<String, double>> _aiTopPredictions = const [];

  double get _averageDb {
    if (_recordedLevels.isEmpty) return _currentDb;
    final total = _recordedLevels.reduce((a, b) => a + b);
    return total / _recordedLevels.length;
  }

  int get _peakDb {
    if (_recordedLevels.isEmpty) return _currentDb.round();

    return _recordedLevels
        .fold<double>(
          0,
          (maxValue, value) => value > maxValue ? value : maxValue,
        )
        .round();
  }

  double get _recentAverageDb {
    if (_recordedLevels.isEmpty) return _statusDb;

    final start = _recordedLevels.length > 24 ? _recordedLevels.length - 24 : 0;
    final recent = _recordedLevels.sublist(start);
    final total = recent.reduce((a, b) => a + b);
    return total / recent.length;
  }

  int get _recentPeakDb {
    if (_recordedLevels.isEmpty) return _statusDb.round();

    final start = _recordedLevels.length > 24 ? _recordedLevels.length - 24 : 0;
    return _recordedLevels
        .sublist(start)
        .fold<double>(
          0,
          (maxValue, value) => value > maxValue ? value : maxValue,
        )
        .round();
  }

  double get _statusDb =>
      _smoothedStatusDb > 0 ? _smoothedStatusDb : _currentDb;

  double get _coachDb => _coachDisplayDb > 0 ? _coachDisplayDb : _statusDb;

  double get _alertThreshold => alertThresholdNotifier.value;

  bool get _isAboveThreshold => _statusDb >= _alertThreshold;

  bool get _hasMeaningfulAiPrediction =>
      _usingAiScene &&
      _aiDetectedLabel.isNotEmpty &&
      _aiDetectedLabel != 'Waiting for audio' &&
      _aiDetectedLabel != 'Listening...' &&
      _aiDetectedLabel != 'AI starting...' &&
      _aiDetectedLabel != 'AI unavailable';

  String get _aiStatusText {
    if (!_isMonitoring) return 'Stopped';
    if (!_usingAiScene) return 'Waiting...';
    if (_hasMeaningfulAiPrediction && _aiIsStable) return 'Stable';
    if (_hasMeaningfulAiPrediction) return 'Learning...';
    return 'Listening...';
  }

  String get _riskStatus {
    if (_statusDb < 70) return 'Safe';
    if (_statusDb < _alertThreshold) return 'Moderate';
    return 'High Exposure';
  }

  String get _sessionRiskStatus {
    if (_averageDb < 70) return 'Safe';
    if (_averageDb < _alertThreshold) return 'Moderate';
    return 'High';
  }

  Color get _statusColor {
    if (_statusDb < 70) return Colors.green;
    if (_statusDb < _alertThreshold) return Colors.orange;
    return Colors.red;
  }

  String get _estimatedLocationLabel {
    if (_statusDb < 70) return 'Library Area';
    if (_statusDb < _alertThreshold) return 'Main Road';
    return 'Workshop';
  }

  String get _locationLabel =>
      _selectedLocationLabel ?? _estimatedLocationLabel;

  String get _conversationStatus {
    final db = _coachDb;

    if (db < 60) return 'Easy to talk';
    if (db < 70) return 'Comfortable';
    if (db < 80) return 'Slightly difficult';
    if (db < 90) return 'Hard to talk';
    return 'Very hard to talk';
  }

  String get _remainingSafeTimeLabel {
    final db = _coachDb;

    if (db < 70) return 'Low concern for now';
    if (db < 75) return 'Approx. 24+ hrs';
    if (db < 80) return 'Approx. 8 hrs';
    if (db < 85) return 'Approx. 2 hrs';
    if (db < 90) return 'Approx. 30 min';
    if (db < 95) return 'Approx. 10 min';
    if (db < 100) return 'Approx. 3 min';
    return 'Leave now';
  }

  String get _soundSceneLabel {
    if (!_isMonitoring && _recordedLevels.isEmpty) {
      return 'Not monitoring';
    }

    if (_manualSoundTypeOverride != null) return _manualSoundTypeOverride!;

    if (_hasMeaningfulAiPrediction) {
      return _aiDetectedLabel;
    }

    if (_isMonitoring && _recordedLevels.length < 8) {
      return 'Listening...';
    }

    return _detectedSoundType;
  }

  double get _soundSceneConfidence {
    if (!_isMonitoring && _recordedLevels.isEmpty) return 0.0;
    if (_manualSoundTypeOverride != null) return 1.0;

    if (_hasMeaningfulAiPrediction) {
      return _aiConfidence;
    }

    if (_isMonitoring && _recordedLevels.length < 8) return 0.0;
    return _detectedSoundTypeConfidence;
  }

  String get _soundSceneEngineLabel {
    if (!_isMonitoring && _recordedLevels.isEmpty) return 'Inactive';
    if (_manualSoundTypeOverride != null) return 'Manual';
    if (_hasMeaningfulAiPrediction) return 'Custom 6-class AI';
    if (_usingAiScene) return 'Analyzing';
    return 'Rule-based fallback';
  }

  String get _detectedSoundType {
    final avg = _recentAverageDb;
    final peak = _recentPeakDb;

    if (avg < 38) return 'Quiet Indoor';
    if (avg < 56) return 'Conversation';
    if (avg < 70) return 'Crowd';
    if (avg < 84) return 'Traffic';
    if (peak >= 100 && avg >= 88) return 'Machinery';
    if (avg < 96) return 'Music / Event';
    return 'Machinery';
  }

  double get _detectedSoundTypeConfidence {
    final avg = _recentAverageDb;
    final peak = _recentPeakDb;

    if (avg < 38) return 0.68;
    if (avg < 56) return 0.58;
    if (avg < 70) return 0.54;
    if (avg < 84) return 0.60;
    if (peak >= 100 && avg >= 88) return 0.66;
    if (avg < 96) return 0.63;
    return 0.66;
  }

  int get _exposureScore => _calculateExposureScore(
    averageDb: _averageDb,
    peakDb: _peakDb,
    durationSeconds: _secondsElapsed,
    unsafeAlertCount: _unsafeAlertCount,
  );

  String get _coachSummary => _buildCoachSummary(
    currentDb: _coachDb,
    averageDb: _averageDb,
    secondsElapsed: _secondsElapsed,
    unsafeAlertCount: _unsafeAlertCount,
  );

  void _setManualSoundType(String? value) {
    _soundClassifierService.setManualOverride(value);
    setState(() {
      _manualSoundTypeOverride = value;
    });
  }

  int _calculateExposureScore({
    required double averageDb,
    required int peakDb,
    required int durationSeconds,
    required int unsafeAlertCount,
  }) {
    int score = 0;

    if (averageDb >= 95) {
      score += 60;
    } else if (averageDb >= 90) {
      score += 50;
    } else if (averageDb >= 85) {
      score += 40;
    } else if (averageDb >= 80) {
      score += 28;
    } else if (averageDb >= 75) {
      score += 18;
    } else if (averageDb >= 70) {
      score += 10;
    } else {
      score += 4;
    }

    if (peakDb >= 100) {
      score += 20;
    } else if (peakDb >= 95) {
      score += 15;
    } else if (peakDb >= 90) {
      score += 10;
    } else if (peakDb >= 85) {
      score += 6;
    }

    if (durationSeconds >= 3600) {
      score += 20;
    } else if (durationSeconds >= 1800) {
      score += 15;
    } else if (durationSeconds >= 900) {
      score += 10;
    } else if (durationSeconds >= 300) {
      score += 5;
    }

    score += unsafeAlertCount * 8;

    if (score < 0) return 0;
    if (score > 100) return 100;
    return score;
  }

  String _buildCoachSummary({
    required double currentDb,
    required double averageDb,
    required int secondsElapsed,
    required int unsafeAlertCount,
  }) {
    String message;

    if (currentDb < 60) {
      message = 'Great for study, calls, and focused work.';
    } else if (currentDb < 70) {
      message = 'Comfortable daily environment. Safe for longer stays.';
    } else if (currentDb < 80) {
      message =
          'Okay for a normal stay, but repeated long exposure can add up.';
    } else if (currentDb < 85) {
      message = 'Stay aware. Better for short visits than long study sessions.';
    } else if (currentDb < 90) {
      message = 'Too loud for long exposure. Move away or reduce time here.';
    } else if (currentDb < 95) {
      message = 'Use hearing protection or leave within a short time.';
    } else {
      message = 'High-risk environment. Leave or protect your ears now.';
    }

    if (unsafeAlertCount > 0) {
      message +=
          ' This session already triggered $unsafeAlertCount unsafe alert${unsafeAlertCount == 1 ? '' : 's'}.';
    }

    if (secondsElapsed >= 1800 && averageDb >= 80) {
      message += ' A quiet recovery break would be a good idea after this.';
    }

    return message;
  }

  String _formatNotificationTime(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';

    return '${_formatDate(dateTime)} • $hour:$minute $period';
  }

  String _formatPredictionLine(MapEntry<String, double> prediction) {
    final percent = (prediction.value * 100).round();
    return '${prediction.key} ($percent%)';
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<LocationPickResult>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LocationPickerScreen(initialLabel: _selectedLocationLabel),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _selectedLocationLabel = result.label;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Location selected: ${result.label}')),
    );
  }

  Future<bool> _requestMicPermission() async {
    final status = await Permission.microphone.request();

    if (status.isGranted) return true;

    if (!mounted) return false;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Microphone permission is required for live monitoring'),
      ),
    );

    return false;
  }

  void _handlePrediction(SoundClassificationResult result) {
    if (!mounted || !_isMonitoring) return;

    final topPredictions = List<MapEntry<String, double>>.from(
      result.topPredictions,
    )..sort((a, b) => b.value.compareTo(a.value));

    final liveDb = result.smoothedDb > 0 ? result.smoothedDb : result.currentDb;

    setState(() {
      final liveDb = result.smoothedDb > 0
          ? result.smoothedDb
          : result.currentDb;
      final nextCoachDb = _coachDisplayDb <= 0
          ? liveDb
          : (_coachDisplayDb + (0.10 * (liveDb - _coachDisplayDb)));

      _currentDb = result.currentDb;
      _smoothedStatusDb = liveDb;
      _coachDisplayDb = nextCoachDb;

      _usingAiScene = true;
      _currentDb = result.currentDb;
      _smoothedStatusDb = liveDb;

      if (liveDb > 0) {
        _recordedLevels.add(liveDb);
        if (_recordedLevels.length > 3600) {
          _recordedLevels.removeAt(0);
        }
      }

      _aiDetectedLabel = result.label.isEmpty
          ? 'Waiting for audio'
          : result.label;
      _aiConfidence = result.confidence;
      _aiIsStable = result.isStable;
      _aiTopPredictions = topPredictions;
    });

    _handleThresholdTracking();
  }

  Future<void> _startAiClassification() async {
    try {
      await _aiSubscription?.cancel();
      _soundClassifierService.reset();
      _soundClassifierService.setManualOverride(_manualSoundTypeOverride);

      setState(() {
        _usingAiScene = true;
        _aiDetectedLabel = 'AI starting...';
        _aiConfidence = 0.0;
        _aiIsStable = false;
        _aiTopPredictions = const [];
      });

      await _soundClassifierService.initialize();
      final aiStream = await _soundClassifierService.startListening();

      _aiSubscription = aiStream.listen(
        _handlePrediction,
        onError: _handleAiFallback,
      );
    } catch (error) {
      _handleAiFallback(error);
    }
  }

  void _handleAiFallback(Object error) {
    if (!mounted) return;

    setState(() {
      _usingAiScene = false;
      _aiDetectedLabel = 'AI unavailable';
      _aiConfidence = 0.0;
      _aiIsStable = false;
      _aiTopPredictions = const [];
    });

    debugPrint('AI FALLBACK ERROR: $error');

    if (_aiFallbackNoticeShown) return;
    _aiFallbackNoticeShown = true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('AI failed: $error'),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _stopAiClassification() async {
    await _aiSubscription?.cancel();
    _aiSubscription = null;
    await _soundClassifierService.stop();
  }

  Future<void> _startMonitoring() async {
    if (_isMonitoring) return;

    final hasPermission = await _requestMicPermission();
    if (!hasPermission) return;

    _durationTimer?.cancel();
    _cancelUnsafeExposureTimer();
    await _stopAiClassification();

    setState(() {
      _isMonitoring = true;
      _secondsElapsed = 0;
      _unsafeAlertCount = 0;
      _lastUnsafeAlertAt = null;
      _isAlertDialogOpen = false;
      _manualSoundTypeOverride = null;
      _currentDb = 0;
      _smoothedStatusDb = 0;
      _recordedLevels.clear();
      _aiDetectedLabel = 'Waiting for audio';
      _aiConfidence = 0.0;
      _aiIsStable = false;
      _usingAiScene = false;
      _aiFallbackNoticeShown = false;
      _aiTopPredictions = const [];
    });

    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isMonitoring) return;

      setState(() {
        _secondsElapsed++;
      });
    });

    await _startAiClassification();
  }

  void _handleThresholdTracking() {
    if (!_isMonitoring || !alertsEnabledNotifier.value) {
      _cancelUnsafeExposureTimer();
      return;
    }

    if (_isAboveThreshold) {
      _unsafeExposureTimer ??= Timer(_unsafeExposureDelay, () async {
        _unsafeExposureTimer = null;
        await _triggerUnsafeAlert();
      });
    } else {
      _cancelUnsafeExposureTimer();
    }
  }

  void _cancelUnsafeExposureTimer() {
    _unsafeExposureTimer?.cancel();
    _unsafeExposureTimer = null;
  }

  Future<void> _triggerUnsafeAlert() async {
    if (!_isMonitoring) return;
    if (!alertsEnabledNotifier.value) return;
    if (!_isAboveThreshold) return;

    final now = DateTime.now();

    if (_lastUnsafeAlertAt != null &&
        now.difference(_lastUnsafeAlertAt!) < _unsafeAlertCooldown) {
      return;
    }

    _lastUnsafeAlertAt = now;

    if (mounted) {
      setState(() {
        _unsafeAlertCount++;
      });
    } else {
      _unsafeAlertCount++;
    }

    final message =
        'Sound stayed at ${_statusDb.round()} dB for ${_unsafeExposureDelay.inSeconds} seconds, above your threshold of ${_alertThreshold.toInt()} dB.';

    await addAppNotification(
      AppNotificationModel(
        id: now.microsecondsSinceEpoch.toString(),
        title: 'Unsafe Noise Alert',
        message: message,
        type: 'warning',
        time: _formatNotificationTime(now),
        isRead: false,
      ),
    );

    await LocalNotificationService.showNoiseAlert(
      title: 'Unsafe Noise Alert',
      body: message,
    );

    await HapticFeedback.mediumImpact();

    if (!mounted || _isAlertDialogOpen) return;

    _isAlertDialogOpen = true;

    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Unsafe Noise Alert'),
            content: Text(
              'Sound has remained above your limit for ${_unsafeExposureDelay.inSeconds} seconds.\n\n'
              'Current level: ${_statusDb.round()} dB\n'
              'Your threshold: ${_alertThreshold.toInt()} dB\n\n'
              'Consider moving away, reducing exposure time, or using ear protection.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Dismiss'),
              ),
            ],
          );
        },
      );
    } finally {
      _isAlertDialogOpen = false;
    }
  }

  Future<void> _stopMonitoring() async {
    _durationTimer?.cancel();
    _cancelUnsafeExposureTimer();
    await _stopAiClassification();

    if (!mounted) return;

    setState(() {
      _isMonitoring = false;
      _usingAiScene = false;
      _aiDetectedLabel = 'Waiting for audio';
      _aiConfidence = 0.0;
      _aiIsStable = false;
      _aiTopPredictions = const [];
    });
  }

  Future<void> _resetSession() async {
    _durationTimer?.cancel();
    _cancelUnsafeExposureTimer();
    await _stopAiClassification();

    if (!mounted) return;

    setState(() {
      _isMonitoring = false;
      _secondsElapsed = 0;
      _unsafeAlertCount = 0;
      _lastUnsafeAlertAt = null;
      _isAlertDialogOpen = false;
      _manualSoundTypeOverride = null;
      _currentDb = 0;
      _smoothedStatusDb = 0;
      _recordedLevels.clear();
      _aiDetectedLabel = 'Waiting for audio';
      _aiConfidence = 0.0;
      _aiIsStable = false;
      _usingAiScene = false;
      _aiFallbackNoticeShown = false;
      _aiTopPredictions = const [];
    });
  }

  Future<void> _saveSession() async {
    if (_secondsElapsed == 0 || _recordedLevels.isEmpty) return;

    final now = DateTime.now();

    final newSession = SessionModel(
      date: _formatDate(now),
      place: _locationLabel,
      averageDb: _averageDb.round(),
      peakDb: _peakDb,
      duration: _formatDuration(_secondsElapsed),
      riskLevel: _sessionRiskStatus,
      createdAt: now.toIso8601String(),
      unsafeAlertCount: _unsafeAlertCount,
      exposureScore: _exposureScore,
      conversationStatus: _conversationStatus,
      coachSummary: _coachSummary,
      remainingSafeTimeLabel: _remainingSafeTimeLabel,
      soundType: _soundSceneLabel,
      soundTypeConfidence: _soundSceneConfidence,
    );

    await addSessionToHistory(newSession);

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Session saved to history')));

    await _resetSession();
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final h = hours.toString().padLeft(2, '0');
    final m = minutes.toString().padLeft(2, '0');
    final s = seconds.toString().padLeft(2, '0');

    return '$h:$m:$s';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} ${date.day}';
  }

  Widget _buildWarningBanner() {
    if (!_isAboveThreshold) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Unsafe Exposure Detected',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Noise level is ${_statusDb.round()} dB. Your threshold is ${_alertThreshold.toInt()} dB.',
          ),
          if (protectiveTipsNotifier.value) ...[
            const SizedBox(height: 8),
            const Text(
              'Tip: Move away from the source, reduce time in this area, or use hearing protection.',
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _cancelUnsafeExposureTimer();
    _aiSubscription?.cancel();
    unawaited(_stopAiClassification());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder<double>(
        valueListenable: alertThresholdNotifier,
        builder: (context, threshold, _) {
          return ValueListenableBuilder<bool>(
            valueListenable: alertsEnabledNotifier,
            builder: (context, alertsEnabled, __) {
              return ValueListenableBuilder<bool>(
                valueListenable: protectiveTipsNotifier,
                builder: (context, protectiveTips, ___) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        const Text(
                          'Live Monitor',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isMonitoring
                              ? 'Monitoring surrounding sound in real time'
                              : 'Tap start to begin a new monitoring session',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 20),

                        _buildWarningBanner(),

                        Container(
                          height: 230,
                          width: 230,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _statusColor, width: 14),
                            color: _statusColor.withOpacity(0.08),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${_currentDb.round()}',
                                  style: const TextStyle(
                                    fontSize: 50,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  'dB',
                                  style: TextStyle(fontSize: 20),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _riskStatus,
                                  style: TextStyle(
                                    color: _statusColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          'Smoothed status level: ${_statusDb.round()} dB',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),

                        const SizedBox(height: 24),

                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.timer),
                            title: const Text('Session Duration'),
                            subtitle: Text(_formatDuration(_secondsElapsed)),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.warning_amber_rounded),
                            title: const Text('Current Risk Status'),
                            subtitle: Text(_riskStatus),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.notifications_active),
                            title: const Text('Alert Threshold'),
                            subtitle: Text('${threshold.toInt()} dB'),
                            trailing: Text(
                              alertsEnabled ? 'Alerts On' : 'Alerts Off',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.graphic_eq),
                            title: const Text('Average Session Level'),
                            subtitle: Text('${_averageDb.round()} dB'),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.schedule),
                            title: const Text('Remaining Safe Time'),
                            subtitle: Text(_remainingSafeTimeLabel),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.record_voice_over_outlined,
                            ),
                            title: const Text('Conversation Quality'),
                            subtitle: Text(_conversationStatus),
                            trailing: Text('${_statusDb.round()} dB'),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.psychology_alt_outlined),
                            title: const Text('Noise Coach'),
                            subtitle: Text(_coachSummary),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.insights_outlined),
                            title: const Text('Exposure Load'),
                            subtitle: Text('${_exposureScore}/100'),
                            trailing: Text('Alerts: $_unsafeAlertCount'),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.auto_awesome_outlined),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Likely Sound Scene',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'AI scene detection is approximate.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF757575),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _soundSceneLabel,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Confidence: ${(_soundSceneConfidence * 100).round()}%',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Engine: $_soundSceneEngineLabel',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'AI status: $_aiStatusText',
                                  style: TextStyle(
                                    color: _aiStatusText == 'Stable'
                                        ? Colors.green.shade700
                                        : (_aiStatusText == 'Stopped'
                                              ? Colors.grey.shade700
                                              : Colors.orange.shade700),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_usingAiScene &&
                                    _aiTopPredictions.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Top AI predictions',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ..._aiTopPredictions
                                      .take(2)
                                      .map(
                                        (prediction) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 2,
                                          ),
                                          child: Text(
                                            _formatPredictionLine(prediction),
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      ),
                                ],
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ChoiceChip(
                                      label: const Text('Auto'),
                                      selected:
                                          _manualSoundTypeOverride == null,
                                      onSelected: (_) =>
                                          _setManualSoundType(null),
                                    ),
                                    ChoiceChip(
                                      label: const Text('Traffic'),
                                      selected:
                                          _manualSoundTypeOverride == 'Traffic',
                                      onSelected: (_) =>
                                          _setManualSoundType('Traffic'),
                                    ),
                                    ChoiceChip(
                                      label: const Text('Crowd'),
                                      selected:
                                          _manualSoundTypeOverride == 'Crowd',
                                      onSelected: (_) =>
                                          _setManualSoundType('Crowd'),
                                    ),
                                    ChoiceChip(
                                      label: const Text('Music / Event'),
                                      selected:
                                          _manualSoundTypeOverride ==
                                          'Music / Event',
                                      onSelected: (_) =>
                                          _setManualSoundType('Music / Event'),
                                    ),
                                    ChoiceChip(
                                      label: const Text('Machinery'),
                                      selected:
                                          _manualSoundTypeOverride ==
                                          'Machinery',
                                      onSelected: (_) =>
                                          _setManualSoundType('Machinery'),
                                    ),
                                    ChoiceChip(
                                      label: const Text('Quiet Indoor'),
                                      selected:
                                          _manualSoundTypeOverride ==
                                          'Quiet Indoor',
                                      onSelected: (_) =>
                                          _setManualSoundType('Quiet Indoor'),
                                    ),
                                    ChoiceChip(
                                      label: const Text('Conversation'),
                                      selected:
                                          _manualSoundTypeOverride ==
                                          'Conversation',
                                      onSelected: (_) =>
                                          _setManualSoundType('Conversation'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Card(
                          child: ListTile(
                            onTap: _openLocationPicker,
                            leading: const Icon(Icons.place_outlined),
                            title: const Text('Location'),
                            subtitle: Text(_locationLabel),
                            trailing: const Icon(Icons.chevron_right_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.mic),
                            title: const Text('Monitoring State'),
                            subtitle: Text(
                              _isMonitoring ? 'Active' : 'Stopped',
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        if (!_isMonitoring && _secondsElapsed == 0)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _startMonitoring,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Start Session'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),

                        if (_isMonitoring)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _stopMonitoring,
                              icon: const Icon(Icons.stop),
                              label: const Text('Stop Session'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),

                        if (!_isMonitoring && _secondsElapsed > 0) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _saveSession,
                              icon: const Icon(Icons.save),
                              label: const Text('Save Session'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _resetSession,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Discard Session'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
