import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'store.dart';
import 'theme.dart';

/// v2.14: animated aurora background for the AI chat screen ONLY.
///
/// Same blue-family palette as the static [AuroraBackground] (pale blue
/// base, sky-blue glows — never lavender/purple), but the four glows
/// drift slowly on sine paths while the chat screen is open, so the
/// background keeps moving behind the messages. The [AnimationController]
/// is created here and disposed with the screen, so the animation stops
/// the moment the user leaves chat — it never runs app-wide. When
/// [Settings.reduceAnim] is on, the static blobs render with no
/// controller ticking at all. Every glow layer sits behind a
/// [RepaintBoundary] and uses cheap radial gradients only — no
/// full-screen shader — so the Infinix stays smooth.
class AnimatedAuroraBackground extends StatefulWidget {
  final Widget child;
  const AnimatedAuroraBackground({super.key, required this.child});

  @override
  State<AnimatedAuroraBackground> createState() =>
      _AnimatedAuroraBackgroundState();
}

class _AnimatedAuroraBackgroundState extends State<AnimatedAuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );
    // Static when reduce-animation is on: no repeat, no ticking.
    if (!Settings.reduceAnim) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Settings.reduceAnim) return _staticStack(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value * 2 * math.pi;
        return Stack(
          children: [
            _driftingBlob(
              dark
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.primary.withValues(alpha: 0.20),
              320,
              top: -110 + 26 * math.sin(t),
              right: -80 + 30 * math.cos(t * 0.9),
            ),
            _driftingBlob(
              dark
                  ? AppColors.primaryDark.withValues(alpha: 0.30)
                  : const Color(0xFF7DD3FC).withValues(alpha: 0.22),
              280,
              top: 180 + 30 * math.cos(t * 0.8),
              left: -90 + 26 * math.sin(t * 1.1),
            ),
            _driftingBlob(
              dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.70),
              260,
              bottom: -70 + 22 * math.sin(t * 0.7),
              left: 60 + 28 * math.cos(t),
            ),
            _driftingBlob(
              dark
                  ? const Color(0xFF1E3A5F).withValues(alpha: 0.50)
                  : const Color(0xFFBFDBFE).withValues(alpha: 0.35),
              220,
              bottom: -40 + 24 * math.cos(t * 1.2),
              right: -40 + 26 * math.sin(t * 0.9),
            ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }

  /// Static twin of the animated stack (same positions, same palette).
  Widget _staticStack(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned(
          top: -110,
          right: -80,
          child: _blob(
              dark
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.primary.withValues(alpha: 0.20),
              320),
        ),
        Positioned(
          top: 180,
          left: -90,
          child: _blob(
              dark
                  ? AppColors.primaryDark.withValues(alpha: 0.30)
                  : const Color(0xFF7DD3FC).withValues(alpha: 0.22),
              280),
        ),
        Positioned(
          bottom: -70,
          left: 60,
          child: _blob(
              dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.70),
              260),
        ),
        Positioned(
          bottom: -40,
          right: -40,
          child: _blob(
              dark
                  ? const Color(0xFF1E3A5F).withValues(alpha: 0.50)
                  : const Color(0xFFBFDBFE).withValues(alpha: 0.35),
              220),
        ),
        widget.child,
      ],
    );
  }

  Widget _driftingBlob(Color c, double size,
      {double? top, double? left, double? right, double? bottom}) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: RepaintBoundary(child: _blob(c, size)),
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

/// v2.14: message-entry animation — a new chat message fades + slides
/// up once when it first appears ([animate] is true only for messages
/// the screen has not rendered before; the screen tracks seen ids so
/// scrolling back never replays it). Skipped under reduce-animation.
class ChatMessageEntry extends StatelessWidget {
  final bool animate;
  final Widget child;
  const ChatMessageEntry(
      {super.key, required this.animate, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!animate || Settings.reduceAnim) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 16), child: c),
      ),
      child: child,
    );
  }
}

/// v2.14: typing indicator — three dots that bounce in a staggered
/// loop while the AI is responding. Static dots under reduce-animation.
class TypingDots extends StatefulWidget {
  const TypingDots({super.key});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (!Settings.reduceAnim) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Settings.reduceAnim) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(scale: 1, opacity: 1),
          SizedBox(width: 5),
          _Dot(scale: 1, opacity: 1),
          SizedBox(width: 5),
          _Dot(scale: 1, opacity: 1),
        ],
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              _Dot(
                scale: _dotScale(i),
                opacity: _dotOpacity(i),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Staggered bounce: each dot peaks 0.18 of a cycle after the last.
  double _dotScale(int i) {
    final phase = (_c.value - i * 0.18) % 1.0;
    return 0.6 + 0.4 * math.sin(phase * math.pi);
  }

  double _dotOpacity(int i) {
    final phase = (_c.value - i * 0.18) % 1.0;
    return 0.4 + 0.6 * math.sin(phase * math.pi);
  }
}

class _Dot extends StatelessWidget {
  final double scale;
  final double opacity;
  const _Dot({required this.scale, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
