/// lib/shared/widgets/sync_indicator.dart
///
/// Shows sync status: spinning icon when syncing, check when done,
/// pending count badge when writes are queued, wifi-off when offline.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/theme/app_theme.dart';

class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncProvider);
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => ref.read(syncProvider.notifier).forceSync(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SyncIcon(sync: sync),
            const SizedBox(width: 4),
            Text(
              sync.statusLabel,
              style: TextStyle(
                fontSize: 10,
                color: _labelColor(sync, theme),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (sync.pendingWrites > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: WaziBotColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${sync.pendingWrites}',
                  style: const TextStyle(
                      fontSize: 9,
                      color: WaziBotColors.warning,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _labelColor(SyncState sync, ThemeData theme) {
    if (!sync.isOnline) return WaziBotColors.warning;
    if (sync.error != null) return WaziBotColors.error;
    return theme.colorScheme.onSurfaceVariant;
  }
}

class _SyncIcon extends StatefulWidget {
  final SyncState sync;
  const _SyncIcon({required this.sync});

  @override
  State<_SyncIcon> createState() => _SyncIconState();
}

class _SyncIconState extends State<_SyncIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.sync.isSyncing) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(_SyncIcon old) {
    super.didUpdateWidget(old);
    if (widget.sync.isSyncing && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.sync.isSyncing && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sync = widget.sync;

    if (!sync.isOnline) {
      return const Icon(Icons.wifi_off_outlined,
          size: 14, color: WaziBotColors.warning);
    }
    if (sync.isSyncing) {
      return RotationTransition(
        turns: _ctrl,
        child: const Icon(Icons.sync_rounded,
            size: 14, color: WaziBotColors.primary),
      );
    }
    if (sync.error != null) {
      return const Icon(Icons.sync_problem_outlined,
          size: 14, color: WaziBotColors.error);
    }
    if (sync.pendingWrites > 0) {
      return const Icon(Icons.upload_outlined,
          size: 14, color: WaziBotColors.warning);
    }
    return const Icon(Icons.check_circle_outline,
        size: 14, color: WaziBotColors.success);
  }
}

/// Compact dot-only sync indicator for tight spaces (e.g. bottom nav badge)
class SyncDot extends ConsumerWidget {
  const SyncDot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncProvider);
    if (sync.isOnline && !sync.isSyncing && sync.pendingWrites == 0) {
      return const SizedBox.shrink();
    }
    final color = !sync.isOnline
        ? WaziBotColors.warning
        : sync.pendingWrites > 0
            ? WaziBotColors.warning
            : WaziBotColors.primary;

    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
