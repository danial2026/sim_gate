import 'package:flutter/material.dart';

/// Mode-dependent palette resolved through [Theme.of] extensions.
///
/// Widgets must use [AppTheme.of] instead of hardcoded colors so the app can
/// switch between dark and light modes.
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.hint,
    required this.subtleBorder,
  });

  final Color background;
  final Color surface;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Color hint;
  final Color subtleBorder;

  /// Pure-black, near-black surfaces, white accents.
  static const AppPalette dark = AppPalette(
    background: Color(0xFF000000),
    surface: Color(0xFF0A0A0A),
    accent: Color(0xFFFFFFFF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF666666),
    divider: Color(0xFF1A1A1A),
    hint: Color(0xFF333333),
    subtleBorder: Color(0x1AFFFFFF),
  );

  /// White background, near-white surfaces, black accents.
  static const AppPalette light = AppPalette(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFF6F6F6),
    accent: Color(0xFF000000),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF666666),
    divider: Color(0xFFE4E4E4),
    hint: Color(0xFF9E9E9E),
    subtleBorder: Color(0x1F000000),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? accent,
    Color? textPrimary,
    Color? textSecondary,
    Color? divider,
    Color? hint,
    Color? subtleBorder,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      accent: accent ?? this.accent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      divider: divider ?? this.divider,
      hint: hint ?? this.hint,
      subtleBorder: subtleBorder ?? this.subtleBorder,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      hint: Color.lerp(hint, other.hint, t)!,
      subtleBorder: Color.lerp(subtleBorder, other.subtleBorder, t)!,
    );
  }
}

/// Centralized theme for the SimGate app.
///
/// Implements the "ultra-minimal, dark, sophisticated" aesthetic described in
/// `UI_DESIGN_GUIDE.md`: pure-black background, white accents, no shadows,
/// hierarchy through opacity, generous letter-spacing on uppercase labels,
/// and monospace fonts for technical data. A light counterpart is provided
/// and selected via the settings page.
class AppTheme {
  AppTheme._();

  // Semantic colors (identical in both modes) -------------------------------
  static const Color successColor = Color(0xFF00FF88); // Neon green.
  static const Color warningColor = Color(0xFFFFCC00); // Caution yellow.
  static const Color errorColor = Color(0xFFFF3366); // Pink-red destructive.

  /// Monospace family used for IPs, tokens, and technical data.
  ///
  /// Uses the platform's generic monospace family instead of a bundled font
  /// (bundling would add assets and require pubspec font config).
  static const String monoFamily = 'monospace';

  /// Resolves the active palette from the ambient [BuildContext].
  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? AppPalette.dark;

  static ThemeData get darkTheme => _build(AppPalette.dark, Brightness.dark);

  static ThemeData get lightTheme => _build(AppPalette.light, Brightness.light);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: p.background,
      colorScheme:
          (brightness == Brightness.dark
                  ? const ColorScheme.dark()
                  : const ColorScheme.light())
              .copyWith(
                primary: p.accent,
                onPrimary: p.background,
                surface: p.surface,
                onSurface: p.textPrimary,
                error: errorColor,
                onError: const Color(0xFFFFFFFF),
              ),
      extensions: [p],

      // Typography ----------------------------------------------------------
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          color: p.textPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          color: p.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: p.textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: p.textSecondary, fontSize: 14),
      ),

      // AppBar ---------------------------------------------------------------
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: p.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
        iconTheme: IconThemeData(color: p.textPrimary, size: 20),
      ),

      // Card theme (minimalist, no shadow) ----------------------------------
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: p.divider, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Inputs --------------------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.accent, width: 1),
        ),
        labelStyle: TextStyle(color: p.textSecondary, fontSize: 14),
        hintStyle: TextStyle(color: p.hint, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),

      // Buttons -------------------------------------------------------------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.background,
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
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.subtleBorder),
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
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accent,
        foregroundColor: p.background,
        elevation: 0,
        highlightElevation: 0,
        shape: const CircleBorder(),
      ),

      // Dialogs -------------------------------------------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.divider),
        ),
      ),

      // Switches (used for SIM toggles) ------------------------------------
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? p.accent
              : p.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? successColor.withValues(alpha: 0.4)
              : p.divider;
        }),
      ),

      dividerTheme: DividerThemeData(color: p.divider, thickness: 1, space: 1),
    );
  }

  /// Utility used by status indicators to colorize latency values.
  static Color pingLatencyColor(int latencyMs) {
    if (latencyMs < 100) return successColor;
    if (latencyMs < 300) return warningColor;
    return errorColor;
  }
}
