import 'package:flutter/material.dart';
import '../app/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _alertsEnabled = true;
  bool _weeklyReminder = true;
  bool _microphonePermission = true;
  bool _protectiveTips = true;
  double _alertThreshold = 85;

  void _resetDefaults() {
    setState(() {
      _alertsEnabled = true;
      _weeklyReminder = true;
      _microphonePermission = true;
      _protectiveTips = true;
      _alertThreshold = 85;
      themeModeNotifier.value = ThemeMode.light;
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
              'Manage alerts, reminders, theme, and monitoring preferences.',
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
                    Slider(
                      value: _alertThreshold,
                      min: 60,
                      max: 100,
                      divisions: 8,
                      label: '${_alertThreshold.toInt()} dB',
                      onChanged: (value) {
                        setState(() {
                          _alertThreshold = value;
                        });
                      },
                    ),
                    Text(
                      'Lower values warn earlier, higher values allow more exposure before alerts appear.',
                      style: TextStyle(color: Colors.grey.shade700),
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
                      'Alert Threshold',
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
