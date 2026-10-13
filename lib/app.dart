import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/l10n.dart';
import 'core/theme.dart';
import 'core/store.dart';
import 'features/shell.dart';

class StudyApp extends StatelessWidget {
  const StudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: L.lang,
      builder: (_, code, __) {
        return ValueListenableBuilder(
          valueListenable: DB.kv.listenable(keys: ['theme']),
          builder: (_, ___, ____) {
            final mode = Settings.theme;
            final themeMode = mode == 'light'
                ? ThemeMode.light
                : mode == 'dark'
                    ? ThemeMode.dark
                    : ThemeMode.system;
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: t('appName'),
              theme: buildTheme(Brightness.light),
              darkTheme: buildTheme(Brightness.dark),
              themeMode: themeMode,
              locale: Locale(code),
              supportedLocales: const [Locale('ar'), Locale('en')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (ctx, child) => LangScope(child: child ?? const SizedBox()),
              home: const Shell(),
            );
          },
        );
      },
    );
  }
}
