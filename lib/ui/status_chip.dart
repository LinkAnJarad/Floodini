import 'package:flutter/material.dart';

import 'theme.dart';

enum StatusTone { safe, caution, danger, neutral }

/// Compact pill (32 dp) with a state dot. Never relies on color alone: the
/// label always says what the state is.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.icon,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.floodini;
    final (Color background, Color foreground, Color accent) = switch (tone) {
      StatusTone.safe => (
        colors.safeContainer,
        colors.onSafeContainer,
        colors.safe,
      ),
      StatusTone.caution => (
        colors.cautionContainer,
        colors.onCautionContainer,
        colors.caution,
      ),
      StatusTone.danger => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        scheme.error,
      ),
      StatusTone.neutral => (
        scheme.surfaceContainerHigh,
        scheme.onSurfaceVariant,
        scheme.outline,
      ),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 16, color: foreground)
          else
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium!
                  .copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Offline mode · Handa na". Shown only inside the app shell, which is reached
/// only after the profile and every on-device model are installed.
class OfflineReadyChip extends StatelessWidget {
  const OfflineReadyChip({super.key});

  @override
  Widget build(BuildContext context) =>
      const StatusChip(label: 'Offline mode · Handa na', tone: StatusTone.safe);
}
