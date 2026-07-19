import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'providers/heart_rate_provider.dart';

void main() {
  runApp(const VitalLensApp());
}

class VitalLensApp extends StatelessWidget {
  const VitalLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HeartRateProvider()..init(),
      child: MaterialApp(
        title: 'VitalLens',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const HomeScreen(),
        routes: {
          '/settings': (context) => const SettingsScreen(),
        },
      ),
    );
  }
}
