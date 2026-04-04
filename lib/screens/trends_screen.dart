import 'package:flutter/material.dart';
import '../data/mock_trends.dart';

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  bool _showDaily = true;

  List<TrendPoint> get _activeData =>
      _showDaily ? dailyTrendData : weeklyTrendData;

  double get _maxValue {
    final max = _activeData
        .map((point) => point.value)
        .reduce((a, b) => a > b ? a : b);
    return max < 100 ? 100 : max;
  }

  String get _summaryText {
    if (_showDaily) {
      return 'Daily exposure pattern for the last 7 days.';
    }
    return 'Weekly exposure pattern for the last 4 weeks.';
  }

  String get _riskMessage {
    final average =
        _activeData.map((e) => e.value).reduce((a, b) => a + b) /
        _activeData.length;

    if (average < 70) return 'Overall trend is in the safe range.';
    if (average < 85) return 'Overall trend is moderate. Keep monitoring.';
    return 'Overall trend is high. Consider reducing exposure.';
  }

  Color _barColor(double value) {
    if (value < 70) return Colors.green;
    if (value < 85) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final data = _activeData;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trend Analysis',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              _summaryText,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Daily'),
                    selected: _showDaily,
                    onSelected: (_) {
                      setState(() {
                        _showDaily = true;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Weekly'),
                    selected: !_showDaily,
                    onSelected: (_) {
                      setState(() {
                        _showDaily = false;
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 260,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: data.map((point) {
                      final height = (point.value / _maxValue) * 180;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${point.value.toInt()}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: height,
                                decoration: BoxDecoration(
                                  color: _barColor(point.value),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                point.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    title: 'Highest',
                    value:
                        '${data.map((e) => e.value).reduce((a, b) => a > b ? a : b).toInt()} dB',
                    icon: Icons.trending_up,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    title: 'Lowest',
                    value:
                        '${data.map((e) => e.value).reduce((a, b) => a < b ? a : b).toInt()} dB',
                    icon: Icons.trending_down,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    title: 'Average',
                    value:
                        '${(data.map((e) => e.value).reduce((a, b) => a + b) / data.length).toStringAsFixed(0)} dB',
                    icon: Icons.graphic_eq,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    title: 'Status',
                    value: _showDaily ? '7 Days' : '4 Weeks',
                    icon: Icons.analytics_outlined,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.insights, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _riskMessage,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(title),
          ],
        ),
      ),
    );
  }
}
