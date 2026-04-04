import 'package:flutter/material.dart';
import 'screens/main_navigation.dart';

void main() {
  runApp(const SafeSoundApp());
}

class SafeSoundApp extends StatelessWidget {
  const SafeSoundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SafeSound',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
      ),
      home: const MainNavigation(),
    );
  }
}
