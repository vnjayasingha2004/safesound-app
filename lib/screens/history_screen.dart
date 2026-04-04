import 'package:flutter/material.dart';
import '../data/mock_sessions.dart';
import '../models/session_model.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Color _riskColor(String riskLevel) {
    switch (riskLevel) {
      case 'Safe':
        return Colors.green;
      case 'Moderate':
        return Colors.orange;
      case 'High':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  int _highRiskCount(List<SessionModel> sessions) {
    return sessions.where((session) => session.riskLevel == 'High').length;
  }

  double _averageDb(List<SessionModel> sessions) {
    final total = sessions.fold<int>(
      0,
      (sum, session) => sum + session.averageDb,
    );
    return total / sessions.length;
  }

  @override
  Widget build(BuildContext context) {
    final sessions = mockSessions;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'History',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Review previous noise exposure sessions.',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Sessions',
                    value: '${sessions.length}',
                    icon: Icons.history,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Avg dB',
                    value: '${_averageDb(sessions).toStringAsFixed(0)} dB',
                    icon: Icons.graphic_eq,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    title: 'High Risk',
                    value: '${_highRiskCount(sessions)}',
                    icon: Icons.warning_amber_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Latest',
                    value: sessions.first.date,
                    icon: Icons.calendar_today,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Text(
              'Recorded Sessions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: ListView.builder(
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final session = sessions[index];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: _riskColor(
                              session.riskLevel,
                            ).withOpacity(0.15),
                            child: Icon(
                              Icons.volume_up,
                              color: _riskColor(session.riskLevel),
                            ),
                          ),
                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session.place,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text('Date: ${session.date}'),
                                Text('Average Level: ${session.averageDb} dB'),
                                Text('Duration: ${session.duration}'),
                              ],
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _riskColor(
                                session.riskLevel,
                              ).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              session.riskLevel,
                              style: TextStyle(
                                color: _riskColor(session.riskLevel),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
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
            Text(title, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
