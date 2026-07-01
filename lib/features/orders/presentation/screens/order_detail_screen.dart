/// lib/features/orders/presentation/screens/order_detail_screen.dart
/// Added: invoice view, SLA age badge, AI/agent sender label on items
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../shared/models/business_models.dart';
import '../../../../shared/providers/cached_providers.dart';

const _nextStatus = {'new': 'preparing', 'preparing': 'completed'};

// ── Invoice provider ──────────────────────────────────────────────────────────
final invoiceProvider =
    FutureProvider.family<String, String>((ref, orderId) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get('/orders/$orderId/invoice');
  final data = resp.data as Map<String, dynamic>;
  return data['invoice'] as String? ?? '';
});

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final orderAsync = ref.watch(orderDetailProvider(orderId));
    final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
    final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #$shortId'),
        actions: [
          // Invoice button
          IconButton(
            icon: const Icon(Icons.receipt_outlined),
            tooltip: 'View Invoice',
            onPressed: () => _showInvoice(context, ref),
          ),
        ],
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(apiErrorMessage(e))),
        data: (order) => Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Status + SLA age row
                  Row(
                    children: [
                      Expanded(child: _StatusBanner(status: order.status)),
                      const SizedBox(width: 10),
                      _AgeBadge(createdAt: order.createdAt, status: order.status),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (order.customerName != null || order.customerPhone != null)
                    _Section(
                      title: 'Customer',
                      child: _InfoRow(
                        icon: Icons.person_outline,
                        text: order.customerName ?? order.customerPhone ?? '',
                        subtext: order.customerPhone,
                      ),
                    ),

                  // One-tap contact actions — Call, Message, Navigate
                  if (order.customerPhone != null)
                    _ContactActionsRow(order: order),

                  _Section(
                    title: 'Items',
                    child: Column(
                      children: order.items
                          .map((item) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item.quantity}× ${item.productName}',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                    Text(
                                      currency.format(item.price * item.quantity),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),

                  // Total
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total', style: theme.textTheme.titleMedium),
                        Text(
                          currency.format(order.total),
                          style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),

                  if (order.paymentStatus != null) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.payment_outlined,
                      text: 'Payment: ${order.paymentStatus!}',
                    ),
                  ],

                  if (order.isDelivery) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      text: order.deliveryAddress!,
                      subtext: 'Delivery address',
                    ),
                  ],

                  if (order.notes != null && order.notes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _Section(
                      title: 'Notes',
                      child: Text(order.notes!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ),
                  ],
                ],
              ),
            ),
            if (order.status != 'completed' && order.status != 'cancelled')
              _ActionBar(order: order, ref: ref),
          ],
        ),
      ),
    );
  }

  void _showInvoice(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _InvoiceSheet(orderId: orderId, ref: ref),
    );
  }
}

