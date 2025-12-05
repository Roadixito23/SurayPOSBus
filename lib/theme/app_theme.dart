import 'package:flutter/material.dart';

/// Clase de tema para la aplicación
class AppTheme {
  // Colores principales
  static const Color turquoise = Color(0xFF40E0D0);
  static const Color turquoiseDark = Color(0xFF20B2AA);
  static const Color turquoiseLight = Color(0xFFAFEEEE);

  static const Color coral = Color(0xFFFF7F50);
  static const Color coralDark = Color(0xFFFF6347);
  static const Color coralLight = Color(0xFFFFA07A);

  static const Color background = Color(0xFFF5F5F5);
  static const Color cardBackground = Colors.white;

  // Fuentes
  static const String fontHemiheads = 'Hemiheads';
  static const String fontDefault = 'Roboto';

  // Estilos de texto
  static TextStyle get titleLarge => TextStyle(
    fontFamily: fontHemiheads,
    fontSize: 26,
    fontWeight: FontWeight.bold,
    color: turquoiseDark,
  );

  static TextStyle get titleMedium => TextStyle(
    fontFamily: fontHemiheads,
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: turquoiseDark,
  );

  static TextStyle get subtitleLarge => TextStyle(
    fontFamily: fontDefault,
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: turquoiseDark,
  );

  static TextStyle get bodyLarge => TextStyle(
    fontFamily: fontDefault,
    fontSize: 16,
    color: Colors.black87,
  );

  static TextStyle get bodyMedium => TextStyle(
    fontFamily: fontDefault,
    fontSize: 14,
    color: Colors.black87,
  );

  static TextStyle get emphasis => TextStyle(
    fontFamily: fontDefault,
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: coral,
  );

  // Decoraciones
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: cardBackground,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
        offset: Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration get gradientBackground => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        turquoiseLight.withOpacity(0.3),
        Colors.white,
      ],
    ),
  );

  // Tema completo de la aplicación
  static ThemeData get lightTheme => ThemeData(
    primaryColor: turquoise,
    colorScheme: ColorScheme.light(
      primary: turquoise,
      secondary: coral,
      surface: background,
    ),
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: turquoise,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: fontHemiheads,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: turquoise,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: turquoiseDark,
      ),
    ),
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
    ),
    fontFamily: fontDefault,
  );

  // Duración para animaciones
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);
}