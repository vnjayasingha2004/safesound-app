import 'package:flutter/material.dart';
import '../models/session_model.dart';
import 'mock_sessions.dart';

final ValueNotifier<List<SessionModel>> sessionHistoryNotifier = ValueNotifier(
  List<SessionModel>.from(mockSessions),
);

void addSessionToHistory(SessionModel session) {
  sessionHistoryNotifier.value = [session, ...sessionHistoryNotifier.value];
}
