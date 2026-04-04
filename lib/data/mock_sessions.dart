import '../models/session_model.dart';

const List<SessionModel> mockSessions = [
  SessionModel(
    date: 'Oct 24',
    place: 'Factory Floor',
    averageDb: 88,
    duration: '2h 45m',
    riskLevel: 'High',
  ),
  SessionModel(
    date: 'Oct 23',
    place: 'Main Road',
    averageDb: 76,
    duration: '45m',
    riskLevel: 'Moderate',
  ),
  SessionModel(
    date: 'Oct 22',
    place: 'Lecture Hall',
    averageDb: 55,
    duration: '1h 30m',
    riskLevel: 'Safe',
  ),
  SessionModel(
    date: 'Oct 21',
    place: 'Gym',
    averageDb: 82,
    duration: '1h 10m',
    riskLevel: 'Moderate',
  ),
  SessionModel(
    date: 'Oct 20',
    place: 'Construction Area',
    averageDb: 92,
    duration: '3h 10m',
    riskLevel: 'High',
  ),
];
