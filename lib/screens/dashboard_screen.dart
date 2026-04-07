import 'package:flutter/material.dart';

import '../app/monitor_settings.dart';
import '../data/session_store.dart';
import '../models/session_model.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
                      final now = DateTime.now();
                      final startOfWeek = _startOfWeek(now);

                      final weeklySessions = sessions.where((session) {
                        final createdAt = _parseCreatedAt(session.createdAt);
                        return !createdAt.isBefore(startOfWeek);
                      }).toList();

                      final mostCommonSoundType = _mostCommonSoundType(
                        weeklySessions,
                      );
                      final riskiestSoundType = _riskiestSoundType(
                        weeklySessions,
                      );

                      final latestSession = sessions.isEmpty
                          ? null
                          : sessions.first;

                      final SessionModel? loudestWeekSession =
                          weeklySessions.isEmpty
                          ? null
                          : weeklySessions.reduce(
                              (a, b) => a.peakDb >= b.peakDb ? a : b,
                            );

                      final weeklyCount = weeklySessions.length;

                      final weeklyAverage = weeklyCount == 0
                          ? 0.0
                          : weeklySessions.fold<double>(
                                  0.0,
                                  (sum, item) => sum + item.averageDb,
                                ) /
                                weeklyCount;

                      final weeklyAverageExposureScore = weeklyCount == 0
                          ? 0.0
                          : weeklySessions.fold<double>(
                                  0.0,
                                  (sum, item) => sum + item.exposureScore,
                                ) /
                                weeklyCount;

                      final weeklyAlertCount = weeklySessions.fold<int>(
                        0,
                        (sum, item) => sum + item.unsafeAlertCount,
                      );

                      final overLimitCount = weeklySessions
                          .where((s) => s.averageDb >= threshold)
                          .length;

                      final highRiskCount = weeklySessions
                          .where(
                            (s) => s.riskLevel.toLowerCase().contains('high'),
                          )
                          .length;

                      final moderateCount = weeklySessions
                          .where(
                            (s) =>
                                s.riskLevel.toLowerCase().contains('moderate'),
                          )
                          .length;

                      final weeklySeconds = weeklySessions.fold<int>(
                        0,
                        (sum, item) =>
                            sum + _parseDurationToSeconds(item.duration),
                      );

                      final safetyScore = _calculateSafetyScore(
                        weeklyAverage: weeklyAverage,
                        overLimitCount: overLimitCount,
                        highRiskCount: highRiskCount,
                        weeklyAlertCount: weeklyAlertCount,
                        averageExposureScore: weeklyAverageExposureScore,
                        threshold: threshold,
                        usesHearingAid: usesHearingAid,
                      );

                      final scoreColor = _scoreColor(safetyScore);
                      final scoreLabel = _scoreLabel(safetyScore);

                      final recommendation = _buildRecommendation(
                        weeklyAverage: weeklyAverage,
                        overLimitCount: overLimitCount,
                        highRiskCount: highRiskCount,
                        moderateCount: moderateCount,
                        weeklyAlertCount: weeklyAlertCount,
                        averageExposureScore: weeklyAverageExposureScore,
                        threshold: threshold,
                        ageGroup: ageGroup,
                        usesHearingAid: usesHearingAid,
                      );

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            const Text(
                              'Dashboard',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Your personalized SafeSound coach summary.',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 20),

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: LinearGradient(
                                  colors: [
                                    scoreColor.withOpacity(0.95),
                                    scoreColor.withOpacity(0.70),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Weekly Safety Score',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '$safetyScore',
                                        style: const TextStyle(
                                          fontSize: 48,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          height: 1,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Padding(
                                        padding: EdgeInsets.only(bottom: 6),
                                        child: Text(
                                          '/100',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.16),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Text(
                                      scoreLabel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Threshold: ${threshold.toInt()} dB  •  Profile: $ageGroup${usesHearingAid ? ' • Hearing Aid' : ''}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: _buildMiniCard(
                                    title: 'This Week',
                                    value: '$weeklyCount sessions',
                                    icon: Icons.calendar_view_week,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildMiniCard(
                                    title: 'Avg Exposure',
                                    value: '${weeklyAverage.round()} dB',
                                    icon: Icons.graphic_eq,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: _buildMiniCard(
                                    title: 'Unsafe Alerts',
                                    value: '$weeklyAlertCount',
                                    icon: Icons.warning_amber_rounded,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildMiniCard(
                                    title: 'Coach Load',
                                    value:
                                        '${weeklyAverageExposureScore.round()}/100',
                                    icon: Icons.psychology_alt_outlined,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildQuickMetric(
                                        title: 'Monitor Time',
                                        value: _formatDuration(weeklySeconds),
                                        color: Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildQuickMetric(
                                        title: 'Over Limit',
                                        value: '$overLimitCount times',
                                        color: Colors.deepPurple,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.tips_and_updates_outlined),
                                        SizedBox(width: 8),
                                        Text(
                                          'Weekly Coach Insight',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      recommendation,
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.pie_chart_outline),
                                        SizedBox(width: 8),
                                        Text(
                                          'Exposure Breakdown',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    _buildProgressRow(
                                      label: 'Safe Sessions',
                                      count:
                                          weeklyCount -
                                          moderateCount -
                                          highRiskCount,
                                      total: weeklyCount,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildProgressRow(
                                      label: 'Moderate Sessions',
                                      count: moderateCount,
                                      total: weeklyCount,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildProgressRow(
                                      label: 'High Risk Sessions',
                                      count: highRiskCount,
                                      total: weeklyCount,
                                      color: Colors.red,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            if (loudestWeekSession != null) ...[
                              const SizedBox(height: 16),
                              Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.volume_up_outlined),
                                          SizedBox(width: 8),
                                          Text(
                                            'Loudest Place This Week',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        loudestWeekSession.place,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${loudestWeekSession.peakDb} dB peak • ${loudestWeekSession.averageDb} dB avg',
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        loudestWeekSession.coachSummary.isEmpty
                                            ? loudestWeekSession.riskLevel
                                            : loudestWeekSession.coachSummary,
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),

                            Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.surround_sound_outlined),
                                        SizedBox(width: 8),
                                        Text(
                                          'Sound Scene Summary',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'Most common: $mostCommonSoundType',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Riskiest source: $riskiestSoundType',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: latestSession == null
                                    ? Column(
                                        children: [
                                          Icon(
                                            Icons.home_outlined,
                                            size: 48,
                                            color: Colors.grey.shade500,
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            'No recent session yet',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Start Live Monitor and save a session to make your dashboard come alive.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Row(
                                            children: [
                                              Icon(Icons.access_time_outlined),
                                              SizedBox(width: 8),
                                              Text(
                                                'Latest Saved Session',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 14),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: _riskColor(
                                                latestSession.riskLevel,
                                              ).withOpacity(0.08),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  latestSession.place,
                                                  style: const TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  '${latestSession.averageDb} dB avg • ${latestSession.peakDb} dB peak',
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${latestSession.date} • ${latestSession.duration}',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                Text(
                                                  'Conversation: ${latestSession.conversationStatus}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'Sound scene: ${latestSession.soundType}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'Confidence: ${(latestSession.soundTypeConfidence * 100).round()}%',
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'Safe time guide: ${latestSession.remainingSafeTimeLabel}',
                                                ),
                                                if (latestSession.coachSummary
                                                    .trim()
                                                    .isNotEmpty) ...[
                                                  const SizedBox(height: 10),
                                                  Text(
                                                    latestSession.coachSummary,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
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

  int _calculateSafetyScore({
    required double weeklyAverage,
    required int overLimitCount,
    required int highRiskCount,
    required int weeklyAlertCount,
    required double averageExposureScore,
    required double threshold,
    required bool usesHearingAid,
  }) {
    int score = 100;

    if (weeklyAverage >= threshold) {
      score -= 25;
    } else if (weeklyAverage >= threshold - 5) {
      score -= 15;
    } else if (weeklyAverage >= 75) {
      score -= 8;
    }

    score -= overLimitCount * 6;
    score -= highRiskCount * 8;
    score -= weeklyAlertCount * 4;
    score -= (averageExposureScore ~/ 10) * 3;

    if (usesHearingAid) {
      score -= overLimitCount * 3;
      score -= weeklyAlertCount * 2;
    }

    if (score < 0) return 0;
    if (score > 100) return 100;
    return score;
  }

  String _scoreLabel(int score) {
    if (score >= 85) return 'Excellent';
    if (score >= 70) return 'Good';
    if (score >= 50) return 'Needs Attention';
    return 'High Risk';
  }

  Color _scoreColor(int score) {
    if (score >= 85) return Colors.green;
    if (score >= 70) return Colors.blue;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  String _buildRecommendation({
    required double weeklyAverage,
    required int overLimitCount,
    required int highRiskCount,
    required int moderateCount,
    required int weeklyAlertCount,
    required double averageExposureScore,
    required double threshold,
    required String ageGroup,
    required bool usesHearingAid,
  }) {
    if (highRiskCount >= 2 || weeklyAlertCount >= 3) {
      return 'You had repeated unsafe moments this week. Shorter stays, quieter routes, and faster reactions to alerts should be your priority.';
    }

    if (usesHearingAid && overLimitCount >= 1) {
      return 'Because hearing aid support is enabled, try to stay clearly below ${threshold.toInt()} dB and reduce repeated loud exposures.';
    }

    if (ageGroup == '61+' && weeklyAverage >= 75) {
      return 'Your weekly exposure is a bit high for your selected profile. Safer listening this week would mean shorter sessions and earlier breaks.';
    }

    if (averageExposureScore >= 50 ||
        moderateCount >= 2 ||
        weeklyAverage >= threshold - 5) {
      return 'Your coach load is trending upward. This is a good week to cut back on noisy places before it becomes a repeated pattern.';
    }

    return 'You are doing well. Keep saving sessions so SafeSound can keep learning your routines and giving better day-to-day advice.';
  }

  String _mostCommonSoundType(List<SessionModel> sessions) {
    if (sessions.isEmpty) return 'No data';

    final counts = <String, int>{};
    for (final session in sessions) {
      counts[session.soundType] = (counts[session.soundType] ?? 0) + 1;
    }

    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String _riskiestSoundType(List<SessionModel> sessions) {
    if (sessions.isEmpty) return 'No data';

    final totals = <String, int>{};
    for (final session in sessions) {
      totals[session.soundType] =
          (totals[session.soundType] ?? 0) + session.exposureScore;
    }

    return totals.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  static DateTime _startOfWeek(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: date.weekday - 1));
  }

  static DateTime _parseCreatedAt(String value) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }

  static int _parseDurationToSeconds(String value) {
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

  Widget _buildMiniCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 10),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickMetric({
    required String title,
    required String value,
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
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(title, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildProgressRow({
    required String label,
    required int count,
    required int total,
    required Color color,
  }) {
    final safeCount = count < 0 ? 0 : count;
    final safeTotal = total == 0 ? 1 : total;
    final progress = safeCount / safeTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label ($safeCount)',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Color _riskColor(String riskLevel) {
    final value = riskLevel.toLowerCase();

    if (value.contains('high')) return Colors.red;
    if (value.contains('moderate')) return Colors.orange;
    return Colors.green;
  }
}
