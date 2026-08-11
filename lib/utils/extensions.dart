import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Reusable [TextStyle] shortcuts that conform to the design guide.
class AppTextStyles {
  AppTextStyles._();

  /// App/section title: 20/900, uppercase, wide letter spacing.
  static const TextStyle appTitle = TextStyle(
    color: AppTheme.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w900,
    letterSpacing: 2.0,
  );

  /// Uppercase status label: 10/600.
  static const TextStyle statusLabel = TextStyle(
    color: AppTheme.textSecondary,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
  );

  /// Section header: 12/900 uppercase.
  static const TextStyle sectionHeader = TextStyle(
    color: AppTheme.textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.w900,
    letterSpacing: 2.0,
  );

  /// Monospace style for IPs, tokens, technical data.
  static const TextStyle mono = TextStyle(
    color: AppTheme.textPrimary,
    fontFamily: AppTheme.monoFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  static const TextStyle bodyStrong = TextStyle(
    color: AppTheme.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodySecondary = TextStyle(
    color: AppTheme.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );
}

/// Extension helpers on [BuildContext] for quick theme access.
extension ContextTheme on BuildContext {
  AppTheme get appTheme => AppTheme;
  TextTheme get tt => Theme.of(this).textTheme;
}
