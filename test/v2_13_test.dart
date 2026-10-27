import 'dart:io';

import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant/core/theme.dart';
import 'package:study_assistant/core/theme_switch.dart';

void main() {
  group('v2.13: selection → ThemeData mapping', () {
    test('light/dark selections are absolute', () {
      expect(effectiveBrightness('light', Brightness.dark),
          Brightness.light);
      expect(
          effectiveBrightness('dark', Brightness.light), Brightness.dark);
    });

    test('system follows the OS brightness', () {
      expect(effectiveBrightness('system', Brightness.dark),
          Brightness.dark);
      expect(effectiveBrightness('system', Brightness.light),
          Brightness.light);
    });

    test('themeForSelection returns the existing palettes, unchanged', () {
      final light = themeForSelection('light', Brightness.dark, 'ar');
      final dark = themeForSelection('dark', Brightness.light, 'ar');
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      // Same palettes as buildTheme: light bg pale blue, dark bg slate.
      expect(light.scaffoldBackgroundColor, AppColors.lightBg);
      expect(dark.scaffoldBackgroundColor, AppColors.darkBg);
      // System resolves through the platform value.
      expect(themeForSelection('system', Brightness.dark, 'en').brightness,
          Brightness.dark);
    });
  });

  group('v2.13: reveal direction', () {
    test('isReversed is true exactly when the target is light', () {
      expect(isReversedForTarget(Brightness.light), isTrue);
      expect(isReversedForTarget(Brightness.dark), isFalse);
    });
  });

  group('v2.13: when animation runs', () {
    test('reduceAnim skips the animation', () {
      expect(
          shouldAnimateTheme(
              reduceAnim: true,
              target: Brightness.dark,
              current: Brightness.light),
          isFalse);
    });

    test('no animation when target already equals current', () {
      expect(
          shouldAnimateTheme(
              reduceAnim: false,
              target: Brightness.dark,
              current: Brightness.dark),
          isFalse);
    });

    test('animation runs for a real light↔dark switch', () {
      expect(
          shouldAnimateTheme(
              reduceAnim: false,
              target: Brightness.dark,
              current: Brightness.light),
          isTrue);
      expect(
          shouldAnimateTheme(
              reduceAnim: false,
              target: Brightness.light,
              current: Brightness.dark),
          isTrue);
    });
  });

  group('v2.13: wiring (source scans)', () {
    test('app.dart: provider owns the theme, area wraps Shell', () {
      final app =
          File('lib/app.dart').readAsStringSync();
      expect(app.contains('ThemeProvider('), isTrue);
      expect(app.contains('ThemeSwitchingArea(child: const Shell())'),
          isTrue);
      // No themeMode fighting the provider.
      expect(app.contains('themeMode:'), isFalse);
      expect(app.contains('darkTheme:'), isFalse);
    });

    test('settings: switcher wraps the segmented control, persists on finish',
        () {
      final s =
          File('lib/features/settings_screen.dart').readAsStringSync();
      expect(s.contains('ThemeSwitcher('), isTrue);
      expect(s.contains('ThemeSwitcher.of(context).changeTheme('), isTrue);
      expect(s.contains('onAnimationFinish'), isTrue);
      expect(s.contains('isReversedForTarget'), isTrue);
    });

    test('dashboard toggle: switcher wraps the button, persists on finish',
        () {
      final d =
          File('lib/features/dashboard_screen.dart').readAsStringSync();
      expect(d.contains('ThemeSwitcher('), isTrue);
      expect(d.contains('ThemeSwitcher.of(context).changeTheme('), isTrue);
      expect(d.contains('onAnimationFinish'), isTrue);
    });

    test('no theme write bypasses the animated path', () {
      // Every Settings.theme assignment lives in the two animated
      // toggle handlers (settings segmented control, dashboard button).
      for (final path in [
        'lib/features/settings_screen.dart',
        'lib/features/dashboard_screen.dart',
      ]) {
        final src = File(path).readAsStringSync();
        final writes = RegExp(r'Settings\.theme\s*=[^=]')
            .allMatches(src)
            .length;
        expect(writes, greaterThan(0));
      }
      final appWrites =
          RegExp(r'Settings\.theme\s*=[^=]').allMatches(
              File('lib/app.dart').readAsStringSync());
      expect(appWrites.length, 0);
    });
  });

  group('v2.13: package reveal end-to-end (minimal tree)', () {
    testWidgets('tap on a switcher flips the effective brightness',
        (tester) async {
      await tester.pumpWidget(
        ThemeProvider(
          initTheme: buildTheme(Brightness.light, lang: 'en'),
          builder: (context, myTheme) => MaterialApp(
            theme: myTheme,
            home: ThemeSwitchingArea(
              child: Builder(
                builder: (context) => ThemeSwitcher(
                  builder: (context) => TextButton(
                    onPressed: () {
                      ThemeSwitcher.of(context).changeTheme(
                        theme: buildTheme(Brightness.dark, lang: 'en'),
                        isReversed: false,
                      );
                    },
                    child: const Text('toggle'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(Theme.of(tester.element(find.text('toggle'))).brightness,
          Brightness.light);
      await tester.tap(find.text('toggle'));
      await tester.pumpAndSettle();
      expect(Theme.of(tester.element(find.text('toggle'))).brightness,
          Brightness.dark);
    });
  });
}
