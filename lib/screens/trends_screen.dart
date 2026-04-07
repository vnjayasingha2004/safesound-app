import 'package:flutter/material.dart';

import '../app/monitor_settings.dart';
import '../data/session_store.dart';
import '../models/session_model.dart';

class TrendsScreen extends StatelessWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder<List<SessionModel>>(
        valueListenable: sessionHistoryNotifier,
        builder: (context, sessions, _) {
          return ValueListenableBuilder<double>(
            valueListenable: alertThresholdNotifier,
            builder: (context, threshold, __) {
              final recentSessions = sessions
                  .take(7)
                  .toList()
                  .reversed
                  .toList();

              final recentAverage = recentSessions.isEmpty
                  ? 0.0
                  : recentSessions.fold<double>(
                          0.0,
                          (sum, session) => sum + session.averageDb,
                        ) /
                        recentSessions.length;

              final previousSessions = sessions.skip(7).take(7).toList();
              final previousAverage = previousSessions.isEmpty
                  ? 0.0
                  : previousSessions.fold<double>(
                          0.0,
                          (sum, session) => sum + session.averageDb,
                        ) /
                        previousSessions.length;

              final highestDb = sessions.isEmpty
                  ? 0
                  : sessions
                        .map((session) => session.averageDb)
                        .reduce((a, b) => a > b ? a : b);

              final overLimitCount = sessions
                  .where((session) => session.averageDb >= threshold)
                  .length;

              final safeCount = sessions
                  .where(
                    (session) =>
                        session.riskLevel.toLowerCase().contains('safe'),
                  )
                  .length;

              final moderateCount = sessions
                  .where(
                    (session) =>
                        session.riskLevel.toLowerCase().contains('moderate'),
                  )
                  .length;

              final highCount = sessions
                  .where(
                    (session) =>
                        session.riskLevel.toLowerCase().contains('high'),
                  )
                  .length;

              final placeStats = _buildPlaceStats(sessions);
              final weekdayStats = _buildWeekdayStats(sessions);
              final trendSummary = _buildTrendSummary(
                recentAverage: recentAverage,
                previousAverage: previousAverage,
                threshold: threshold,
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    const Text(
                      'Trends',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Analytics view for your saved SafeSound sessions.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (sessions.isEmpty)
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.show_chart,
                                size: 52,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No trend data yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Save a few Live Monitor sessions and this page will turn into real analytics.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (sessions.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: LinearGradient(
                            colors: [
                              trendSummary.color.withOpacity(0.95),
                              trendSummary.color.withOpacity(0.72),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(trendSummary.icon, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    trendSummary.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              trendSummary.message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Recent Avg',
                              value: '${recentAverage.round()} dB',
                              icon: Icons.graphic_eq,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Highest',
                              value: '$highestDb dB',
                              icon: Icons.bolt,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Over Limit',
                              value: '$overLimitCount',
                              icon: Icons.notifications_active_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Sessions',
                              value: '${sessions.length}',
                              icon: Icons.history,
                            ),
                          ),
                        ],
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
                                  Icon(Icons.bar_chart_rounded),
                                  SizedBox(width: 8),
                                  Text(
                                    'Last 7 Sessions',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Bar height shows average dB for each saved session.',
                                style: TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 16),
                              _buildSessionBars(recentSessions, threshold),
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
                                  Icon(Icons.donut_large),
                                  SizedBox(width: 8),
                                  Text(
                                    'Risk Distribution',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _buildProgressRow(
                                label: 'Safe',
                                count: safeCount,
                                total: sessions.length,
                                color: Colors.green,
                              ),
                              const SizedBox(height: 12),
                              _buildProgressRow(
                                label: 'Moderate',
                                count: moderateCount,
                                total: sessions.length,
                                color: Colors.orange,
                              ),
                              const SizedBox(height: 12),
                              _buildProgressRow(
                                label: 'High',
                                count: highCount,
                                total: sessions.length,
                                color: Colors.red,
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
                                  Icon(Icons.place_outlined),
                                  SizedBox(width: 8),
                                  Text(
                                    'Noisiest Places',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ...placeStats
                                  .take(3)
                                  .map(
                                    (place) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              place.place,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${place.averageDb.round()} dB avg',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            '${place.count}x',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined),
                                  SizedBox(width: 8),
                                  Text(
                                    'Activity by Weekday',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ...weekdayStats.entries.map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildWeekdayRow(
                                    label: entry.key,
                                    count: entry.value,
                                    maxCount: weekdayStats.values.fold<int>(
                                      0,
                                      (max, value) => value > max ? value : max,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
      ),
    );
  }

  static List<_PlaceStat> _buildPlaceStats(List<SessionModel> sessions) {
    final Map<String, List<SessionModel>> grouped = {};

    for (final session in sessions) {
      grouped.putIfAbsent(session.place, () => []).add(session);
    }

    final stats = grouped.entries.map((entry) {
      final average =
          entry.value.fold<double>(
            0.0,
            (sum, session) => sum + session.averageDb,
          ) /
          entry.value.length;

      return _PlaceStat(
        place: entry.key,
        averageDb: average,
        count: entry.value.length,
      );
    }).toList();

    stats.sort((a, b) => b.averageDb.compareTo(a.averageDb));
    return stats;
  }

  static Map<String, int> _buildWeekdayStats(List<SessionModel> sessions) {
    final stats = <String, int>{
      'Mon': 0,
      'Tue': 0,
      'Wed': 0,
      'Thu': 0,
      'Fri': 0,
      'Sat': 0,
      'Sun': 0,
    };

    for (final session in sessions) {
      final date = DateTime.tryParse(session.createdAt);
      if (date == null) continue;

      switch (date.weekday) {
        case DateTime.monday:
          stats['Mon'] = stats['Mon']! + 1;
          break;
        case DateTime.tuesday:
          stats['Tue'] = stats['Tue']! + 1;
          break;
        case DateTime.wednesday:
          stats['Wed'] = stats['Wed']! + 1;
          break;
        case DateTime.thursday:
          stats['Thu'] = stats['Thu']! + 1;
          break;
        case DateTime.friday:
          stats['Fri'] = stats['Fri']! + 1;
          break;
        case DateTime.saturday:
          stats['Sat'] = stats['Sat']! + 1;
          break;
        case DateTime.sunday:
          stats['Sun'] = stats['Sun']! + 1;
          break;
      }
    }

    return stats;
  }

  static _TrendSummary _buildTrendSummary({
    required double recentAverage,
    required double previousAverage,
    required double threshold,
  }) {
    if (previousAverage == 0) {
      if (recentAverage >= threshold) {
        return const _TrendSummary(
          title: 'Strong caution needed',
          message:
              'Your recent saved sessions are already above your current threshold. Reduce loud exposure before it becomes a regular pattern.',
          color: Colors.red,
          icon: Icons.warning_amber_rounded,
        );
      }

      return const _TrendSummary(
        title: 'Trend data is building',
        message:
            'Keep saving sessions. After a few more entries, SafeSound will show stronger trend comparisons.',
        color: Colors.blue,
        icon: Icons.insights,
      );
    }

    final difference = recentAverage - previousAverage;

    if (difference >= 5) {
      return const _TrendSummary(
        title: 'Exposure is getting worse',
        message:
            'Your more recent sessions are noticeably louder than the previous set. This trend should be corrected early.',
        color: Colors.red,
        icon: Icons.trending_up,
      );
    }

    if (difference <= -5) {
      return const _TrendSummary(
        title: 'Exposure is improving',
        message:
            'Your recent sessions are quieter than before. Keep this pattern going and respond early to alerts.',
        color: Colors.green,
        icon: Icons.trending_down,
      );
    }

    return const _TrendSummary(
      title: 'Exposure is staying steady',
      message:
          'Your recent sessions are close to your earlier pattern. Small changes now can still improve long-term listening safety.',
      color: Colors.orange,
      icon: Icons.trending_flat,
    );
  }

  Widget _buildSessionBars(List<SessionModel> sessions, double threshold) {
    if (sessions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No saved sessions available for chart.'),
      );
    }

    final maxDb = sessions
        .map((session) => session.averageDb.toDouble())
        .fold<double>(threshold, (max, value) => value > max ? value : max);

    return SizedBox(
      height: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: sessions.map((session) {
          final ratio = maxDb == 0 ? 0.0 : session.averageDb / maxDb;
          final isOver = session.averageDb >= threshold;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${session.averageDb}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 140 * ratio,
                    decoration: BoxDecoration(
                      color: isOver ? Colors.red : Colors.blue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    session.date,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMetricCard({
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

  Widget _buildProgressRow({
    required String label,
    required int count,
    required int total,
    required Color color,
  }) {
    final progress = total == 0 ? 0.0 : count / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label Sessions ($count)',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdayRow({
    required String label,
    required int count,
    required int maxCount,
  }) {
    final progress = maxCount == 0 ? 0.0 : count / maxCount;

    return Row(
      children: [
        SizedBox(
          width: 42,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey.shade300,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text('$count'),
      ],
    );
  }
}

class _PlaceStat {
  final String place;
  final double averageDb;
  final int count;

  const _PlaceStat({
    required this.place,
    required this.averageDb,
    required this.count,
  });
}

class _TrendSummary {
  final String title;
  final String message;
  final Color color;
  final IconData icon;

  const _TrendSummary({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
  });
}
