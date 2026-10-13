import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The ONE branded loading indicator for the whole app: a small glass-blue
/// circle with an animated open book whose pages keep flipping.
///
/// GPU-cheap by design: a single [AnimationController] driving one
/// [CustomPainter] repaint — no image assets, no shadows animating.
class BookLoader extends StatefulWidget {
  final double size;
  const BookLoader({super.key, this.size = 72});

  @override
  State<BookLoader> createState() => _BookLoaderState();
}

class _BookLoaderState extends State<BookLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [const Color(0xFF2A3D6B), const Color(0xFF131F3D)]
              : [const Color(0xFFE3F1FF), const Color(0xFF9CC8F5)],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? 0.25 : 0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E6FC4).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: _FlippingBookPainter(
            progress: _c.value,
            dark: dark,
          ),
        ),
      ),
    );
  }
}

class _FlippingBookPainter extends CustomPainter {
  final double progress; // 0..1, one full page flip per cycle
  final bool dark;
  const _FlippingBookPainter({required this.progress, required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final pw = w * 0.30; // half-page width
    final ph = h * 0.44; // page height
    final top = cy - ph / 2;

    final cover = Paint()
      ..color = dark ? const Color(0xFF0D1730) : const Color(0xFF1E6FC4);
    final page = Paint()
      ..color = dark ? const Color(0xFFDCE9FF) : Colors.white;
    final spine = Paint()
      ..color = (dark ? const Color(0xFF0D1730) : const Color(0xFF1E6FC4))
          .withValues(alpha: 0.55);

    RRect rr(double l, double t, double r, double b, double rad) =>
        RRect.fromLTRBR(l, t, r, b, Radius.circular(rad));

    // book cover (slightly larger rounded rect behind the pages)
    canvas.drawRRect(
        rr(cx - pw - 3, top - 3, cx + pw + 3, top + ph + 3, 5), cover);
    // static left + right pages
    canvas.drawRRect(rr(cx - pw, top, cx - 1, top + ph, 3), page);
    canvas.drawRRect(rr(cx + 1, top, cx + pw, top + ph, 3), page);
    // center spine line
    canvas.drawRect(Rect.fromLTWH(cx - 1, top, 2, ph), spine);

    // the flipping page: sweeps right -> left, faked in 2D by shrinking
    // its horizontal extent with a cosine and shading it by the sine.
    final angle = progress * math.pi;
    final dx = math.cos(angle) * pw;
    final shade = (math.sin(angle).abs() * 70).round().clamp(0, 70);
    final base = dark ? const Color(0xFFDCE9FF) : Colors.white;
    final flipPaint = Paint()
      ..color = Color.fromARGB(
        255,
        (base.red - shade).clamp(0, 255),
        (base.green - shade).clamp(0, 255),
        (base.blue - shade ~/ 2).clamp(0, 255),
      );

    final x0 = dx >= 0 ? cx : cx + dx;
    final x1 = dx >= 0 ? cx + dx : cx;
    if ((x1 - x0).abs() > 0.5) {
      canvas.drawRRect(rr(x0, top, x1, top + ph, 3), flipPaint);
      // page edge line for definition
      canvas.drawLine(
        Offset(x1, top + 2),
        Offset(x1, top + ph - 2),
        Paint()
          ..color = cover.color.withValues(alpha: 0.35)
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(_FlippingBookPainter old) =>
      old.progress != progress || old.dark != dark;
}

/// Full-screen branded launch splash: flipping-book loader + app name on a
/// brand-blue gradient. Shown while the app initializes in [main].
class BookSplash extends StatelessWidget {
  const BookSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2E8FE8), Color(0xFF0E4EA8)],
            ),
          ),
          child: const SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BookLoader(size: 110),
                SizedBox(height: 26),
                Text(
                  'مساعد الطالب',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Study Assistant',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
