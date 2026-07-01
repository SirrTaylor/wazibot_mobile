/// lib/features/customers/presentation/screens/customer_profile_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/business_models.dart';

// ── Models ────────────────────────────────────────────────────────────────────
class CustomerProfile {
  final String id;
  final String phone;
  final String? name;
  final String? email;
  final int totalOrders;
  final double totalSpent;
  final String? lastOrderAt;
  final String? firstSeenAt;
  final String? segment;
  final List<Order> recentOrders;

  const CustomerProfile({
    required this.id,
    required this.phone,
    this.name,
    this.email,
    this.totalOrders = 0,
    this.totalSpent = 0,
    this.lastOrderAt,
    this.firstSeenAt,
    this.segment,
    this.recentOrders = const [],
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) =>
      CustomerProfile(
        id: json['id']?.toString() ?? '',
        phone: json['phone'] as String? ?? '',
        name: json['name'] as String?,
        email: json['email'] as String?,
        totalOrders: json['total_orders'] as int? ?? 0,
        totalSpent:
            (json['total_spent'] as num?)?.toDouble() ?? 0,
        lastOrderAt: json['last_order_at'] as String?,
        firstSeenAt: json['first_seen_at'] as String?,
        segment: json['segment'] as String?,
        recentOrders: (json['recent_orders'] as List<dynamic>?)
                ?.map((e) =>
                    Order.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

// ── Provider ──────────────────────────────────────────────────────────────────
final customerProfileProvider =
    FutureProvider.family<CustomerProfile, String>((ref, phone) async {
  final api = ref.watch(apiClientProvider);
  // Try dedicated endpoint first, fall back to constructing from conversations
  try {
    final resp = await api.get('/customers/by-phone/$phone');
    return CustomerProfile.fromJson(
        resp.data as Map<String, dynamic>);
  } catch (_) {
    // Fallback: get from conversations endpoint
    final resp = await api.get('/chat/conversations/$phone');
    final data = resp.data as Map<String, dynamic>? ?? {};
    return CustomerProfile(
      id: data['customer_id']?.toString() ?? phone,
      phone: phone,
      name: data['customer_name'] as String?,
    );
  }
});

// ── Screen ────────────────────────────────────────────────────────────────────
class CustomerProfileScreen extends ConsumerWidget {
  final String phone;
  const CustomerProfileScreen({super.key, required this.phone});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(customerProfileProvider(phone));

    return Scaffold(
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(phone: phone),
        data: (profile) => CustomScrollView(
          slivers: [
            // ── Hero app bar ────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        WaziBotColors.primary.withValues(alpha: 0.2),
                        theme.scaffoldBackgroundColor,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      CircleAvatar(
                        radius: 36,
                        backgroundColor:
                            WaziBotColors.primary.withValues(alpha: 0.2),
                        child: Text(
                          _initial(profile.name ?? profile.phone),
                          style: theme.textTheme.headlineMedium
                              ?.copyWith(color: WaziBotColors.primary),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        profile.name ?? profile.phone,
                        style: theme.textTheme.titleLarge,
                      ),
                      if (profile.name != null)
                        Text(profile.phone,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    theme.colorScheme.onSurfaceVariant)),
                      if (profile.segment != null)
                        const SizedBox(height: 6),
                      if (profile.segment != null)
                        _SegmentBadge(segment: profile.segment!),
                    ],
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.chat_outlined),
                  tooltip: 'Open conversation',
                  onPressed: () =>
                      context.go('/inbox/${profile.phone}'),
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Stats row ─────────────────────────────────────────────
                  Row(children: [
                    _StatBox(
                      label: 'Orders',
                      value: profile.totalOrders.toString(),
                      icon: Icons.receipt_long_outlined,
                      color: WaziBotColors.info,
                    ),
                    const SizedBox(width: 10),
                    _StatBox(
                      label: 'Total Spent',
                      value: NumberFormat.currency(
                              symbol: r'$', decimalDigits: 0)
                          .format(profile.totalSpent),
                      icon: Icons.attach_money,
                      color: WaziBotColors.primary,
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // ── Contact details ───────────────────────────────────────
                  _Section(
                    title: 'Contact',
                    child: Column(children: [
                      _InfoRow(
                          icon: Icons.phone_outlined,
                          label: 'Phone',
                          value: profile.phone),
                      if (profile.email != null) ...[
                        const Divider(height: 12),
                        _InfoRow(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: profile.email!),
                      ],
                      if (profile.firstSeenAt != null) ...[
                        const Divider(height: 12),
                        _InfoRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'First seen',
                            value: _formatDate(profile.firstSeenAt)),
                      ],
                      if (profile.lastOrderAt != null) ...[
                        const Divider(height: 12),
                        _InfoRow(
                            icon: Icons.schedule_outlined,
                            label: 'Last order',
                            value: _formatDate(profile.lastOrderAt)),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // ── Recent orders ─────────────────────────────────────────
                  if (profile.recentOrders.isNotEmpty) ...[
                    _Section(
                      title: 'Recent Orders',
                      child: Column(
                        children: profile.recentOrders
                            .take(5)
                            .map((order) => _OrderRow(
                                order: order))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Actions ───────────────────────────────────────────────
                  ElevatedButton.icon(
                    onPressed: () =>
                        context.go('/inbox/${profile.phone}'),
                    icon: const Icon(Icons.chat_outlined,
                        color: Colors.black, size: 18),
                    label: const Text('Open Conversation'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.go('/orders?phone=${profile.phone}'),
                    icon: const Icon(Icons.receipt_long_outlined,
                        size: 18),
                    label: const Text('View All Orders'),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initial(String s) => s.isNotEmpty ? s[0].toUpperCase() : '?';

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat.yMMMd().format(dt.toLocal());
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 8),
              Text(value,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text(label,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
              padding: const EdgeInsets.all(14), child: child),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(children: [
      Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant)),
        Text(value, style: theme.textTheme.bodyMedium),
      ]),
    ]);
  }
}

class _OrderRow extends StatelessWidget {
  final Order order;
  const _OrderRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency =
        NumberFormat.currency(symbol: r'$', decimalDigits: 2);
    final shortId = order.id.length > 8
        ? order.id.substring(0, 8)
        : order.id;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('#$shortId',
                  style: theme.textTheme.titleSmall),
              Text(
                  '${order.items.length} item${order.items.length == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(currency.format(order.total),
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: WaziBotColors.primary)),
          _StatusDot(status: order.status),
        ]),
      ]),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final String status;
  const _StatusDot({required this.status});

  static const _colors = {
    'new': WaziBotColors.info,
    'preparing': WaziBotColors.warning,
    'completed': WaziBotColors.success,
    'cancelled': WaziBotColors.error,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[status] ?? WaziBotColors.info;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(status[0].toUpperCase() + status.substring(1),
          style: TextStyle(fontSize: 10, color: color)),
    ]);
  }
}

class _SegmentBadge extends StatelessWidget {
  final String segment;
  const _SegmentBadge({required this.segment});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: WaziBotColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: WaziBotColors.primary.withValues(alpha: 0.4)),
        ),
        child: Text(
          segment,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: WaziBotColors.primary,
          ),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String phone;
  const _ErrorView({required this.phone});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(phone)),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.person_off_outlined,
              size: 52, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('Customer not found',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.go('/inbox/$phone'),
            child: const Text('Open Conversation'),
          ),
        ]),
      ),
    );
  }
}
