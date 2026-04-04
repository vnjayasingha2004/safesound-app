class SessionModel {
  final String date;
  final String place;
  final int averageDb;
  final String duration;
  final String riskLevel;

  const SessionModel({
    required this.date,
    required this.place,
    required this.averageDb,
    required this.duration,
    required this.riskLevel,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'place': place,
      'averageDb': averageDb,
      'duration': duration,
      'riskLevel': riskLevel,
    };
  }

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      date: json['date'] as String,
      place: json['place'] as String,
      averageDb: json['averageDb'] as int,
      duration: json['duration'] as String,
      riskLevel: json['riskLevel'] as String,
    );
  }
}
