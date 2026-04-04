import 'package:flutter/material.dart';
import 'app/app_settings.dart';
import 'screens/main_navigation.dart';

void main() {
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
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            scaffoldBackgroundColor: const Color(0xFFF5F7FB),
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
          ),
          home: const MainNavigation(),
        );
      },
    );
  }
}
