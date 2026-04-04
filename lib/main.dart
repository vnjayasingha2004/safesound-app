import 'package:flutter/material.dart';
import 'app/app_settings.dart';
import 'app/app_theme.dart';
import 'data/session_store.dart';
import 'screens/main_navigation.dart';
import 'data/notification_store.dart';
import 'services/local_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeSessionHistory();
  await initializeNotifications();
  await LocalNotificationService.initialize();
  runApp(const SafeSoundApp());
}

class SafeSoundApp extends StatelessWidget {
  const SafeSoundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, currentThemeMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'SafeSound',
          themeMode: currentThemeMode,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          home: const MainNavigation(),
        );
      },
    );
  }
}
