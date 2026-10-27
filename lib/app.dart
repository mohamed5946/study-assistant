import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/l10n.dart';
import 'core/theme_switch.dart';
import 'core/store.dart';
import 'features/shell.dart';

/// v2.13: theme is owned by animated_theme_switcher's ThemeProvider so
/// switching themes plays the Telegram-style circular reveal that starts
/// at the toggle button (see theme_switch.dart). The provider is the
/// single source of truth while running — MaterialApp has no themeMode
/// fighting it. The persisted Settings.theme is still the cold-start
/// source: initTheme resolves it (system → current OS brightness).
class StudyApp extends StatefulWidget {
  const StudyApp({super.key});

  @override
  State<StudyApp> createState() => _StudyAppState();
}

class _StudyAppState extends State<StudyApp> with WidgetsBindingObserver {
  /// Last OS brightness observed while running. Null until the OS
  /// brightness actually changes mid-session. It is part of the provider
  /// key ONLY so a mid-session OS change remounts the provider with the
  /// new system theme (instant, no animation). Manual theme selections
  /// never touch it, so their reveal animation is never remounted away
  /// (persistence happens in onAnimationFinish, after the reveal).
  Brightness? _observedSystemBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    // Only the 'system' choice follows the OS; light/dark stay put.
    if (Settings.theme == 'system') {
      setState(() {
        _observedSystemBrightness = WidgetsBinding
            .instance.platformDispatcher.platformBrightness;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: L.lang,
      builder: (_, code, __) {
        return ValueListenableBuilder(
          valueListenable: DB.kv.listenable(keys: ['theme', 'reduceAnim']),
          builder: (_, ___, ____) {
            // Keyed by language (so a language change remounts the
            // provider with the right font, since it only reads
            // initTheme once) plus a mid-session OS-brightness change.
            // A persisted theme change does NOT change the key, so an
            // in-flight reveal is never interrupted by a remount.
            final providerKey = ValueKey(
                'theme-$code-${_observedSystemBrightness?.name ?? 'stable'}');
            return ThemeProvider(
              key: providerKey,
              initTheme: themeForSelection(
                  Settings.theme,
                  WidgetsBinding.instance.platformDispatcher.platformBrightness,
                  code),
              builder: (context, myTheme) {
                return MaterialApp(
                  debugShowCheckedModeBanner: false,
                  title: t('appName'),
                  theme: myTheme,
                  locale: Locale(code),
                  supportedLocales: const [Locale('ar'), Locale('en')],
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  builder: (ctx, child) {
                    // Status-bar icons follow the effective theme so they stay
                    // visible in both light and dark mode.
                    final dark =
                        Theme.of(ctx).brightness == Brightness.dark;
                    SystemChrome.setSystemUIOverlayStyle(
                      SystemUiOverlayStyle(
                        statusBarColor: Colors.transparent,
                        statusBarIconBrightness:
                            dark ? Brightness.light : Brightness.dark,
                        statusBarBrightness:
                            dark ? Brightness.dark : Brightness.light,
                      ),
                    );
                    return LangScope(child: child ?? const SizedBox());
                  },
                  // The reveal covers the whole screen including the
                  // bottom nav, since the area wraps the entire Shell.
                  home: ThemeSwitchingArea(child: const Shell()),
                );
              },
            );
          },
        );
      },
    );
  }
}
