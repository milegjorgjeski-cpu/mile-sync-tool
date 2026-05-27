import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// Mile Sync Tool – Dark Industrial Theme
// ─────────────────────────────────────────────────────────────

class MileColors {
  // Background layers
  static const Color bg0 = Color(0xFF0A0B0D); // deepest
  static const Color bg1 = Color(0xFF111318); // surface
  static const Color bg2 = Color(0xFF1A1D24); // card
  static const Color bg3 = Color(0xFF232730); // elevated card

  // Accent – warm amber for Balkan energy
  static const Color accent = Color(0xFFE8A23A);
  static const Color accentDim = Color(0xFF9B6A1F);
  static const Color accentGlow = Color(0xFFFFCC66);

  // Status colors
  static const Color success = Color(0xFF4CAF82);
  static const Color warning = Color(0xFFE8A23A);
  static const Color error = Color(0xFFE05555);
  static const Color info = Color(0xFF4A9EE0);

  // Text
  static const Color textPrimary = Color(0xFFF0EDE8);
  static const Color textSecondary = Color(0xFF9A96A0);
  static const Color textDim = Color(0xFF5A5760);

  // Waveform
  static const Color waveformActive = Color(0xFFE8A23A);
  static const Color waveformInactive = Color(0xFF3A3D45);
  static const Color waveformPlayhead = Color(0xFFFFCC66);

  // Step indicators
  static const Color stepDone = Color(0xFF4CAF82);
  static const Color stepActive = Color(0xFFE8A23A);
  static const Color stepPending = Color(0xFF3A3D45);
}

class MileTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        surface: MileColors.bg1,
        primary: MileColors.accent,
        secondary: MileColors.accentDim,
        error: MileColors.error,
        onSurface: MileColors.textPrimary,
        onPrimary: MileColors.bg0,
      ),
      scaffoldBackgroundColor: MileColors.bg0,
      appBarTheme: const AppBarTheme(
        backgroundColor: MileColors.bg1,
        foregroundColor: MileColors.textPrimary,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'monospace',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.0,
          color: MileColors.accent,
        ),
      ),
      cardTheme: CardTheme(
        color: MileColors.bg2,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF2A2D35), width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MileColors.accent,
          foregroundColor: MileColors.bg0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 1.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MileColors.accent,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: MileColors.accentDim, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 1.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MileColors.accent,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A2D35),
        thickness: 1,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: MileColors.accent,
        inactiveTrackColor: MileColors.bg3,
        thumbColor: MileColors.accentGlow,
        overlayColor: MileColors.accent.withOpacity(0.2),
        trackHeight: 4,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? MileColors.accent
              : MileColors.textDim,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? MileColors.accentDim
              : MileColors.bg3,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MileColors.bg2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF2A2D35)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF2A2D35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: MileColors.accent, width: 1.5),
        ),
        labelStyle: const TextStyle(color: MileColors.textSecondary),
        hintStyle: const TextStyle(color: MileColors.textDim),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: MileColors.textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: MileColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: MileColors.textPrimary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        titleMedium: TextStyle(
          color: MileColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(color: MileColors.textPrimary),
        bodyMedium: TextStyle(color: MileColors.textSecondary),
        bodySmall: TextStyle(color: MileColors.textDim, fontSize: 11),
        labelLarge: TextStyle(
          color: MileColors.textPrimary,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
      iconTheme: const IconThemeData(color: MileColors.textSecondary, size: 22),
    );
  }
}