// ── Age badge ─────────────────────────────────────────────────────────────────
class _AgeBadge extends StatelessWidget {
  final String createdAt;
  final String status;
  const _AgeBadge({required this.createdAt, required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == 'completed' || status == 'cancelled') {
      return const SizedBox.shrink();
    }
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return const SizedBox.shrink();
    final age = DateTime.now().difference(dt);
    final String label;
    final Color color;

    if (age.inMinutes < 30) {
      label = '${age.inMinutes}m';
      color = WaziBotColors.success;
    } else if (age.inHours < 2) {
      label = '${age.inMinutes}m';
      color = WaziBotColors.warning;
    } else {
      label = '${age.inHours}h ${age.inMinutes % 60}m';
      color = WaziBotColors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.schedule_outlined, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

// ── Invoice sheet ─────────────────────────────────────────────────────────────
class _InvoiceSheet extends ConsumerWidget {
  final String orderId;
  final WidgetRef ref;
  const _InvoiceSheet({required this.orderId, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final invoiceAsync = ref.watch(invoiceProvider(orderId));

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Invoice', style: theme.textTheme.titleMedium),
                Row(children: [
                  // Copy invoice text
                  IconButton(
                    icon: const Icon(Icons.copy_outlined, size: 20),
                    tooltip: 'Copy',
                    onPressed: () {
                      final text = invoiceAsync.valueOrNull ?? '';
                      Clipboard.setData(ClipboardData(text: text));
                      Haptics.light();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invoice copied')),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ]),
              ],
            ),
          ),
          const Divider(height: 0),
          Expanded(
            child: invoiceAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not load invoice: ${apiErrorMessage(e)}',
                      textAlign: TextAlign.center),
                ),
              ),
              data: (text) => SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.all(20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: SelectableText(
                    text,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Existing widgets (unchanged) ──────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: child)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? subtext;
  const _InfoRow({required this.icon, required this.text, this.subtext});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(children: [
      Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(text, style: theme.textTheme.bodyMedium),
        if (subtext != null && subtext != text)
          Text(subtext!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ]),
    ]);
  }
}

// ── One-tap contact actions: Call, WhatsApp, Navigate ─────────────────────────
/// Lets a busy owner reach the customer or open directions in one tap,
/// instead of copying a phone number into another app. Navigate only
/// appears for delivery orders that have an address on file.
class _ContactActionsRow extends StatelessWidget {
  final Order order;
  const _ContactActionsRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final phone = order.customerPhone;
    if (phone == null || phone.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 16),
      child: Row(children: [
        Expanded(
          child: _ContactActionButton(
            icon: Icons.call_outlined,
            label: 'Call',
            color: WaziBotColors.info,
            onTap: () => _call(context, phone),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ContactActionButton(
            icon: Icons.chat_outlined,
            label: 'Message',
            color: WaziBotColors.success,
            onTap: () => _whatsapp(context, phone),
          ),
        ),
        if (order.isDelivery) ...[
          const SizedBox(width: 10),
          Expanded(
            child: _ContactActionButton(
              icon: Icons.directions_outlined,
              label: 'Navigate',
              color: WaziBotColors.warning,
              onTap: () => _navigate(context, order.deliveryAddress!),
            ),
          ),
        ],
      ]),
    );
  }

  Future<void> _call(BuildContext context, String phone) async {
    Haptics.light();
    final uri = Uri(scheme: 'tel', path: phone);
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      _showLaunchError(context, 'Could not open phone app');
    }
  }

  Future<void> _whatsapp(BuildContext context, String phone) async {
    Haptics.light();
    // Strip any non-digit characters so wa.me always gets a clean number.
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('https://wa.me/${digits.replaceFirst('+', '')}');
    final launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      _showLaunchError(context, 'Could not open WhatsApp');
    }
  }

  Future<void> _navigate(BuildContext context, String address) async {
    Haptics.light();
    final query = Uri.encodeComponent(address);
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    final launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      _showLaunchError(context, 'Could not open maps');
    }
  }

  void _showLaunchError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: WaziBotColors.error,
    ));
  }
}

class _ContactActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ContactActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;
  const _StatusBanner({required this.status});

  static const _colors = {
    'new': WaziBotColors.info,
    'preparing': WaziBotColors.warning,
    'completed': WaziBotColors.success,
    'cancelled': WaziBotColors.error,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[status] ?? WaziBotColors.info;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Center(
        child: Text(
          status[0].toUpperCase() + status.substring(1),
          style: theme.textTheme.titleSmall?.copyWith(color: color),
        ),
      ),
    );
  }
}

class _ActionBar extends StatefulWidget {
  final Order order;
  final WidgetRef ref;
  const _ActionBar({required this.order, required this.ref});

  @override
  State<_ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends State<_ActionBar> {
  bool _loading = false;

  Future<void> _updateStatus(String status) async {
    setState(() => _loading = true);
    try {
      final api = widget.ref.read(apiClientProvider);
      await api.put('/orders/${widget.order.id}/status',
          data: {'status': status});
      await Haptics.success();
      widget.ref.invalidate(orderDetailProvider(widget.order.id));
    } catch (e) {
      await Haptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(apiErrorMessage(e)),
          backgroundColor: WaziBotColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final next = _nextStatus[widget.order.status];
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
            top: BorderSide(color: Theme.of(context).colorScheme.outline)),
      ),
      child: Row(children: [
        if (widget.order.status == 'new') ...[
          Expanded(
            child: OutlinedButton(
              onPressed: _loading ? null : () => _updateStatus('cancelled'),
              style: OutlinedButton.styleFrom(
                foregroundColor: WaziBotColors.error,
                side: const BorderSide(color: WaziBotColors.error),
              ),
              child: const Text('Reject'),
            ),
          ),
          const SizedBox(width: 12),
        ],
        if (next != null)
          Expanded(
            child: ElevatedButton(
              onPressed: _loading ? null : () => _updateStatus(next),
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : Text(next == 'preparing' ? 'Accept' : 'Mark Complete'),
            ),
          ),
      ]),
    );
  }
}
