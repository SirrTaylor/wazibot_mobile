/// lib/features/reminders/presentation/screens/reminders_screen.dart
///
/// "What payments need a nudge today?" — the mobile equivalent of the
/// web dashboard's Reminders tab, simplified to what an owner can act
/// on with one tap each: see who hasn't paid, and nudge them.
///
/// Backend: GET /payments/reminders/pending → {count, orders:[...]}
///          POST /payments/reminders/{order_id}/nudge?dry_run=false
///          POST /payments/reminders/send?dry_run=false (bulk)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../shared/providers/cached_providers.dart';

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final remindersAsync = ref.watch(paymentRemindersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.invalidate(paymentRemindersProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: WaziBotColors.primary,
        onRefresh: () async {
          await Haptics.refresh();
          ref.invalidate(paymentRemindersProvider);
        },
        child: remindersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(apiErrorMessage(e))),
          data: (data) {
            final orders =
                (data['orders'] as List?)?.cast<Map<String, dynamic>>() ??
                    [];
            if (orders.isEmpty) {
              return const _EmptyState();
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                Text(
                  '${orders.length} payment${orders.length == 1 ? '' : 's'} waiting',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'A quick nudge often gets these paid within minutes.',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                ...orders.map((o) => _ReminderCard(order: o)),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: remindersAsync.maybeWhen(
        data: (data) {
          final count = (data['count'] as num?)?.toInt() ?? 0;
          if (count == 0) return null;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _SendAllButton(count: count),
            ),
          );
        },
        orElse: () => null,
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                size: 52, color: WaziBotColors.success),
            const SizedBox(height: 16),
            Text('All caught up', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'No payments are waiting on a reminder right now.',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reminder card ──────────────────────────────────────────────────────────────
class _ReminderCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> order;
  const _ReminderCard({required this.order});

  @override
  ConsumerState<_ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends ConsumerState<_ReminderCard> {
  bool _sending = false;
  bool _sent = false;

  static const _tierColors = {
    1: WaziBotColors.warning,
    2: Color(0xFFF97316),
    3: WaziBotColors.error,
  };

  static const _tierLabels = {
    1: 'First reminder',
    2: 'Second reminder',
    3: 'Final reminder',
  };

  Future<void> _nudge() async {
    final orderId = widget.order['order_id'];
    if (orderId == null) return;
    setState(() => _sending = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/payments/reminders/$orderId/nudge?dry_run=false');
      await Haptics.success();
      if (mounted) setState(() => _sent = true);
      ref.invalidate(paymentRemindersProvider);
    } catch (e) {
      await Haptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(apiErrorMessage(e)),
          backgroundColor: WaziBotColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _age(String? createdAt) {
    if (createdAt == null) return '';
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return '';
    final hours = DateTime.now().difference(dt).inHours;
    if (hours < 1) return 'less than 1h ago';
    if (hours < 24) return '${hours}h ago';
    return '${(hours / 24).floor()}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final o = widget.order;
    final orderId = o['order_id'];
    final phone = o['customer_phone'] as String? ?? '';
    final total = (o['total_price'] as num?)?.toDouble() ?? 0;
    final method = (o['payment_method'] as String? ?? '')
        .replaceAll('_', ' ');
    final tier = (o['reminder_tier'] as num?)?.toInt() ?? 1;
    final tierColor = _tierColors[tier] ?? WaziBotColors.warning;
    final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 2);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Text('ORDER-$orderId', style: theme.textTheme.titleSmall),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tierColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _tierLabels[tier] ?? 'Reminder',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: tierColor),
                    ),
                  ),
                ]),
                Text(currency.format(total),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: WaziBotColors.primary)),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.person_outline,
                  size: 13, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(phone, style: theme.textTheme.bodySmall),
              const SizedBox(width: 12),
              if (method.isNotEmpty) ...[
                Icon(Icons.payment_outlined,
                    size: 13, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(method, style: theme.textTheme.bodySmall),
              ],
            ]),
            const SizedBox(height: 2),
            Text(_age(o['created_at'] as String?),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _sending || _sent ? null : _nudge,
                  icon: _sending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _sent
                              ? Icons.check_circle_outline
                              : Icons.send_outlined,
                          size: 16,
                        ),
                  label: Text(_sent ? 'Sent' : 'Send Reminder'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        _sent ? WaziBotColors.success : WaziBotColors.warning,
                    side: BorderSide(
                        color: _sent
                            ? WaziBotColors.success
                            : WaziBotColors.warning),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (phone.isNotEmpty)
                IconButton(
                  tooltip: 'Open conversation',
                  icon: const Icon(Icons.chat_outlined, size: 20),
                  onPressed: () {
                    Haptics.light();
                    context.push('/inbox/$phone');
                  },
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Send all button ───────────────────────────────────────────────────────────
class _SendAllButton extends ConsumerStatefulWidget {
  final int count;
  const _SendAllButton({required this.count});

  @override
  ConsumerState<_SendAllButton> createState() => _SendAllButtonState();
}

class _SendAllButtonState extends ConsumerState<_SendAllButton> {
  bool _sending = false;

  Future<void> _sendAll() async {
    setState(() => _sending = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/payments/reminders/send?dry_run=false');
      await Haptics.success();
      ref.invalidate(paymentRemindersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('All reminders sent ✓'),
          backgroundColor: WaziBotColors.success,
        ));
      }
    } catch (e) {
      await Haptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(apiErrorMessage(e)),
          backgroundColor: WaziBotColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _sending ? null : _sendAll,
      icon: _sending
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.black),
            )
          : const Icon(Icons.send_rounded, color: Colors.black, size: 18),
      label: Text('Send All Reminders (${widget.count})'),
    );
  }
}
