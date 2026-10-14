import 'package:flutter/material.dart';

/// A card wrapper that feels physically pressable: on touch it sinks down
/// (translate + slight scale, shadow compresses) and springs back on release
/// with an elastic curve — like a real 3D button.
///
/// Wraps any child; pass [onTap] to make it tappable.
class Pressable3D extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const Pressable3D({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
  });

  @override
  State<Pressable3D> createState() => _Pressable3DState();
}

class _Pressable3DState extends State<Pressable3D> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      behavior: HitTestBehavior.opaque,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: _pressed ? 1.0 : 0.0, end: _pressed ? 1.0 : 0.0),
        duration: Duration(milliseconds: _pressed ? 90 : 320),
        curve: _pressed ? Curves.easeIn : Curves.elasticOut,
        builder: (context, t, child) {
          // t: 0 = resting, 1 = fully pressed
          return Transform.translate(
            offset: Offset(0, 3.5 * t),
            child: Transform.scale(
              scale: 1.0 - 0.025 * t,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius:
                      widget.borderRadius ?? BorderRadius.circular(20),
                  boxShadow: [
                    // Compressed shadow when pressed — card "sinks".
                    BoxShadow(
                      color: Colors.black.withValues(
                          alpha: 0.14 * (1 - 0.55 * t)),
                      blurRadius: 18 * (1 - 0.5 * t),
                      offset: Offset(0, 8 * (1 - t) + 1),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
