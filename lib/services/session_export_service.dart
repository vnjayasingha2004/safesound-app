import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/session_model.dart';

class SessionExportService {
  static Future<File> buildCsvFile(List<SessionModel> sessions) async {
    final rows = <List<String>>[
      [
        'Date',
        'Location',
        'Average dB',
        'Peak dB',
        'Duration',
        'Risk Level',
        'Unsafe Alerts',
        'Exposure Score',
        'Conversation Status',
        'Sound Type',
        'Sound Confidence',
        'Remaining Safe Time',
        'Coach Summary',
        'Created At',
      ],
      ...sessions.map(
        (session) => [
          session.date,
          session.place,
          session.averageDb.toString(),
          session.peakDb.toString(),
          session.duration,
          session.riskLevel,
          session.unsafeAlertCount.toString(),
          session.exposureScore.toString(),
          session.conversationStatus,
          session.soundType,
          session.soundTypeConfidence.toStringAsFixed(3),
          session.remainingSafeTimeLabel,
          session.coachSummary,
          session.createdAt,
        ],
      ),
    ];

    final csvContent = rows.map(_toCsvRow).join('\n');

    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/safesound_sessions_$timestamp.csv');

    await file.writeAsString(csvContent, flush: true);
    return file;
  }

  static Future<void> exportAndShare(List<SessionModel> sessions) async {
    if (sessions.isEmpty) {
      throw Exception('No saved sessions available to export.');
    }

    final file = await buildCsvFile(sessions);

    await SharePlus.instance.share(
      ShareParams(
        title: 'SafeSound Session Report',
        text: 'SafeSound session history export',
        files: [XFile(file.path)],
      ),
    );
  }

  static String _toCsvRow(List<String> values) {
    return values.map(_escapeCsvValue).join(',');
  }

  static String _escapeCsvValue(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}
