import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_model.dart';
import 'mock_sessions.dart';

final ValueNotifier<List<SessionModel>> sessionHistoryNotifier = ValueNotifier(
  [],
);

const String _sessionStorageKey = 'saved_sessions';

Future<void> initializeSessionHistory() async {
  final prefs = await SharedPreferences.getInstance();
  final storedSessions = prefs.getString(_sessionStorageKey);

  if (storedSessions == null || storedSessions.isEmpty) {
    sessionHistoryNotifier.value = List<SessionModel>.from(mockSessions);
    await _saveSessionsToStorage(sessionHistoryNotifier.value);
    return;
  }

  final List<dynamic> decoded = jsonDecode(storedSessions);
  sessionHistoryNotifier.value = decoded
      .map((item) => SessionModel.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}

Future<void> addSessionToHistory(SessionModel session) async {
  final updatedSessions = [session, ...sessionHistoryNotifier.value];
  sessionHistoryNotifier.value = updatedSessions;
  await _saveSessionsToStorage(updatedSessions);
}

Future<void> clearAllSessions() async {
  sessionHistoryNotifier.value = [];
  await _saveSessionsToStorage([]);
}

Future<void> _saveSessionsToStorage(List<SessionModel> sessions) async {
  final prefs = await SharedPreferences.getInstance();
  final encoded = jsonEncode(
    sessions.map((session) => session.toJson()).toList(),
  );
  await prefs.setString(_sessionStorageKey, encoded);
}
