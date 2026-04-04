import 'dart:async';
import 'package:flutter/material.dart';
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

  String get _riskStatus {
    if (_currentDb < 70) return 'Safe';
    if (_currentDb < 85) return 'Moderate';
    return 'High Exposure';
  }

  String get _sessionRiskStatus {
    if (_averageDb < 70) return 'Safe';
    if (_averageDb < 85) return 'Moderate';
    return 'High';
  }

  Color get _statusColor {
    if (_currentDb < 70) return Colors.green;
    if (_currentDb < 85) return Colors.orange;
    return Colors.red;
  }

  String get _locationLabel {
    if (_currentDb < 70) return 'Library Area';
    if (_currentDb < 85) return 'Main Road';
    return 'Workshop';
  }

  void _startMonitoring() {
    if (_isMonitoring) return;

    setState(() {
      _isMonitoring = true;
      _secondsElapsed = 0;
      _currentIndex = 0;
      _recordedLevels.clear();
      _recordedLevels.add(_currentDb);
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsElapsed++;
        _currentIndex = (_currentIndex + 1) % _mockNoiseLevels.length;
        _recordedLevels.add(_currentDb);
      });
    });
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
      _recordedLevels.clear();
    });
  }

  void _saveSession() {
    if (_secondsElapsed == 0 || _recordedLevels.isEmpty) return;

    final newSession = SessionModel(
      date: _formatDate(DateTime.now()),
      place: _locationLabel,
      averageDb: _averageDb.round(),
      duration: _formatDuration(_secondsElapsed),
      riskLevel: _sessionRiskStatus,
    );

    addSessionToHistory(newSession);

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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Text(
              'Live Monitor',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _isMonitoring
                  ? 'Monitoring surrounding sound in real time'
                  : 'Tap start to begin a new monitoring session',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),

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
                    const Text('dB', style: TextStyle(fontSize: 20)),
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
                subtitle: Text(_isMonitoring ? 'Active' : 'Stopped'),
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
