import 'package:flutter/material.dart';
import '../app/app_settings.dart';
import '../app/monitor_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final List<String> _ageGroups = ['Under 18', '18-40', '41-60', '61+'];

  bool _alertsEnabled = alertsEnabledNotifier.value;
  bool _weeklyReminder = true;
  bool _microphonePermission = true;
  bool _protectiveTips = protectiveTipsNotifier.value;
  double _alertThreshold = alertThresholdNotifier.value;

  String _selectedAgeGroup = ageGroupNotifier.value;
  bool _usesHearingAid = usesHearingAidNotifier.value;
  bool _autoThreshold = autoThresholdNotifier.value;

  double get _recommendedThreshold => getRecommendedThreshold(
    ageGroup: _selectedAgeGroup,
    usesHearingAid: _usesHearingAid,
  );

  String get _thresholdReason => getThresholdReason(
    ageGroup: _selectedAgeGroup,
    usesHearingAid: _usesHearingAid,
  );

  void _applyAutoThresholdIfNeeded() {
    if (!_autoThreshold) return;

    final recommended = _recommendedThreshold;

    setState(() {
      _alertThreshold = recommended;
    });

    alertThresholdNotifier.value = recommended;
  }

  void _resetDefaults() {
    setState(() {
      _alertsEnabled = true;
      _weeklyReminder = true;
      _microphonePermission = true;
      _protectiveTips = true;

      _selectedAgeGroup = '18-40';
      _usesHearingAid = false;
      _autoThreshold = true;
      _alertThreshold = 85.0;

      themeModeNotifier.value = ThemeMode.light;
      alertsEnabledNotifier.value = true;
      protectiveTipsNotifier.value = true;
      ageGroupNotifier.value = '18-40';
      usesHearingAidNotifier.value = false;
      autoThresholdNotifier.value = true;
      applyPersonalizedThreshold();
      _alertThreshold = alertThresholdNotifier.value;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings reset to default values')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = themeModeNotifier.value == ThemeMode.dark;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Manage alerts, reminders, hearing profile, theme, and monitoring preferences.',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 20),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hearing Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedAgeGroup,
                      decoration: const InputDecoration(
                        labelText: 'Age Group',
                        border: OutlineInputBorder(),
                      ),
                      items: _ageGroups.map((group) {
                        return DropdownMenuItem<String>(
                          value: group,
                          child: Text(group),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;

                        setState(() {
                          _selectedAgeGroup = value;
                          ageGroupNotifier.value = value;
                        });

                        _applyAutoThresholdIfNeeded();
                      },
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Uses Hearing Aid'),
                      subtitle: const Text(
                        'Used for personalized safety recommendations',
                      ),
                      value: _usesHearingAid,
                      onChanged: (value) {
                        setState(() {
                          _usesHearingAid = value;
                          usesHearingAidNotifier.value = value;
                        });

                        _applyAutoThresholdIfNeeded();
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Personalized Threshold',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Recommended threshold: ${_recommendedThreshold.toInt()} dB',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _thresholdReason,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Use Personalized Threshold Automatically',
                      ),
                      subtitle: const Text(
                        'Auto-update alerts from age and hearing profile',
                      ),
                      value: _autoThreshold,
                      onChanged: (value) {
                        setState(() {
                          _autoThreshold = value;
                          autoThresholdNotifier.value = value;
                        });

                        if (value) {
                          _applyAutoThresholdIfNeeded();
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final recommended = _recommendedThreshold;

                          setState(() {
                            _alertThreshold = recommended;
                          });

                          alertThresholdNotifier.value = recommended;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Applied recommended threshold: ${recommended.toInt()} dB',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('Apply Recommended Threshold'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monitoring Preferences',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable Noise Alerts'),
                      subtitle: const Text(
                        'Warn me when surrounding sound becomes unsafe',
                      ),
                      value: _alertsEnabled,
                      onChanged: (value) {
                        setState(() {
                          _alertsEnabled = value;
                          alertsEnabledNotifier.value = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Weekly Summary Reminder'),
                      subtitle: const Text(
                        'Show a reminder to review weekly exposure',
                      ),
                      value: _weeklyReminder,
                      onChanged: (value) {
                        setState(() {
                          _weeklyReminder = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Protective Safety Tips'),
                      subtitle: const Text(
                        'Display safety tips during risky exposure',
                      ),
                      value: _protectiveTips,
                      onChanged: (value) {
                        setState(() {
                          _protectiveTips = value;
                          protectiveTipsNotifier.value = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Microphone Permission'),
                      subtitle: const Text(
                        'Allow the app to use microphone monitoring',
                      ),
                      value: _microphonePermission,
                      onChanged: (value) {
                        setState(() {
                          _microphonePermission = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alert Threshold',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Current threshold: ${_alertThreshold.toInt()} dB',
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _autoThreshold
                          ? 'Automatic mode is ON. The threshold follows the hearing profile.'
                          : 'Automatic mode is OFF. You can set the threshold manually.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    Slider(
                      value: _alertThreshold,
                      min: 60,
                      max: 100,
                      divisions: 8,
                      label: '${_alertThreshold.toInt()} dB',
                      onChanged: _autoThreshold
                          ? null
                          : (value) {
                              setState(() {
                                _alertThreshold = value;
                                alertThresholdNotifier.value = value;
                              });
                            },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Appearance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Dark Mode'),
                      subtitle: const Text('Switch the whole app theme'),
                      value: isDarkMode,
                      onChanged: (value) {
                        themeModeNotifier.value = value
                            ? ThemeMode.dark
                            : ThemeMode.light;
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Preference Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryRow('Age Group', _selectedAgeGroup),
                    _buildSummaryRow(
                      'Hearing Aid',
                      _usesHearingAid ? 'Yes' : 'No',
                    ),
                    _buildSummaryRow(
                      'Auto Threshold',
                      _autoThreshold ? 'On' : 'Off',
                    ),
                    _buildSummaryRow(
                      'Recommended Threshold',
                      '${_recommendedThreshold.toInt()} dB',
                    ),
                    _buildSummaryRow('Alerts', _alertsEnabled ? 'On' : 'Off'),
                    _buildSummaryRow(
                      'Weekly Reminder',
                      _weeklyReminder ? 'On' : 'Off',
                    ),
                    _buildSummaryRow(
                      'Safety Tips',
                      _protectiveTips ? 'On' : 'Off',
                    ),
                    _buildSummaryRow(
                      'Microphone',
                      _microphonePermission ? 'Allowed' : 'Blocked',
                    ),
                    _buildSummaryRow('Theme', isDarkMode ? 'Dark' : 'Light'),
                    _buildSummaryRow(
                      'Current Threshold',
                      '${_alertThreshold.toInt()} dB',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _resetDefaults,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset to Defaults'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }
}
