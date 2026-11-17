import 'package:flutter/material.dart';

import '../ui/trainer_screen.dart';

/// Root widget of the Sweep Trainer.
///
/// Black/monospace visual direction mirrors the legacy React app
/// (`src/App.css`), with Material 3 dark theming on top.
class GuitarSweepApp extends StatelessWidget {
  const GuitarSweepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sweep Trainer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE5E7EB),
          onPrimary: Color(0xFF050505),
          secondary: Color(0xFF6B6B6B),
          surface: Color(0xFF090909),
          onSurface: Color(0xFFF3F4F6),
        ),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: const Color(0xFFF3F4F6),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Color(0xFFE5E7EB),
          inactiveTrackColor: Color(0xFF2A2A2A),
          thumbColor: Color(0xFFF3F4F6),
          overlayColor: Color(0x22FFFFFF),
          valueIndicatorColor: Color(0xFFFAFAFA),
          valueIndicatorTextStyle: TextStyle(
            color: Color(0xFF050505),

            fontSize: 12,
          ),
        ),
      ),
      home: const TrainerScreen(),
    );
  }
}
