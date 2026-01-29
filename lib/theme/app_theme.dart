import 'package:flutter/material.dart';

/// Clase de tema para la aplicación
class AppTheme {
  // Colores principales
  // Nueva paleta moderna y armónica
  static const Color primary = Color(0xFF4F8FC0); // Azul suave
  static const Color primaryDark = Color(0xFF395B7F);
  static const Color primaryLight = Color(0xFFD6E6F6);

  static const Color secondary = Color(0xFF6FCF97); // Verde menta
  static const Color secondaryDark = Color(0xFF3B7A57);
  static const Color secondaryLight = Color(0xFFE0F8EC);

  static const Color accent = Color(0xFFF2C94C); // Amarillo pastel
  static const Color accentDark = Color(0xFFC9A13B);
  static const Color accentLight = Color(0xFFFFF6D6);

  static const Color error = Color(0xFFE57373); // Rojo suave
  static const Color background = Color(0xFFF8FAFB);
  static const Color cardBackground = Colors.white;

  // Colores adicionales (alias para compatibilidad)
  static const Color turquoise = Color(0xFF4F8FC0); // Azul turquesa
  static const Color turquoiseDark = Color(0xFF395B7F); // Azul turquesa oscuro
  static const Color turquoiseLight = Color(0xFFD6E6F6); // Azul turquesa claro
  static const Color coral = Color(0xFFE57373); // Coral/Rojo suave
  static const Color coralLight = Color(0xFFFFCDD2); // Coral claro

  // Fuentes
  static const String fontHemiheads = 'Hemiheads';
  static const String fontDefault = 'Roboto';

  // Estilos de texto
  static TextStyle get titleLarge => TextStyle(
    fontFamily: fontHemiheads,
    fontSize: 26,
    fontWeight: FontWeight.bold,
    color: primaryDark,
  );

  static TextStyle get titleMedium => TextStyle(
    fontFamily: fontHemiheads,
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: primaryDark,
  );

  static TextStyle get subtitleLarge => TextStyle(
    fontFamily: fontDefault,
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: primaryDark,
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
    color: secondaryDark,
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
        primaryLight.withOpacity(0.3),
        Colors.white,
      ],
    ),
  );

  // Tema completo de la aplicación
  static ThemeData get lightTheme => ThemeData(
    primaryColor: primary,
    colorScheme: ColorScheme.light(
      primary: primary,
      secondary: secondary,
      surface: background,
      error: error,
    ),
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: primary,
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
        backgroundColor: primary,
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
        foregroundColor: primaryDark,
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