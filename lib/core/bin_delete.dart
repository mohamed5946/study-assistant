import 'package:flutter/material.dart';

import 'l10n.dart';
import 'store.dart';
import 'theme.dart';

/// v2.14: "the bin eats the label" delete button.
///
/// A red pill with a trash bin and a text label. On [start] (tap, or
/// automatically when [autoStart] is true) it plays, over ~1s:
///   1. the bin lid swings open,
///   2. the label's letters fly one by one into the bin (fade + slide
///      toward the icon + shrink, staggered),
///   3. the pill shrinks to a circle holding only the bin,
/// then [onComplete] fires — the caller runs the actual deletion only
/// after that, so the animation is never a substitute for confirmation.
///
/// Wiring: [confirmDelete] (the shared Yes/No dialog every delete in
/// the app goes through) swaps its Yes button for this widget once Yes
/// is tapped, so every confirmed delete — lecture, deadline, note,
/// subject, chat clear, data clear, ... — gets the animation with no
/// call-site changes, and no delete can ever animate without the user
/// having confirmed first. Under [Settings.reduceAnim] the animation
/// is skipped and [onComplete] fires on the next frame.
class BinDeleteButton extends StatefulWidget {
  final String label;
  final bool autoStart;
  final VoidCallback onComplete;
  const BinDeleteButton({
    super.key,
    required this.label,
    required this.onComplete,
    this.autoStart = false,
  });

  @override
  State<BinDeleteButton> createState() => _BinDeleteButtonState();
}

class _BinDeleteButtonState extends State<BinDeleteButton>
    with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 1000);
  static const _height = 52.0;
  static const _binWidth = 28.0;
  late final AnimationController _c;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _total)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _finish();
      });
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _start() {
    if (_done || _c.isAnimating || !mounted) return;
    if (Settings.reduceAnim) {
      _finish();
    } else {
      _c.forward();
    }
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onComplete();
  }

  /// Width of the label text at the button's text style, so the pill
  /// hugs its label instead of using a guessed fixed width.
  double _labelWidth() {
    final tp = TextPainter(
      text: TextSpan(
        text: widget.label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.width;
  }

  @override
  Widget build(BuildContext context) {
    final pillWidth = 20 + _binWidth + 10 + _labelWidth() + 20;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return GestureDetector(
      onTap: _start,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          // Phase 1 (0–0.65): lid opens, letters get eaten.
          // Phase 2 (0.65–1): pill shrinks to a circle.
          final shrinkT = t <= 0.65
              ? 0.0
              : Curves.easeOutCubic.transform((t - 0.65) / 0.35);
          final width =
              pillWidth + (_height - pillWidth) * shrinkT;
          final lidAngle = t < 0.2 ? -0.55 * (t / 0.2) : -0.55;
          final letters = widget.label.characters.toList();
          return SizedBox(
            width: width,
            height: _height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Container(
                color: AppColors.error,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _bin(lidAngle),
                      if (t < 0.65) ...[
                        const SizedBox(width: 10),
                        for (var i = 0; i < letters.length; i++)
                          _letter(letters[i], i, t, rtl),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// One label letter mid-flight: fades, slides toward the bin icon
  /// and shrinks, staggered by index so letters are eaten one by one.
  Widget _letter(String ch, int i, double t, bool rtl) {
    final start = 0.15 + i * 0.06;
    final end = (start + 0.25).clamp(0.0, 0.65);
    final p = t <= start
        ? 0.0
        : t >= end
            ? 1.0
            : (t - start) / (end - start);
    final towardBin = rtl ? 26.0 * p : -26.0 * p;
    return Opacity(
      opacity: 1 - p,
      child: Transform.translate(
        offset: Offset(towardBin, -8 * p),
        child: Transform.scale(
          scale: 1 - 0.5 * p,
          child: Text(
            ch,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  /// Trash bin drawn from shapes so its lid can swing open: a lid bar
  /// hinged at its leading edge, over a slitted bin body.
  Widget _bin(double lidAngle) {
    return SizedBox(
      width: _binWidth,
      height: 32,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: lidAngle,
            alignment: Alignment.centerLeft,
            child: Container(
              width: 26,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 22,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(6),
                topLeft: Radius.circular(2),
                topRight: Radius.circular(2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    width: 2,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The Yes button of the shared delete-confirmation dialog: on tap it
/// swaps itself for a [BinDeleteButton] (bin eats the "حذف"/"Delete"
/// label, pill shrinks to a circle) and only then calls [onConfirmed]
/// — so the dialog's caller runs the real deletion after the
/// animation, never before confirmation.
class AnimatedConfirmYesButton extends StatefulWidget {
  final VoidCallback onConfirmed;
  const AnimatedConfirmYesButton({super.key, required this.onConfirmed});

  @override
  State<AnimatedConfirmYesButton> createState() =>
      _AnimatedConfirmYesButtonState();
}

class _AnimatedConfirmYesButtonState extends State<AnimatedConfirmYesButton> {
  bool _animating = false;

  @override
  Widget build(BuildContext context) {
    if (_animating) {
      return BinDeleteButton(
        label: t('delete'),
        autoStart: true,
        onComplete: widget.onConfirmed,
      );
    }
    return FilledButton(
      style: FilledButton.styleFrom(backgroundColor: AppColors.error),
      onPressed: () => setState(() => _animating = true),
      child: Text(t('yes')),
    );
  }
}

