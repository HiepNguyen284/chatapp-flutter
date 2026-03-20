import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get light {
    const messengerBlue = Color(0xFF168AFF);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: messengerBlue,
        primary: messengerBlue,
        surface: const Color(0xFFF4F5F8),
      ),
      scaffoldBackgroundColor: const Color(0xFFF4F5F8),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF0F2F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: messengerBlue),
        ),
      ),
    );
  }
}
