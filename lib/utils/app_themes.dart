import 'package:flutter/material.dart';

class AppThemes {
  static const Color primaryGreen = Color(0xFF2ECC71);
  static const Color lightGreen = Color(0xFF27AE60);
  static const Color darkGreen = Color(0xFF1E8449);
  static const Color pendingColor = Color(0xFFF39C12);
  static const Color scheduledColor = Color(0xFF3498DB);
  static const Color collectedColor = Color(0xFF2ECC71);
  static const Color missedColor = Color(0xFFE74C3C);
  static const Color approvedColor = Color(0xFF27AE60);
  static const Color rejectedColor = Color(0xFFE74C3C);

  static final ThemeData light = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGreen,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
  );

  static final ThemeData dark = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGreen,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF1E1E1E),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
  );
}