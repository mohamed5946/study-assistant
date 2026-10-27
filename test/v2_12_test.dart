import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant/core/external_link.dart';
import 'package:study_assistant/core/sensitive_query.dart';
import 'package:study_assistant/core/theme.dart';

void main() {
  group('v2.12: broadened sensitive-query gate', () {
    test('blocks "make a program like this" phrasings (the reported case)',
        () {
      expect(isSensitiveAppQuery('طيب عايز اعمل برنامج زي ده'), isTrue);
      expect(isSensitiveAppQuery('اعمل برنامج زي ده'), isTrue);
      expect(isSensitiveAppQuery('برنامج زي هذا'), isTrue);
      expect(isSensitiveAppQuery('make an app like this'), isTrue);
      expect(isSensitiveAppQuery('clone this app'), isTrue);
    });

    test('blocks app-details / how-it-was-built questions', () {
      expect(isSensitiveAppQuery('تفاصيل البرنامج ايه؟'), isTrue);
      expect(isSensitiveAppQuery('معلومات عن التطبيق'), isTrue);
      expect(isSensitiveAppQuery('ازاي البرنامج اتعمل'), isTrue);
      expect(isSensitiveAppQuery('how was this app built?'), isTrue);
      expect(isSensitiveAppQuery('details about this app'), isTrue);
      expect(isSensitiveAppQuery('نسخة من البرنامج'), isTrue);
    });

    test('blocks code/source only when combined with an app word', () {
      expect(isSensitiveAppQuery('كود البرنامج'), isTrue);
      expect(isSensitiveAppQuery('كود التطبيق فين'), isTrue);
      expect(isSensitiveAppQuery('سورس البرنامج'), isTrue);
      expect(isSensitiveAppQuery('source of this app'), isTrue);
    });

    test('keeps every legacy pattern blocked', () {
      expect(isSensitiveAppQuery('source code'), isTrue);
      expect(isSensitiveAppQuery('سورس كود'), isTrue);
      expect(isSensitiveAppQuery('كود المصدر'), isTrue);
      expect(isSensitiveAppQuery('api key'), isTrue);
      expect(isSensitiveAppQuery('reverse engineer'), isTrue);
      expect(isSensitiveAppQuery('groq key'), isTrue);
    });

    test('legitimate code-help questions still pass through', () {
      expect(isSensitiveAppQuery('اشرح الكود ده'), isFalse);
      expect(isSensitiveAppQuery('explain this code'), isFalse);
      expect(isSensitiveAppQuery('كود بايثون يطبع الأرقام'), isFalse);
      expect(isSensitiveAppQuery('لخص الموضوع ده'), isFalse);
      expect(isSensitiveAppQuery('اديني أسئلة تدريب'), isFalse);
    });
  });

  group('v2.12: suggested prompts visibility', () {
    test('visible only while input is empty', () {
      expect(promptsVisibleForInput(''), isTrue);
      expect(promptsVisibleForInput('   '), isTrue);
      expect(promptsVisibleForInput('س'), isFalse);
      expect(promptsVisibleForInput('  سؤال'), isFalse);
    });

    test('chat screen gates both prompts call sites on input emptiness',
        () {
      final src = File('lib/features/ai_chat_screen.dart')
          .readAsStringSync();
      expect(src.contains('if (msgs.isNotEmpty && _inputEmpty) _promptsSection()'),
          isTrue);
      expect(src.contains('if (_inputEmpty) _promptsSection()'), isTrue);
      expect(src.contains('_input.addListener(_onInputChanged)'), isTrue);
      expect(
          src.contains('_input.removeListener(_onInputChanged)'), isTrue);
    });
  });

  group('v2.12: input directly above the bar', () {
    test('tabbed bottom padding is 12, not 84', () {
      final src = File('lib/features/ai_chat_screen.dart')
          .readAsStringSync();
      expect(
          src.contains('Navigator.canPop(context) ? 16 : 12'), isTrue);
      expect(src.contains('? 16 : 84'), isFalse);
    });
  });

  group('v2.12: portfolio link', () {
    test('portfolio URL constant', () {
      expect(portfolioUrl, 'https://mohamed5946.github.io/portfolio/');
    });

    test('link is wired into the developer popup and settings contact',
        () {
      final chat = File('lib/features/ai_chat_screen.dart')
          .readAsStringSync();
      final settings =
          File('lib/features/settings_screen.dart').readAsStringSync();
      expect(chat.contains('openPortfolioLink(context)'), isTrue);
      expect(chat.contains('portfolioUrl'), isTrue);
      expect(settings.contains('openPortfolioLink(context)'), isTrue);
      expect(settings.contains('portfolioUrl'), isTrue);
    });
  });

  group('v2.12: mockup background', () {
    test('AuroraBackground body has no violet reference', () {
      final src = File('lib/core/theme.dart').readAsStringSync();
      final start = src.indexOf('class AuroraBackground');
      expect(start, isNot(-1));
      final end = src.indexOf('\n}\n', start);
      expect(end, isNot(-1));
      final body = src.substring(start, end).toLowerCase();
      expect(body.contains('violet'), isFalse);
    });

    testWidgets('AuroraBackground renders on a narrow phone without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuroraBackground(
              child: const Center(child: Text('hello')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('hello'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
