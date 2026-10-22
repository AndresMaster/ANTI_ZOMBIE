import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Paleta de colores y tema exclusivo Dark Mode ("Cero Deslumbramientos").
/// Diseñado específicamente para visualización en la madrugada sin blancos puros (#FFFFFF).
class AntizombiTheme {
  AntizombiTheme._();

  // Fondos de ultra bajo brillo (OLED / Carbono profundo)
  static const Color bgObsidian = Color(0xFF070709);
  static const Color bgSurface = Color(0xFF0F1016);
  static const Color bgCard = Color(0xFF151722);
  static const Color bgCardElevated = Color(0xFF1C1F2E);

  // Bordes sutiles
  static const Color borderSubtle = Color(0xFF25293A);
  static const Color borderAmberGlow = Color(0x66F59E0B);
  static const Color borderCrimsonGlow = Color(0x88EF4444);

  // Tipografía sin blanco puro (evita deslumbramiento retiniano)
  static const Color textPrimary = Color(0xFFE5E2DC); // Hueso suave / Gris cálido
  static const Color textSecondary = Color(0xFF9499AD); // Gris pizarra claro
  static const Color textMuted = Color(0xFF5D6275); // Gris atenuado

  // Acentos principales
  static const Color amberPrimary = Color(0xFFF59E0B); // Ámbar cálido nocturno
  static const Color amberDeep = Color(0xFFD97706);
  static const Color crimsonAlert = Color(0xFFEF4444); // Rojo alerta antizombi
  static const Color crimsonDark = Color(0xFF991B1B);
  static const Color emeraldSuccess = Color(0xFF10B981); // Verde despertar exitoso

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgObsidian,
      primaryColor: amberPrimary,
      colorScheme: const ColorScheme.dark(
        primary: amberPrimary,
        secondary: amberDeep,
        error: crimsonAlert,
        surface: bgSurface,
        onPrimary: bgObsidian,
        onSecondary: bgObsidian,
        onSurface: textPrimary,
        onError: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: bgObsidian,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: textPrimary,
          fontSize: 64,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.5,
        ),
        displayMedium: TextStyle(
          color: textPrimary,
          fontSize: 44,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 14,
          height: 1.45,
        ),
        labelLarge: TextStyle(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
