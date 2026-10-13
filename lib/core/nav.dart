import 'package:flutter/material.dart';

/// Cross-tab navigation requests (dashboard quick actions -> other tabs).
class TabNav {
  static final ValueNotifier<int> tab = ValueNotifier(0);
  static final ValueNotifier<String?> studyTarget = ValueNotifier(null);
  static final ValueNotifier<String?> moreTarget = ValueNotifier(null);

  static void go(int i, {String? study, String? more}) {
    if (study != null) studyTarget.value = study;
    if (more != null) moreTarget.value = more;
    tab.value = i;
  }
}
