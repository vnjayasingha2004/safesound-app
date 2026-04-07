class SessionModel {
  final String date;
  final String place;
  final int averageDb;
  final int peakDb;
  final String duration;
  final String riskLevel;
  final String createdAt;
  final int unsafeAlertCount;
  final int exposureScore;
  final String conversationStatus;
  final String coachSummary;
  final String remainingSafeTimeLabel;
  final String soundType;
  final double soundTypeConfidence;

  const SessionModel({
    required this.date,
    required this.place,
    required this.averageDb,
    required this.duration,
    required this.riskLevel,
    required this.createdAt,
    this.peakDb = 0,
    this.unsafeAlertCount = 0,
    this.exposureScore = 0,
    this.conversationStatus = 'Unknown',
    this.coachSummary = '',
    this.remainingSafeTimeLabel = 'Unknown',
    this.soundType = 'Unknown',
    this.soundTypeConfidence = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'place': place,
      'averageDb': averageDb,
      'peakDb': peakDb,
      'duration': duration,
      'riskLevel': riskLevel,
      'createdAt': createdAt,
      'unsafeAlertCount': unsafeAlertCount,
      'exposureScore': exposureScore,
      'conversationStatus': conversationStatus,
      'coachSummary': coachSummary,
      'remainingSafeTimeLabel': remainingSafeTimeLabel,
      'soundType': soundType,
      'soundTypeConfidence': soundTypeConfidence,
    };
  }

  factory SessionModel.fromMap(Map<String, dynamic> map) {
    final averageDb = (map['averageDb'] as num?)?.toInt() ?? 0;

    return SessionModel(
      date: map['date'] as String? ?? '',
      place: map['place'] as String? ?? '',
      averageDb: averageDb,
      peakDb: (map['peakDb'] as num?)?.toInt() ?? averageDb,
      duration: map['duration'] as String? ?? '00:00:00',
      riskLevel: map['riskLevel'] as String? ?? 'Safe',
      createdAt:
          map['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      unsafeAlertCount: (map['unsafeAlertCount'] as num?)?.toInt() ?? 0,
      exposureScore: (map['exposureScore'] as num?)?.toInt() ?? 0,
      conversationStatus: map['conversationStatus'] as String? ?? 'Unknown',
      coachSummary: map['coachSummary'] as String? ?? '',
      remainingSafeTimeLabel:
          map['remainingSafeTimeLabel'] as String? ?? 'Unknown',
      soundType: map['soundType'] as String? ?? 'Unknown',
      soundTypeConfidence:
          (map['soundTypeConfidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
