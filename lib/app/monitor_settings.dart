import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<double> alertThresholdNotifier = ValueNotifier(85.0);
final ValueNotifier<bool> alertsEnabledNotifier = ValueNotifier(true);
final ValueNotifier<bool> protectiveTipsNotifier = ValueNotifier(true);

final ValueNotifier<String> ageGroupNotifier = ValueNotifier('18-40');
final ValueNotifier<bool> usesHearingAidNotifier = ValueNotifier(false);
final ValueNotifier<bool> autoThresholdNotifier = ValueNotifier(true);

const String _alertThresholdKey = 'alert_threshold';
const String _alertsEnabledKey = 'alerts_enabled';
const String _protectiveTipsKey = 'protective_tips';
const String _ageGroupKey = 'age_group';
const String _usesHearingAidKey = 'uses_hearing_aid';
const String _autoThresholdKey = 'auto_threshold';

bool _listenersAttached = false;

double getRecommendedThreshold({
  required String ageGroup,
  required bool usesHearingAid,
}) {
  double threshold = 85.0;

  switch (ageGroup) {
    case 'Under 18':
      threshold = 80.0;
      break;
    case '18-40':
      threshold = 85.0;
      break;
    case '41-60':
      threshold = 80.0;
      break;
    case '61+':
      threshold = 75.0;
      break;
    default:
      threshold = 85.0;
  }

  if (usesHearingAid) {
    threshold -= 5.0;
  }

  if (threshold < 65.0) return 65.0;
  if (threshold > 90.0) return 90.0;
  return threshold;
}

String getThresholdReason({
  required String ageGroup,
  required bool usesHearingAid,
}) {
  if (usesHearingAid && ageGroup == '61+') {
    return 'Lower threshold for older users with hearing aid support.';
  }

  if (usesHearingAid) {
    return 'Lower threshold because hearing aid users may need earlier warnings.';
  }

  switch (ageGroup) {
    case 'Under 18':
      return 'More protective threshold for younger users.';
    case '41-60':
      return 'Moderately protective threshold for mid-life users.';
    case '61+':
      return 'Safer threshold for older users with higher hearing risk.';
    default:
      return 'Standard adult threshold.';
  }
}

Future<void> initializeMonitorSettings() async {
  final prefs = await SharedPreferences.getInstance();

  alertsEnabledNotifier.value = prefs.getBool(_alertsEnabledKey) ?? true;
  protectiveTipsNotifier.value = prefs.getBool(_protectiveTipsKey) ?? true;
  ageGroupNotifier.value = prefs.getString(_ageGroupKey) ?? '18-40';
  usesHearingAidNotifier.value = prefs.getBool(_usesHearingAidKey) ?? false;
  autoThresholdNotifier.value = prefs.getBool(_autoThresholdKey) ?? true;

  if (autoThresholdNotifier.value) {
    alertThresholdNotifier.value = getRecommendedThreshold(
      ageGroup: ageGroupNotifier.value,
      usesHearingAid: usesHearingAidNotifier.value,
    );
  } else {
    alertThresholdNotifier.value = prefs.getDouble(_alertThresholdKey) ?? 85.0;
  }

  _attachAutoSaveListeners();
}

void _attachAutoSaveListeners() {
  if (_listenersAttached) return;
  _listenersAttached = true;

  alertThresholdNotifier.addListener(_saveMonitorSettings);
  alertsEnabledNotifier.addListener(_saveMonitorSettings);
  protectiveTipsNotifier.addListener(_saveMonitorSettings);
  ageGroupNotifier.addListener(_saveMonitorSettings);
  usesHearingAidNotifier.addListener(_saveMonitorSettings);
  autoThresholdNotifier.addListener(_saveMonitorSettings);
}

Future<void> _saveMonitorSettings() async {
  final prefs = await SharedPreferences.getInstance();

  await prefs.setDouble(_alertThresholdKey, alertThresholdNotifier.value);
  await prefs.setBool(_alertsEnabledKey, alertsEnabledNotifier.value);
  await prefs.setBool(_protectiveTipsKey, protectiveTipsNotifier.value);
  await prefs.setString(_ageGroupKey, ageGroupNotifier.value);
  await prefs.setBool(_usesHearingAidKey, usesHearingAidNotifier.value);
  await prefs.setBool(_autoThresholdKey, autoThresholdNotifier.value);
}

void applyPersonalizedThreshold() {
  alertThresholdNotifier.value = getRecommendedThreshold(
    ageGroup: ageGroupNotifier.value,
    usesHearingAid: usesHearingAidNotifier.value,
  );
}
