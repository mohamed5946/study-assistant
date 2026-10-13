import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'core/l10n.dart';
import 'core/store.dart';
import 'core/notify.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DB.init();
  L.lang.value = Settings.lang;
  await Notify.init();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const StudyApp());
}
