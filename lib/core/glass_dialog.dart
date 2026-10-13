import 'dart:ui';
import 'package:flutter/material.dart';

/// Shared Liquid Glass dialog: blue glass look matching the subject-card
/// banner (NOT a plain white dialog), with a smooth scale+fade entrance —
/// never a sudden popup.
///
/// Use for every dialog/popup in the app (confirmations, pickers, small
/// forms like "add flashcard"). Large input forms keep using
/// [showGlassSheet]; this is for true dialogs.
Future<T?> showGlassDialog<T>(
  BuildContext context, {
  String? title,
  required Widget content,
  List<Widget>? actions,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, _, __) {
      final theme = Theme.of(ctx);
      final dark = theme.brightness == Brightness.dark;
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: Colors.black.withValues(alpha: dark ? 0.45 : 0.28),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
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
                              const Color(0xFF24365F)
                                  .withValues(alpha: 0.97),
                              const Color(0xFF0F1C3A)
                                  .withValues(alpha: 0.98),
                            ]
                          : [
                              const Color(0xFFDCEEFF)
                                  .withValues(alpha: 0.96),
                              const Color(0xFF9CC8F5)
                                  .withValues(alpha: 0.96),
                            ],
                    ),
                    border: Border.all(
                      color: Colors.white
                          .withValues(alpha: dark ? 0.20 : 0.75),
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
                        color: Colors.black
                            .withValues(alpha: dark ? 0.5 : 0.16),
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
                        padding:
                            const EdgeInsets.fromLTRB(22, 20, 22, 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            if (title != null) ...[
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color:
                                      theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            content,
                            if (actions != null &&
                                actions.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              Row(children: [
                                for (var i = 0;
                                    i < actions.length;
                                    i++) ...[
                                  if (i > 0)
                                    const SizedBox(width: 10),
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
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, _, child) {
      final scale = Tween<double>(begin: 0.9, end: 1.0).animate(
        CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        ),
      );
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(scale: scale, child: child),
      );
    },
  );
}
