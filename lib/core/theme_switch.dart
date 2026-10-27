import 'package:flutter/material.dart';

import 'theme.dart';

/// v2.13: animated theme switching (Telegram-style circular reveal via
/// animated_theme_switcher).
///
/// Pure helpers so the selection → ThemeData mapping is unit-testable
/// without Hive. The animated widget wiring lives in app.dart (provider +
/// switching area), settings_screen.dart and dashboard_screen.dart (the
/// two toggle buttons that originate the reveal).

/// Effective brightness for a stored selection: 'light'/'dark' are absolute,
/// 'system' (and anything unexpected) follows the OS brightness.
Brightness effectiveBrightness(String selection, Brightness platform) {
  switch (selection) {
    case 'light':
      return Brightness.light;
    case 'dark':
      return Brightness.dark;
    default:
      return platform;
  }
}

/// The ThemeData to switch to for a selection, in the current language.
/// Palettes are untouched — this only picks the existing light/dark theme.
ThemeData themeForSelection(
    String selection, Brightness platform, String lang) {
  return buildTheme(effectiveBrightness(selection, platform), lang: lang);
}

/// The reveal direction: switching TO dark grows the circle out of the
/// button (isReversed: false); switching back TO light shrinks the
/// circle back into the button (isReversed: true), exactly like the
/// Telegram animation in the reference video.
bool isReversedForTarget(Brightness target) => target == Brightness.light;

/// Whether an animated switch should run at all: never while the
/// reduce-animations accessibility setting is on, and never when the
/// target brightness already equals the current one (nothing to reveal).
bool shouldAnimateTheme({
  required bool reduceAnim,
  required Brightness target,
  required Brightness current,
}) {
  return !reduceAnim && target != current;
}
