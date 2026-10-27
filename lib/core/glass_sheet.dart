import 'dart:ui';
import 'package:flutter/material.dart';

/// Shared Liquid Glass bottom sheet: slide-up (push-up) container with a
/// blurred backdrop, theme-aware translucent gradient, bright top-edge
/// highlight line, drag handle pill, rounded top corners and soft shadow.
///
/// All add/edit input forms in the app open through this helper so they
/// share one tidy 3D-glass look. The returned future completes with
/// whatever value the sheet pops with (e.g. `true`/`false` for
/// save/cancel), exactly like `showDialog`.
Future<T?> showGlassSheet<T>(
  BuildContext context,
  Widget child, {
  String? title,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      final theme = Theme.of(sheetCtx);
      final dark = theme.brightness == Brightness.dark;
      final kb = MediaQuery.of(sheetCtx).viewInsets.bottom;
      return RepaintBoundary(
        child: BackdropFilter(
          // blur of the page behind the sheet
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Padding(
          padding: EdgeInsets.only(
            left: 8,
            right: 8,
            bottom: kb, // keyboard support
          ),
          child: SafeArea(
            child: Container(
              margin: const EdgeInsets.only(top: 48),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: dark
                      ? [
                          const Color(0xFF22305A)
                              .withValues(alpha: 0.94),
                          const Color(0xFF101B38)
                              .withValues(alpha: 0.96),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.90),
                          const Color(0xFFEAF3FF)
                              .withValues(alpha: 0.90),
                        ],
                ),
                border: Border.all(
                  color:
                      Colors.white.withValues(alpha: dark ? 0.16 : 0.8),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: dark ? 0.5 : 0.18),
                    blurRadius: 32,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // bright top-edge highlight line (Liquid Glass cue)
                  Positioned(
                    top: 0,
                    left: 56,
                    right: 56,
                    child: Container(
                      height: 2.5,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(colors: [
                          Colors.transparent,
                          Colors.white
                              .withValues(alpha: 0.95),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 10, 20, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          // drag handle pill
                          Center(
                            child: Container(
                              width: 44,
                              height: 5,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.45),
                                borderRadius:
                                    BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          if (title != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color:
                                    theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          child,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      );
    },
  );
}
