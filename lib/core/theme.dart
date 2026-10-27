import 'dart:ui';

import 'package:flutter/material.dart';

import 'store.dart';

/// Liquid Glass design tokens for Study Assistant.
/// Masculine light theme: cool blue-gray background, confident blue primary,
// teal secondary. Light and airy, sporty — no pastel purple.
class AppColors {
  // Brand accents
  static const primary = Color(0xFF0284C7); // confident blue
  static const primaryDark = Color(0xFF0369A1); // deep blue
  static const secondary = Color(0xFF0D9488); // teal
  // Legacy names kept for gradient call-sites; recolored to blue family
  static const violet = Color(0xFF0369A1); // deep blue
  static const pink = Color(0xFF0EA5E9); // sky blue

  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFDC2626);

  // Light (default, masculine airy)
  static const lightBg = Color(0xFFEEF4FA);
  static const lightText = Color(0xFF0F172A);
  static const lightMuted = Color(0xFF64748B);
  // Dark slate variant
  static const darkBg = Color(0xFF0C1628);
  static const darkText = Color(0xFFF1F5F9);
  static const darkMuted = Color(0xFF94A3B8);

  // v2.9: blue/teal/green/amber/grey only — the old indigo 0xFF4F46E5
  // (a violet) was replaced with a pure blue so no violet, purple,
  // lavender or pink color exists anywhere in the palette.
  static const subjectPalette = <int>[
    0xFF0284C7, 0xFF0D9488, 0xFF0369A1, 0xFF0EA5E9, 0xFF475569, 0xFF16A34A,
    0xFFF59E0B, 0xFF0891B2, 0xFF2563EB, 0xFF64748B,
  ];
}

/// v2.9: [lang] selects the font — Cairo for Arabic (bundled), the
/// system sans for English (no Inter asset ships in this repo, so
/// bundling Inter would need a new font file; the Android default sans
/// is the closest available without a new dependency).
ThemeData buildTheme(Brightness b, {String lang = 'ar'}) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme(
    brightness: b,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.secondary,
    onSecondary: Colors.white,
    tertiary: AppColors.violet,
    error: AppColors.error,
    onError: Colors.white,
    surface: dark ? const Color(0xFF132033) : Colors.white,
    onSurface: dark ? AppColors.darkText : AppColors.lightText,
    surfaceContainerHighest: dark ? const Color(0xFF1A2C44) : const Color(0xFFE3EDF6),
    onSurfaceVariant: dark ? AppColors.darkMuted : AppColors.lightMuted,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    // Cairo carries Arabic; for English the platform sans is used so
    // Latin text does not render in an Arabic-first face.
    fontFamily: lang == 'en' ? null : 'Cairo',
    fontFamilyFallback: const ['Cairo'],
    scaffoldBackgroundColor: dark ? AppColors.darkBg : AppColors.lightBg,
    // Explicit fallbacks so nothing ever renders a light surface in dark
    // mode when a screen/widget falls back to a ThemeData default.
    cardColor: dark ? const Color(0xFF132033) : Colors.white,
    dialogTheme: DialogThemeData(
      backgroundColor:
          dark ? const Color(0xFF1A2C44) : Colors.white,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor:
          dark ? const Color(0xFF16273D) : Colors.white,
      modalBackgroundColor:
          dark ? const Color(0xFF16273D) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Cairo',
        fontWeight: FontWeight.w700,
        fontSize: 20,
        color: dark ? AppColors.darkText : AppColors.lightText,
      ),
      iconTheme: IconThemeData(color: dark ? AppColors.darkText : AppColors.lightText),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      shape: StadiumBorder(),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      // Inverse surface: dark snackbar on light theme, light on dark.
      backgroundColor:
          dark ? const Color(0xFFE8EEF5) : const Color(0xFF1E293B),
      contentTextStyle: TextStyle(
        color: dark ? const Color(0xFF0F172A) : Colors.white,
        fontFamily: 'Cairo',
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    // System pickers (showTimePicker/showDatePicker) in brand colors.
    timePickerTheme: TimePickerThemeData(
      backgroundColor: dark ? const Color(0xFF1A2C44) : Colors.white,
      hourMinuteColor: AppColors.primary.withValues(alpha: 0.12),
      hourMinuteTextColor:
          dark ? AppColors.darkText : AppColors.lightText,
      dialBackgroundColor: dark
          ? const Color(0xFF132033)
          : const Color(0xFFEAF3FF),
      dialHandColor: AppColors.primary,
      dialTextColor: dark ? AppColors.darkText : AppColors.lightText,
      entryModeIconColor: AppColors.primary,
      dayPeriodColor: AppColors.primary.withValues(alpha: 0.12),
      dayPeriodTextColor:
          dark ? AppColors.darkText : AppColors.lightText,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28)),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: dark ? const Color(0xFF1A2C44) : Colors.white,
      headerBackgroundColor: AppColors.primary,
      headerForegroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28)),
    ),
  );
}

/// Frosted-glass card container (v2.9 Liquid Glass).
///
/// True blur (sigma 22) behind a translucent tint, radius 24, thin white
/// border, soft shadow. When reduce-animations is on the blur is skipped
/// (plain translucent card) so the app stays fast on low-end phones.
/// Hero flight children must NOT use this card — see motion.dart.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final List<Color>? gradient;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.onTap,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = gradient != null
        ? null
        : (dark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.75));
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient != null
            ? LinearGradient(
                colors: gradient!,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.9),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.25 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
    if (!Settings.reduceAnim) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: content,
        ),
      );
    }
    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(radius),
      onTap: onTap,
      child: content,
    );
  }
}

/// Gradient primary button.
class GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;

  const GlassButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.secondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Secondary glass button: dark text on light glass, white on dark.
    final fg = secondary
        ? (dark ? Colors.white : AppColors.lightText)
        : Colors.white;
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            // v2.9: secondary is a plain glass button (no gradient) so
            // the primary blue gradient stays the single call to action.
            color: secondary
                ? (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.75))
                : null,
            border: secondary
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.85), width: 1)
                : null,
            gradient: secondary
                ? null
                : const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark]),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: fg, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aurora background blobs (GPU-cheap, static).
class AuroraBackground extends StatelessWidget {
  final Widget child;
  const AuroraBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned(
          top: -90,
          right: -70,
          child: _blob(dark ? AppColors.primary.withValues(alpha: 0.35) : AppColors.primary.withValues(alpha: 0.12), 260),
        ),
        Positioned(
          top: 120,
          left: -80,
          child: _blob(dark ? AppColors.violet.withValues(alpha: 0.30) : AppColors.violet.withValues(alpha: 0.10), 220),
        ),
        Positioned(
          bottom: -60,
          right: 40,
          child: _blob(dark ? AppColors.secondary.withValues(alpha: 0.22) : AppColors.secondary.withValues(alpha: 0.10), 200),
        ),
        child,
      ],
    );
  }

  Widget _blob(Color c, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)]),
        ),
      );
}
