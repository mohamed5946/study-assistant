import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'l10n.dart';
import 'theme.dart';
import 'widgets.dart';

/// Renders text with fenced ```code blocks``` as dark syntax-highlighted
/// cards (with a copy button). Used for AI replies (CS-tailored chat).
class CodeAwareText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final bool selectable;
  const CodeAwareText(
      {super.key, required this.text, this.style, this.selectable = true});

  @override
  Widget build(BuildContext context) {
    final segments = _split(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final seg in segments)
          seg.isCode
              ? _CodeCard(code: seg.text)
              : _textWidget(seg.text),
      ],
    );
  }

  Widget _textWidget(String s) {
    if (s.trim().isEmpty) return const SizedBox.shrink();
    final st =
        style ?? const TextStyle(fontSize: 14.5, height: 1.6);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: selectable
          ? SelectableText(s, style: st)
          : Text(s, style: st),
    );
  }
}

class _Seg {
  final String text;
  final bool isCode;
  _Seg(this.text, this.isCode);
}

/// Splits on ``` fences. Optional language tag after opening fence is dropped.
List<_Seg> _split(String text) {
  final out = <_Seg>[];
  var rest = text;
  while (true) {
    final start = rest.indexOf('```');
    if (start < 0) {
      out.add(_Seg(rest, false));
      break;
    }
    if (start > 0) out.add(_Seg(rest.substring(0, start), false));
    var codeStart = start + 3;
    // skip language tag on the first line
    final nl = rest.indexOf('\n', codeStart);
    final end = rest.indexOf('```', codeStart);
    if (end < 0) {
      // unclosed fence: treat remainder as code
      var code = rest.substring(codeStart);
      if (nl >= 0 && nl < codeStart + 30) {
        code = rest.substring(nl + 1);
      }
      out.add(_Seg(code, true));
      break;
    }
    var code = rest.substring(codeStart, end);
    if (nl >= 0 && nl < end && nl - codeStart < 20) {
      code = rest.substring(nl + 1, end);
    }
    out.add(_Seg(code.trim(), true));
    rest = rest.substring(end + 3);
  }
  return out;
}

class _CodeCard extends StatelessWidget {
  final String code;
  const _CodeCard({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.code_rounded,
                    size: 14, color: Color(0xFF7DD3FC)),
                const SizedBox(width: 6),
                Text(t('code'),
                    style: const TextStyle(
                        color: Color(0xFF7DD3FC),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy_rounded,
                      size: 16, color: Colors.white70),
                  tooltip: t('copied'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 32, minHeight: 32),
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: code));
                    showSnack(context, t('copied'));
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText.rich(
              TextSpan(children: _highlight(code)),
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.6,
                  color: Color(0xFFE2E8F0)),
            ),
          ),
        ],
      ),
    );
  }
}

final _tokRe = RegExp(
  r'(//[^\n]*|#[^\n]*|/\*[\s\S]*?\*/)'
  r'|("(?:[^"\\\n]|\\.)*"|'"'"'(?:[^'"'"'\\\n]|\\.)*'"'"')'
  r'|\b(import|from|class|def|return|if|else|elif|for|while|in|not|and|or|None|True|False|new|public|private|protected|static|void|int|String|double|bool|var|final|const|function|let|extends|implements|SELECT|FROM|WHERE|INSERT|INTO|VALUES|UPDATE|DELETE|CREATE|TABLE|JOIN|ON)\b'
  r'|\b(\d+(?:\.\d+)?)\b',
);

List<TextSpan> _highlight(String code) {
  final spans = <TextSpan>[];
  var last = 0;
  const base = TextStyle(color: Color(0xFFE2E8F0));
  for (final m in _tokRe.allMatches(code)) {
    if (m.start > last) {
      spans.add(TextSpan(
          text: code.substring(last, m.start), style: base));
    }
    final tok = m.group(0)!;
    TextStyle st;
    if (m.group(1) != null) {
      st = const TextStyle(
          color: Color(0xFF64748B), fontStyle: FontStyle.italic);
    } else if (m.group(2) != null) {
      st = const TextStyle(color: Color(0xFF86EFAC));
    } else if (m.group(3) != null) {
      st = const TextStyle(
          color: Color(0xFF7DD3FC), fontWeight: FontWeight.w700);
    } else {
      st = const TextStyle(color: Color(0xFFFDBA74));
    }
    spans.add(TextSpan(text: tok, style: st));
    last = m.end;
  }
  if (last < code.length) {
    spans.add(
        TextSpan(text: code.substring(last), style: base));
  }
  return spans;
}
