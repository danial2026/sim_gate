import 'package:flutter/material.dart';

/// Centralized theme for the SimGate app.
///
/// Implements the "ultra-minimal, dark, sophisticated" aesthetic described in
/// `UI_DESIGN_GUIDE.md`: pure-black background, white accents, no shadows,
/// hierarchy through opacity, generous letter-spacing on uppercase labels,
/// and monospace fonts for technical data.
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Base palette
  // ---------------------------------------------------------------------------
  static const Color backgroundColor = Color(0xFF000000); // Pure black.
  static const Color surfaceColor = Color(0xFF0A0A0A); // Near-black surface.
  static const Color accentColor = Color(0xFFFFFFFF); // Primary accent.

  // Semantic colors ----------------------------------------------------------
  static const Color successColor = Color(0xFF00FF88); // Neon green.
  static const Color warningColor = Color(0xFFFFCC00); // Caution yellow.
  static const Color errorColor = Color(0xFFFF3366); // Pink-red destructive.

  // Text & elements ----------------------------------------------------------
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF666666);
  static const Color dividerColor = Color(0xFF1A1A1A);

  // Opacity helpers (per the design guide) -----------------------------------
  static Color surfaceTint() => const Color(0xFFFFFFFF).withValues(alpha: 0.05);
  static Color subtleBorder() =>
      const Color(0xFFFFFFFF).withValues(alpha: 0.10);
  static Color secondaryText() =>
      const Color(0xFFFFFFFF).withValues(alpha: 0.50);
  static Color hintIcon() => const Color(0xFFFFFFFF).withValues(alpha: 0.30);

  /// Monospace family used for IPs, tokens, and technical data.
  static const String monoFamily = 'RobotoMono';

  // ---------------------------------------------------------------------------
  // Dark theme (the only theme for this app)
  // ---------------------------------------------------------------------------
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.dark(
        primary: accentColor,
        onPrimary: backgroundColor,
        surface: surfaceColor,
        onSurface: textPrimary,
        error: errorColor,
      ),

      // Typography ----------------------------------------------------------
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
      ),

      // AppBar ---------------------------------------------------------------
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
        iconTheme: IconThemeData(color: textPrimary, size: 20),
      ),

      // Card theme (minimalist, no shadow) ----------------------------------
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: dividerColor, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Inputs --------------------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentColor, width: 1),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: Color(0xFF333333), fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),

      // Buttons -------------------------------------------------------------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: backgroundColor,
          elevation: 0,
          minimumSize: const Size.fromHeight(64),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: subtleBorder()),
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),

      // FAB ------------------------------------------------------------------
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: backgroundColor,
        elevation: 0,
        highlightElevation: 0,
        shape: CircleBorder(),
      ),

      // Dialogs -------------------------------------------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: dividerColor),
        ),
      ),

      // Switches (used for SIM toggles) ------------------------------------
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? accentColor
              : textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? successColor.withValues(alpha: 0.4)
              : dividerColor;
        }),
      ),

      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Utility used by status indicators to colorize latency values.
  static Color pingLatencyColor(int latencyMs) {
    if (latencyMs < 100) return successColor;
    if (latencyMs < 300) return warningColor;
    return errorColor;
  }
}
