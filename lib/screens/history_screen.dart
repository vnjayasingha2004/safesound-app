import 'package:flutter/material.dart';
import 'package:safesound_app/services/session_export_service.dart';

import '../app/monitor_settings.dart';
import '../data/session_store.dart';
import '../models/session_model.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder<List<SessionModel>>(
        valueListenable: sessionHistoryNotifier,
        builder: (context, sessions, _) {
          return ValueListenableBuilder<double>(
            valueListenable: alertThresholdNotifier,
            builder: (context, threshold, __) {
              return ValueListenableBuilder<String>(
                valueListenable: ageGroupNotifier,
                builder: (context, ageGroup, ___) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: usesHearingAidNotifier,
                    builder: (context, usesHearingAid, ____) {
                      final recentSessions = sessions.take(7).toList();

                      final int totalSessions = sessions.length;

                      final double averageExposure = totalSessions == 0
                          ? 0
                          : sessions
                                    .map((s) => s.averageDb.toDouble())
                                    .reduce((a, b) => a + b) /
                                totalSessions;

                      final double recentAverage = recentSessions.isEmpty
                          ? 0
                          : recentSessions
                                    .map((s) => s.averageDb.toDouble())
                                    .reduce((a, b) => a + b) /
                                recentSessions.length;

                      final int highRiskSessions = recentSessions
                          .where(
                            (s) => s.riskLevel.toLowerCase().contains('high'),
                          )
                          .length;

                      final int moderateSessions = recentSessions
                          .where(
                            (s) =>
                                s.riskLevel.toLowerCase().contains('moderate'),
                          )
                          .length;

                      final int overThresholdSessions = recentSessions
                          .where((s) => s.averageDb >= threshold)
                          .length;

                      final int recentUnsafeAlerts = recentSessions.fold(
                        0,
                        (sum, session) => sum + session.unsafeAlertCount,
                      );

                      final int totalRecentSeconds = recentSessions.fold(
                        0,
                        (sum, session) =>
                            sum + _parseDurationSeconds(session.duration),
                      );

                      final double averageExposureScore = recentSessions.isEmpty
                          ? 0
                          : recentSessions
                                    .map((s) => s.exposureScore.toDouble())
                                    .reduce((a, b) => a + b) /
                                recentSessions.length;

                      final SessionModel? loudestSession = sessions.isEmpty
                          ? null
                          : sessions.reduce(
                              (a, b) => a.peakDb >= b.peakDb ? a : b,
                            );

                      final SessionModel? latestSession = sessions.isEmpty
                          ? null
                          : sessions.first;

                      final _InsightMessage insight = _buildInsightMessage(
                        recentAverage: recentAverage,
                        highRiskSessions: highRiskSessions,
                        moderateSessions: moderateSessions,
                        overThresholdSessions: overThresholdSessions,
                        recentUnsafeAlerts: recentUnsafeAlerts,
                        averageExposureScore: averageExposureScore,
                        threshold: threshold,
                        usesHearingAid: usesHearingAid,
                        ageGroup: ageGroup,
                      );

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'History & Insights',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Your saved sessions, coach summaries, and exposure patterns.',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 20),

                            Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Recent Exposure Insights',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildStatCard(
                                            title: 'All Sessions',
                                            value: '$totalSessions',
                                            icon: Icons.history,
                                            color: Colors.blue,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildStatCard(
                                            title: 'Recent Avg',
                                            value:
                                                '${recentAverage.round()} dB',
                                            icon: Icons.graphic_eq,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildStatCard(
                                            title: 'Unsafe Alerts',
                                            value: '$recentUnsafeAlerts',
                                            icon: Icons.warning_amber_rounded,
                                            color: Colors.red,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildStatCard(
                                            title: 'Coach Load',
                                            value:
                                                '${averageExposureScore.round()}/100',
                                            icon: Icons.psychology_alt_outlined,
                                            color: Colors.deepPurple,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Recent monitoring time: ${_formatDuration(totalRecentSeconds)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Overall saved average: ${averageExposure.round()} dB',
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Current threshold: ${threshold.toInt()} dB',
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Profile: $ageGroup • Hearing aid ${usesHearingAid ? 'Yes' : 'No'}',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: insight.color.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: insight.color.withOpacity(0.35),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(insight.icon, color: insight.color),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          insight.title,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: insight.color,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    insight.message,
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            if (loudestSession != null)
                              Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Loudest Saved Session',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        '${loudestSession.peakDb} dB peak at ${loudestSession.place}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${loudestSession.date} • ${loudestSession.duration} • ${loudestSession.riskLevel}',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      if (loudestSession.coachSummary
                                          .trim()
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Text(loudestSession.coachSummary),
                                      ],
                                    ],
                                  ),
                                ),
                              ),

                            if (latestSession != null) ...[
                              const SizedBox(height: 16),
                              Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Latest Coach Summary',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        latestSession.coachSummary.isEmpty
                                            ? 'No coach summary saved yet.'
                                            : latestSession.coachSummary,
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),

                            Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Saved Session History',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'These are your real monitoring sessions.',
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (sessions.isNotEmpty)
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          TextButton.icon(
                                            onPressed: () async {
                                              try {
                                                await SessionExportService.exportAndShare(
                                                  sessions,
                                                );

                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'CSV export ready to share',
                                                    ),
                                                  ),
                                                );
                                              } catch (error) {
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Export failed: $error',
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                            icon: const Icon(
                                              Icons.ios_share_outlined,
                                            ),
                                            label: const Text('Export'),
                                          ),
                                          TextButton.icon(
                                            onPressed: () async {
                                              await clearSessionHistory();
                                            },
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                            label: const Text('Clear'),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            if (sessions.isEmpty)
                              Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.insights_outlined,
                                        size: 52,
                                        color: Colors.grey.shade500,
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'No saved sessions yet',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Start Live Monitor, stop a session, and save it to view insights here.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            if (sessions.isNotEmpty)
                              ...sessions.map(_buildSessionCard),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  static int _parseDurationSeconds(String value) {
    final parts = value.split(':');
    if (parts.length != 3) return 0;

    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    final seconds = int.tryParse(parts[2]) ?? 0;

    return (hours * 3600) + (minutes * 60) + seconds;
  }

  static String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final h = hours.toString().padLeft(2, '0');
    final m = minutes.toString().padLeft(2, '0');
    final s = seconds.toString().padLeft(2, '0');

    return '$h:$m:$s';
  }

  static _InsightMessage _buildInsightMessage({
    required double recentAverage,
    required int highRiskSessions,
    required int moderateSessions,
    required int overThresholdSessions,
    required int recentUnsafeAlerts,
    required double averageExposureScore,
    required double threshold,
    required bool usesHearingAid,
    required String ageGroup,
  }) {
    if (recentUnsafeAlerts >= 3 || highRiskSessions >= 3) {
      return _InsightMessage(
        title: 'Repeated unsafe pattern detected',
        message:
            'Your recent sessions triggered several unsafe events. Try shorter visits, quieter routes, or ear protection before this becomes a routine problem.',
        color: Colors.red,
        icon: Icons.warning_amber_rounded,
      );
    }

    if (usesHearingAid && overThresholdSessions >= 1) {
      return _InsightMessage(
        title: 'Extra caution recommended',
        message:
            'Because hearing aid support is enabled, even one recent over-limit session deserves attention. Try to stay comfortably below ${threshold.toInt()} dB when possible.',
        color: Colors.deepPurple,
        icon: Icons.hearing,
      );
    }

    if (ageGroup == '61+' && recentAverage >= 75) {
      return _InsightMessage(
        title: 'Safer listening advised',
        message:
            'Your recent average is a little high for your selected age profile. Earlier breaks and shorter sessions would be a good next step.',
        color: Colors.orange,
        icon: Icons.health_and_safety_outlined,
      );
    }

    if (averageExposureScore >= 50 ||
        overThresholdSessions >= 2 ||
        moderateSessions >= 3) {
      return _InsightMessage(
        title: 'Exposure is trending upward',
        message:
            'You are not always in the danger zone, but your recent coach load is rising. This is the right moment to adjust your routine before it turns into repeated risk.',
        color: Colors.orange,
        icon: Icons.trending_up,
      );
    }

    return _InsightMessage(
      title: 'Good recent listening pattern',
      message:
          'Your recent sessions look relatively controlled. Keep saving sessions so SafeSound can build stronger personal coach insights for your daily routine.',
      color: Colors.green,
      icon: Icons.check_circle,
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(title, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildSessionCard(SessionModel session) {
    final badgeColor = _riskColor(session.riskLevel);
    final exposureColor = _exposureColor(session.exposureScore);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: badgeColor.withOpacity(0.12),
                child: Icon(Icons.volume_up, color: badgeColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.place,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${session.date} • ${session.duration}'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildBadge(
                          '${session.averageDb} dB avg',
                          Colors.grey.shade200,
                          Colors.black87,
                        ),
                        _buildBadge(
                          '${session.peakDb} dB peak',
                          Colors.deepPurple.withOpacity(0.10),
                          Colors.deepPurple,
                        ),
                        _buildBadge(
                          '${session.unsafeAlertCount} alerts',
                          session.unsafeAlertCount > 0
                              ? Colors.red.withOpacity(0.10)
                              : Colors.green.withOpacity(0.10),
                          session.unsafeAlertCount > 0
                              ? Colors.red
                              : Colors.green,
                        ),
                        _buildBadge(
                          'Load ${session.exposureScore}/100',
                          exposureColor.withOpacity(0.10),
                          exposureColor,
                        ),
                        _buildBadge(
                          session.riskLevel,
                          badgeColor.withOpacity(0.10),
                          badgeColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Conversation: ${session.conversationStatus}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Safe time guide: ${session.remainingSafeTimeLabel}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    if (session.coachSummary.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        session.coachSummary,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }

  Color _riskColor(String riskLevel) {
    final value = riskLevel.toLowerCase();

    if (value.contains('high')) return Colors.red;
    if (value.contains('moderate')) return Colors.orange;
    return Colors.green;
  }

  Color _exposureColor(int score) {
    if (score >= 75) return Colors.red;
    if (score >= 50) return Colors.orange;
    if (score >= 25) return Colors.blue;
    return Colors.green;
  }
}

class _InsightMessage {
  final String title;
  final String message;
  final Color color;
  final IconData icon;

  const _InsightMessage({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
  });
}
