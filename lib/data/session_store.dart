import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/session_model.dart';

final ValueNotifier<List<SessionModel>> sessionHistoryNotifier =
    ValueNotifier<List<SessionModel>>([]);

const String _sessionHistoryKey = 'session_history';

Future<void> initializeSessionHistory() async {
  final prefs = await SharedPreferences.getInstance();
  final storedList = prefs.getStringList(_sessionHistoryKey) ?? [];

  final sessions = storedList.map((item) {
    final map = jsonDecode(item) as Map<String, dynamic>;
    final normalizedMap = _normalizeLegacySessionMap(map);
    return SessionModel.fromMap(normalizedMap);
  }).toList();

  sessionHistoryNotifier.value = sessions;
}

Map<String, dynamic> _normalizeLegacySessionMap(Map<String, dynamic> map) {
  if (map['createdAt'] != null && (map['createdAt'] as String).isNotEmpty) {
    return map;
  }

  final legacyDate = map['date'] as String? ?? '';
  final parsedLegacyDate = _tryParseLegacyDate(legacyDate);

  return {
    ...map,
    'createdAt': (parsedLegacyDate ?? DateTime.now()).toIso8601String(),
  };
}

DateTime? _tryParseLegacyDate(String value) {
  final parts = value.trim().split(' ');
  if (parts.length != 2) return null;

  const monthMap = {
    'Jan': 1,
    'Feb': 2,
    'Mar': 3,
    'Apr': 4,
    'May': 5,
    'Jun': 6,
    'Jul': 7,
    'Aug': 8,
    'Sep': 9,
    'Oct': 10,
    'Nov': 11,
    'Dec': 12,
  };

  final month = monthMap[parts[0]];
  final day = int.tryParse(parts[1]);

  if (month == null || day == null) return null;

  final now = DateTime.now();
  return DateTime(now.year, month, day);
}

Future<void> _persistSessionHistory() async {
  final prefs = await SharedPreferences.getInstance();

  final encoded = sessionHistoryNotifier.value
      .map((session) => jsonEncode(session.toMap()))
      .toList();

  await prefs.setStringList(_sessionHistoryKey, encoded);
}

Future<void> addSessionToHistory(SessionModel session) async {
  sessionHistoryNotifier.value = [session, ...sessionHistoryNotifier.value];
  await _persistSessionHistory();
}

List<SessionModel> getSessionHistory() {
  return sessionHistoryNotifier.value;
}

Future<void> clearSessionHistory() async {
  sessionHistoryNotifier.value = [];
  await _persistSessionHistory();
}
