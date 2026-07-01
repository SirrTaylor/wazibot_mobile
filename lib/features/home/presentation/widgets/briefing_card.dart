/// lib/features/home/presentation/widgets/briefing_card.dart
///
/// "Today's Business Briefing" — the centerpiece of the redesigned Home
/// screen. Shows a greeting + 3-5 dynamically generated insights so a
/// busy owner knows exactly what needs attention in under 10 seconds.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/haptics.dart';
import '../../domain/briefing_item.dart';

class BriefingCard extends StatelessWidget {
  final String greeting;
  final List<BriefingItem> items;
  final String closingLine;
  final bool isLoading;

  const BriefingCard({
    super.key,
    required this.greeting,
    required this.items,
    required this.closingLine,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            WaziBotColors.primary.withValues(alpha: 0.16),
            WaziBotColors.primary.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: WaziBotColors.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Here's what needs your attention today.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          if (isLoading) ...[
            const _BriefingShimmerLines(),
          ] else if (items.isEmpty) ...[
            Row(children: [
              const Icon(Icons.check_circle_outline_rounded,
                  size: 18, color: WaziBotColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Everything looks good today. No action needed.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface),
                ),
              ),
            ]),
          ] else ...[
            ...items.map((item) => _BriefingRow(item: item)),
            const SizedBox(height: 4),
            Text(
              closingLine,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BriefingRow extends StatelessWidget {
  final BriefingItem item;
  const _BriefingRow({required this.item});

  Color _toneColor() {
    switch (item.tone) {
      case BriefingTone.urgent:
        return WaziBotColors.error;
      case BriefingTone.warning:
        return WaziBotColors.warning;
      case BriefingTone.positive:
        return WaziBotColors.success;
      case BriefingTone.neutral:
        return WaziBotColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _toneColor();
    final tappable = item.route != null;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.3,
              ),
            ),
          ),
          if (tappable)
            Icon(Icons.chevron_right_rounded,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );

    if (!tappable) return row;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        Haptics.light();
        context.go(item.route!);
      },
      child: row,
    );
  }
}

class _BriefingShimmerLines extends StatelessWidget {
  const _BriefingShimmerLines();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: List.generate(
        3,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 14,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
