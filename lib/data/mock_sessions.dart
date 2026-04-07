import '../models/session_model.dart';

const List<SessionModel> mockSessions = [
  final newSession = SessionModel(
  date: _formatDate(now),
  place: _locationLabel,
  averageDb: _averageDb.round(),
  peakDb: _peakDb,
  duration: _formatDuration(_secondsElapsed),
  riskLevel: _sessionRiskStatus,
  createdAt: now.toIso8601String(),
  unsafeAlertCount: _unsafeAlertCount,
  exposureScore: _exposureScore,
  conversationStatus: _conversationStatus,
  coachSummary: _coachSummary,
  remainingSafeTimeLabel: _remainingSafeTimeLabel,
);
];
