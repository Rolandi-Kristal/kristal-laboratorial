import 'package:flutter/material.dart';

class KristalLabTheme {
  static const Color militarAzulEscuro = Color(0xFF07111D);
  static const Color militarAzul = Color(0xFF102235);
  static const Color azulLaboratorial = Color(0xFF1F4E79);
  static const Color azulClaro = Color(0xFF4EA3FF);
  static const Color branco = Color(0xFFFFFFFF);

  static ThemeData get dark => darkTheme;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: militarAzulEscuro,
      primaryColor: azulLaboratorial,
      colorScheme: ColorScheme.fromSeed(
        seedColor: azulLaboratorial,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: militarAzul,
        foregroundColor: branco,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF0D1B2A),
        elevation: 3,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0B1A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: azulClaro,
          foregroundColor: branco,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
