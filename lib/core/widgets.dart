import 'package:flutter/material.dart';
import 'l10n.dart';
import 'theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.violet]),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20)
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 38),
            ),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 15)),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              GlassButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

Future<bool> confirmDelete(BuildContext context, {String? message}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(t('confirmDelete')),
      content: Text(message ?? t('confirmDeleteMsg')),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false), child: Text(t('no'))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(context, true),
          child: Text(t('yes')),
        ),
      ],
    ),
  );
  return r == true;
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final List<Color> gradient;
  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 10),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12)),
        ],
      ),
    );
  }
}

void showSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : null,
    ),
  );
}

String formatMinutes(int totalMin) {  final h = totalMin ~/ 60;
  final m = totalMin % 60;
  if (h == 0) return '$m ${t('min')}';
  return '${h}h ${m}m';
}

String formatClock(int minutes) {
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

/// Labeled dropdown (avoids the deprecated DropdownButtonFormField.value).
class LabeledDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  const LabeledDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
