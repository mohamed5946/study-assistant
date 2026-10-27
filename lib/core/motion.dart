import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'store.dart';

/// v2.9 shared motion system (UI only — no logic changes).
///
/// Every animation in the app goes through these widgets so the feel is
/// one system, not a different easing per screen:
/// - press: scale 0.96, 120ms, easeOut, light haptic
/// - entrance: fade + slide-up, staggered 70ms per item
/// - reveal: fade + rise from 36px, ~0.85s, elastic overshoot, staggered
///   children, and the same motion in reverse (never a snap)
/// - Hero: unique tag per item, text wrapped in transparent Material
///
/// When [Settings.reduceAnim] is on, every widget below returns its child
/// instantly (zero duration, no scale, no haptic, no blur) — the setting
/// in SettingsScreen flips the whole app at once because MaterialApp
/// rebuilds on the 'reduceAnim' key.

/// Elastic overshoot easing for reveals (matches the reference video feel).
const elasticCurve = Cubic(0.22, 1.32, 0.36, 1);

/// Unique Hero tag for a navigating card. Never a shared literal: a tag
/// reused across cards throws "multiple heroes share the same tag".
String heroTag(String kind, String id) => '$kind-$id';

/// The flight child for a Hero must NOT contain a BackdropFilter: a
/// blurred glass card flying across the screen drops frames on mid-range
/// phones (Infinix NOTE 50S 5G). Flight children are plain gradient
/// containers; the glass blur lives only on the resting card.
class HeroFlightCard extends StatelessWidget {
  final Widget child;
  final List<Color> colors;
  const HeroFlightCard(
      {super.key, required this.child, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Press feedback: scale 0.96 + light haptic, 120ms easeOut.
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const PressScale({super.key, required this.child, this.onTap, this.onLongPress});

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    if (Settings.reduceAnim) return widget.child;
    if (widget.onTap == null && widget.onLongPress == null) {
      return widget.child;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Entrance: fade + slide-up, staggered 70ms per [index].
class FadeSlideIn extends StatelessWidget {
  final int index;
  final Widget child;
  const FadeSlideIn({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    if (Settings.reduceAnim) return child;
    final ms = 320 + (index > 8 ? 8 : index) * 70;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      curve: Curves.easeOutCubic,
      builder: (context, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 18), child: c),
      ),
      child: child,
    );
  }
}

/// Elastic reveal for card details: expands with [AnimatedSize] on the
/// 0.85s overshoot curve while its children fade + rise from 36px below,
/// staggered. Collapsing plays the same animation in reverse — the
/// content stays mounted while [expanded] flips, so it never snaps away.
class ElasticReveal extends StatelessWidget {
  final bool expanded;
  final List<Widget> children;
  const ElasticReveal(
      {super.key, required this.expanded, required this.children});

  @override
  Widget build(BuildContext context) {
    if (Settings.reduceAnim) {
      return expanded ? Column(children: children) : const SizedBox.shrink();
    }
    // One tween drives height, opacity and rise together, so collapsing
    // plays the same motion in reverse instead of snapping away.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: expanded ? 1 : 0),
      duration: const Duration(milliseconds: 950),
      curve: elasticCurve,
      builder: (context, v, _) {
        // Fully collapsed: remove the content from the tree (so it is
        // not focusable/readable) instead of leaving a 0-height column.
        if (v == 0) return const SizedBox.shrink();
        return ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: v.clamp(0.0, 1.0),
          child: Opacity(
            opacity: v.clamp(0.0, 1.0),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++)
                  Transform.translate(
                    offset: Offset(0, (1 - v) * 36 * (1 + i * 0.15)),
                    child: children[i],
                  ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }
}
