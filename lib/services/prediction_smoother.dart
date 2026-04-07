import 'dart:collection';

class SmoothedPrediction {
  final String label;
  final double confidence;
  final String rawLabel;
  final double rawConfidence;
  final bool isStable;
  final List<MapEntry<String, double>> topPredictions;

  const SmoothedPrediction({
    required this.label,
    required this.confidence,
    required this.rawLabel,
    required this.rawConfidence,
    required this.isStable,
    required this.topPredictions,
  });
}

class PredictionSmoother {
  PredictionSmoother({
    this.windowSize = 8,
    this.minStableFrames = 4,
    this.minAverageConfidence = 0.22,
    this.minDominanceGap = 0.06,
    this.holdFramesAfterLoss = 3,
    this.fallbackLabel = 'Ambient / Unknown',
  });

  final int windowSize;
  final int minStableFrames;
  final double minAverageConfidence;
  final double minDominanceGap;
  final int holdFramesAfterLoss;
  final String fallbackLabel;

  final Queue<Map<String, double>> _recentFrames = Queue<Map<String, double>>();

  String? _lastStableLabel;
  double _lastStableConfidence = 0.0;
  int _framesSinceStable = 999;

  void reset() {
    _recentFrames.clear();
    _lastStableLabel = null;
    _lastStableConfidence = 0.0;
    _framesSinceStable = 999;
  }

  SmoothedPrediction addFrame(Map<String, double> currentScores) {
    final cleaned = _cleanScores(currentScores);
    final currentTop = _topEntry(cleaned);

    _recentFrames.addLast(cleaned);
    while (_recentFrames.length > windowSize) {
      _recentFrames.removeFirst();
    }

    if (_recentFrames.isEmpty || currentTop == null) {
      return SmoothedPrediction(
        label: fallbackLabel,
        confidence: 0.0,
        rawLabel: fallbackLabel,
        rawConfidence: 0.0,
        isStable: false,
        topPredictions: const [],
      );
    }

    final averaged = _buildAveragedPredictions();
    final best = averaged.isNotEmpty
        ? averaged.first
        : MapEntry<String, double>(fallbackLabel, 0.0);
    final second = averaged.length > 1
        ? averaged[1]
        : const MapEntry<String, double>('', 0.0);

    final stableHits = _countTopHits(best.key);

    final isStableNow =
        stableHits >= minStableFrames &&
        best.value >= minAverageConfidence &&
        (best.value - second.value) >= minDominanceGap;

    if (isStableNow) {
      _lastStableLabel = best.key;
      _lastStableConfidence = best.value;
      _framesSinceStable = 0;

      return SmoothedPrediction(
        label: best.key,
        confidence: best.value,
        rawLabel: currentTop.key,
        rawConfidence: currentTop.value,
        isStable: true,
        topPredictions: averaged.take(2).toList(),
      );
    }

    _framesSinceStable++;

    if (_lastStableLabel != null && _framesSinceStable <= holdFramesAfterLoss) {
      return SmoothedPrediction(
        label: _lastStableLabel!,
        confidence: _lastStableConfidence,
        rawLabel: currentTop.key,
        rawConfidence: currentTop.value,
        isStable: false,
        topPredictions: averaged.take(2).toList(),
      );
    }

    return SmoothedPrediction(
      label: fallbackLabel,
      confidence: best.value,
      rawLabel: currentTop.key,
      rawConfidence: currentTop.value,
      isStable: false,
      topPredictions: averaged.take(2).toList(),
    );
  }

  Map<String, double> _cleanScores(Map<String, double> input) {
    final result = <String, double>{};

    for (final entry in input.entries) {
      final label = entry.key.trim();
      final value = entry.value;

      if (label.isEmpty) continue;
      if (value.isNaN || value.isInfinite) continue;
      if (value <= 0.0) continue;

      result[label] = value.clamp(0.0, 1.0);
    }

    return result;
  }

  MapEntry<String, double>? _topEntry(Map<String, double> scores) {
    if (scores.isEmpty) return null;

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.first;
  }

  List<MapEntry<String, double>> _buildAveragedPredictions() {
    final totals = <String, double>{};

    for (final frame in _recentFrames) {
      final sorted = frame.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (final entry in sorted.take(3)) {
        totals[entry.key] = (totals[entry.key] ?? 0.0) + entry.value;
      }
    }

    final averaged =
        totals.entries
            .map((e) => MapEntry(e.key, e.value / _recentFrames.length))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return averaged;
  }

  int _countTopHits(String label) {
    int count = 0;

    for (final frame in _recentFrames) {
      final top = _topEntry(frame);
      if (top != null && top.key == label) {
        count++;
      }
    }

    return count;
  }
}
