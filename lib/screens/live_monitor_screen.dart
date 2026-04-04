import 'dart:async';
import 'package:flutter/material.dart';
import '../app/monitor_settings.dart';
import '../data/session_store.dart';
import '../models/session_model.dart';

class LiveMonitorScreen extends StatefulWidget {
  const LiveMonitorScreen({super.key});

  @override
  State<LiveMonitorScreen> createState() => _LiveMonitorScreenState();
}

class _LiveMonitorScreenState extends State<LiveMonitorScreen> {
  Timer? _timer;
  bool _isMonitoring = false;
  int _secondsElapsed = 0;
  int _currentIndex = 0;
  bool _alertShownForCurrentSession = false;

  final List<int> _recordedLevels = [];

  final List<int> _mockNoiseLevels = [
    58,
    62,
    67,
    72,
    76,
    81,
    85,
    88,
    79,
    73,
    69,
    64,
  ];

  int get _currentDb => _mockNoiseLevels[_currentIndex];

  double get _averageDb {
    if (_recordedLevels.isEmpty) return _currentDb.toDouble();
    final total = _recordedLevels.reduce((a, b) => a + b);
    return total / _recordedLevels.length;
  }

  double get _alertThreshold => alertThresholdNotifier.value;

  bool get _isAboveThreshold => _currentDb >= _alertThreshold;

  String get _riskStatus {
    if (_currentDb < 70) return 'Safe';
    if (_currentDb < _alertThreshold) return 'Moderate';
    return 'High Exposure';
  }

  String get _sessionRiskStatus {
    if (_averageDb < 70) return 'Safe';
    if (_averageDb < _alertThreshold) return 'Moderate';
    return 'High';
  }

  Color get _statusColor {
    if (_currentDb < 70) return Colors.green;
    if (_currentDb < _alertThreshold) return Colors.orange;
    return Colors.red;
  }

  String get _locationLabel {
    if (_currentDb < 70) return 'Library Area';
    if (_currentDb < _alertThreshold) return 'Main Road';
    return 'Workshop';
  }

  void _startMonitoring() {
    if (_isMonitoring) return;

    setState(() {
      _isMonitoring = true;
      _secondsElapsed = 0;
      _currentIndex = 0;
      _alertShownForCurrentSession = false;
      _recordedLevels.clear();
      _recordedLevels.add(_currentDb);
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsElapsed++;
        _currentIndex = (_currentIndex + 1) % _mockNoiseLevels.length;
        _recordedLevels.add(_currentDb);
      });

      _checkUnsafeAlert();
    });
  }

  void _checkUnsafeAlert() {
    if (!alertsEnabledNotifier.value) return;
    if (!_isMonitoring) return;
    if (!_isAboveThreshold) return;
    if (_alertShownForCurrentSession) return;

    _alertShownForCurrentSession = true;

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Unsafe Noise Alert'),
          content: Text(
            'Current sound level is $_currentDb dB, which is above your alert threshold of ${_alertThreshold.toInt()} dB.\n\nConsider moving away, reducing exposure time, or using ear protection.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Dismiss'),
            ),
          ],
        );
      },
    );
  }

  void _stopMonitoring() {
    _timer?.cancel();
    setState(() {
      _isMonitoring = false;
    });
  }

  void _resetSession() {
    _timer?.cancel();
    setState(() {
      _isMonitoring = false;
      _secondsElapsed = 0;
      _currentIndex = 0;
      _alertShownForCurrentSession = false;
      _recordedLevels.clear();
    });
  }

  Future<void> _saveSession() async {
    if (_secondsElapsed == 0 || _recordedLevels.isEmpty) return;

    final newSession = SessionModel(
      date: _formatDate(DateTime.now()),
      place: _locationLabel,
      averageDb: _averageDb.round(),
      duration: _formatDuration(_secondsElapsed),
      riskLevel: _sessionRiskStatus,
    );

    await addSessionToHistory(newSession);

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Session saved to history')));

    _resetSession();
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
            'Noise level is $_currentDb dB. Your threshold is ${_alertThreshold.toInt()} dB.',
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
    _timer?.cancel();
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
                                  '$_currentDb',
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
                            leading: const Icon(Icons.place_outlined),
                            title: const Text('Estimated Location Type'),
                            subtitle: Text(_locationLabel),
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
