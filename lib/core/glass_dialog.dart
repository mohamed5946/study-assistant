import 'dart:ui';
import 'package:flutter/material.dart';

/// Shared Liquid Glass dialog: blue glass look matching the subject-card
/// banner, with a smooth fade entrance.
///
/// REWRITTEN (v2.4-test3): uses the standard [showDialog] route instead of
/// [showGeneralDialog] — the general-dialog route was producing a
/// yellow double-line artifact under dialog text on some devices.
/// The v2.2 plain [showDialog] never had this issue.
Future<T?> showGlassDialog<T>(
  BuildContext context, {
  String? title,
  required Widget content,
  List<Widget>? actions,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final dark = theme.brightness == Brightness.dark;
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? [
                        const Color(0xFF24365F).withValues(alpha: 0.97),
                        const Color(0xFF0F1C3A).withValues(alpha: 0.98),
                      ]
                    : [
                        const Color(0xFFDCEEFF).withValues(alpha: 0.96),
                        const Color(0xFF9CC8F5).withValues(alpha: 0.96),
                      ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: dark ? 0.20 : 0.75),
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E6FC4)
                      .withValues(alpha: dark ? 0.35 : 0.28),
                  blurRadius: 36,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.5 : 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                // bright top-edge highlight line (Liquid Glass cue)
                Positioned(
                  top: 0,
                  left: 64,
                  right: 64,
                  child: Container(
                    height: 2.5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.95),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (title != null) ...[
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      content,
                      if (actions != null && actions.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Row(children: [
                          for (var i = 0; i < actions.length; i++) ...[
                            if (i > 0) const SizedBox(width: 10),
                            Expanded(child: actions[i]),
                          ],
                        ]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
