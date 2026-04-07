import 'package:flutter/material.dart';
import 'app/app_settings.dart';
import 'data/session_store.dart';
import 'screens/main_navigation.dart';
import 'data/notification_store.dart';
import 'services/local_notification_service.dart';
import 'app/monitor_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeMonitorSettings();
  await initializeSessionHistory();

  final prefs = await SharedPreferences.getInstance();
  final hasCompletedOnboarding =
      prefs.getBool('has_completed_onboarding') ?? false;

  initializeNotifications();
  LocalNotificationService.initialize();

  runApp(SafeSoundApp(hasCompletedOnboarding: hasCompletedOnboarding));
}

class SafeSoundApp extends StatelessWidget {
  final bool hasCompletedOnboarding;

  const SafeSoundApp({super.key, required this.hasCompletedOnboarding});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'SafeSound',
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: themeMode,
          home: hasCompletedOnboarding
              ? const MainNavigation()
              : OnboardingScreen(),
        );
      },
    );
  }
}
