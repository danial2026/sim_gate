import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// Minimalist top app bar with uppercase title styling.
class SimGateAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SimGateAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showBack = false,
  });

  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.of(context).background,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: showBack,
      title: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
          color: AppTheme.of(context).textPrimary,
        ),
      ),
      actions: actions,
      leading: leading,
    );
  }
}

/// Standard full-width CTA button (white bg, black text) per the design guide.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: destructive
              ? AppTheme.errorColor
              : AppTheme.of(context).accent,
          foregroundColor: AppTheme.of(context).background,
          disabledBackgroundColor: AppTheme.of(
            context,
          ).accent.withValues(alpha: 0.05),
          disabledForegroundColor: AppTheme.of(
            context,
          ).accent.withValues(alpha: 0.30),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.of(context).background,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(label.toUpperCase()),
                ],
              ),
      ),
    );
  }
}

/// Outlined secondary button per the design guide.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.of(context).textPrimary,
          side: BorderSide(color: AppTheme.of(context).subtleBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Text(label.toUpperCase()),
          ],
        ),
      ),
    );
  }
}

/// Status badge with a colored dot + uppercase label.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Standard section header label.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: AppTheme.of(context).textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
        ),
      ),
    );
  }
}

/// Standard screen scaffold with the dark background + consistent padding.
class SimGateScaffold extends StatelessWidget {
  const SimGateScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.fab,
    this.showBack = true,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? fab;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.of(context).background,
      appBar: SimGateAppBar(title: title, actions: actions, showBack: showBack),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: body,
        ),
      ),
      floatingActionButton: fab,
    );
  }
}

/// Small inline loading indicator.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color ?? AppTheme.of(context).accent,
      ),
    );
  }
}
