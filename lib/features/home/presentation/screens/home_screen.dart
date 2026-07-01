/// lib/features/home/presentation/screens/home_screen.dart
///
/// Mirrors the WaziBot web dashboard Overview exactly:
///  Row 1: Total Orders | Revenue | Products | Customers
///  Row 2: Repeat Rate | Satisfaction
///  Row 3: Customer Acquisition funnel (QR→Chat→Orders)
///  Row 4: Business Health checklist
///  Row 5: Quick actions
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../shared/models/business_models.dart';
import '../../../../shared/providers/cached_providers.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../domain/briefing_generator.dart';
import '../../domain/briefing_item.dart';
import '../widgets/briefing_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(cachedProfileProvider);
    final statsAsync = ref.watch(cachedAnalyticsProvider);

    return Scaffold(
      body: RefreshIndicator(
        color: WaziBotColors.primary,
        onRefresh: () async {
          await Haptics.refresh();
          ref.invalidate(cachedProfileProvider);
          ref.invalidate(cachedAnalyticsProvider);
          ref.invalidate(acquisitionProvider);
          ref.invalidate(repeatCustomersProvider);
          ref.invalidate(satisfactionProvider);
          ref.invalidate(healthStatusProvider);
          ref.invalidate(crmSegmentsProvider);
          ref.invalidate(paymentRemindersProvider);
          ref.invalidate(cachedProductsProvider);
          ref.invalidate(cachedOrdersProvider(null));
          ref.invalidate(cachedConversationsProvider(null));
          ref.invalidate(lowStockProductsProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              pinned: false,
              backgroundColor: theme.scaffoldBackgroundColor,
              expandedHeight: 0,
              title: Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: WaziBotColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.smart_toy_outlined,
                      color: Colors.black, size: 18),
                ),
                const SizedBox(width: 10),
                Text('WaziBot',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(color: theme.colorScheme.onSurface)),
              ]),
              actions: [
                IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {}),
                IconButton(
                    icon: const Icon(Icons.person_outline),
                    onPressed: () => context.go(Routes.settings)),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── Today's Business Briefing (NEW — top priority) ─────────
                  Consumer(builder: (_, ref, __) {
                    final data = ref.watch(briefingDataProvider);
                    final isLoading = ref.watch(briefingIsLoadingProvider);

                    final briefingItems = isLoading
                        ? const <BriefingItem>[]
                        : BriefingGenerator.generate(
                            profile: data.profile,
                            stats: data.stats,
                            orders: data.orders,
                            conversations: data.conversations,
                            lowStock: data.lowStock,
                            acquisition: data.acquisition,
                            repeatCustomers: data.repeatCustomers,
                            paymentReminders: data.paymentReminders,
                          );

                    return BriefingCard(
                      greeting:
                          BriefingGenerator.greeting(data.profile?.name),
                      items: briefingItems,
                      closingLine: BriefingGenerator.closingLine(briefingItems),
                      isLoading: isLoading,
                    );
                  }),
                  const SizedBox(height: 20),

                  // ── Business header ───────────────────────────────────────
                  profileAsync.when(
                    loading: () => const LoadingShimmer(height: 80),
                    error: (e, _) => _ErrorCard(message: apiErrorMessage(e)),
                    data: (p) => _BusinessHeader(profile: p),
                  ),

                  // ── Trial warning (< 3 days) ──────────────────────────────
                  profileAsync.whenData((p) {
                    if (!p.isOnTrial) return null;
                    final end = DateTime.tryParse(p.trialEndsAt ?? '');
                    if (end == null) return null;
                    final days = end.difference(DateTime.now()).inDays;
                    if (days > 3) return null;
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _TrialBanner(days: days),
                    );
                  }).valueOrNull ?? const SizedBox.shrink(),

                  const SizedBox(height: 20),

                  // ── Payment reminders badge ───────────────────────────────
                  Consumer(builder: (_, ref, __) {
                    final remAsync = ref.watch(paymentRemindersProvider);
                    return remAsync.whenData((rem) {
                      final count = (rem['count'] as num?)?.toInt() ?? 0;
                      if (count == 0) return null;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RemindersBanner(count: count, ref: ref),
                      );
                    }).valueOrNull ?? const SizedBox.shrink();
                  }),

                  // ── Row 1: Orders | Revenue | Products | Customers ─────────
                  const _SectionLabel('Overview'),
                  const SizedBox(height: 10),
                  statsAsync.when(
                    loading: () => const _GridShimmer(count: 4),
                    error: (e, _) => _ErrorCard(message: apiErrorMessage(e)),
                    data: (data) {
                      final stats = DashboardStats.fromJson(data);
                      final currency = NumberFormat.currency(
                          symbol: r'$', decimalDigits: 0);
                      return Column(children: [
                        Row(children: [
                          Expanded(
                            child: _KpiCard(
                              label: 'TOTAL ORDERS',
                              value: stats.totalOrders.toString(),
                              sub: 'All time',
                              color: WaziBotColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _KpiCard(
                              label: 'REVENUE',
                              value: currency.format(stats.totalRevenue),
                              sub: 'Total USD',
                              color: WaziBotColors.primary,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        // Products + Customers from their own providers
                        Consumer(builder: (_, ref, __) {
                          final prodCount = ref.watch(productCountProvider);
                          final repeatAsync = ref.watch(repeatCustomersProvider);
                          final custCount = repeatAsync.valueOrNull != null
                              ? (repeatAsync.value!['total_customers'] as num?)
                                      ?.toInt() ??
                                  stats.activeCustomers
                              : stats.activeCustomers;
                          return Row(children: [
                            Expanded(
                              child: _KpiCard(
                                label: 'PRODUCTS',
                                value: prodCount.toString(),
                                sub: 'Active items',
                                color: WaziBotColors.info,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _KpiCard(
                                label: 'CUSTOMERS',
                                value: custCount.toString(),
                                sub: 'Unique contacts',
                                color: WaziBotColors.info,
                              ),
                            ),
                          ]);
                        }),
                      ]);
                    },
                  ),
                  const SizedBox(height: 10),

                  // ── Row 2: Repeat Rate | Satisfaction ─────────────────────
                  Consumer(builder: (_, ref, __) {
                    final repeatAsync = ref.watch(repeatCustomersProvider);
                    final satAsync = ref.watch(satisfactionProvider);
                    return Row(children: [
                      Expanded(
                        child: repeatAsync.when(
                          loading: () => const LoadingShimmer(height: 90),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (d) => _RepeatRateCard(data: d),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: satAsync.when(
                          loading: () => const LoadingShimmer(height: 90),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (d) => _SatisfactionCard(data: d),
                        ),
                      ),
                    ]);
                  }),
                  const SizedBox(height: 20),

                  // ── Row 3: Customer Acquisition funnel ─────────────────────
                  const _SectionLabel('Customer Acquisition'),
                  const SizedBox(height: 10),
                  Consumer(builder: (_, ref, __) {
                    final acqAsync = ref.watch(acquisitionProvider);
                    return acqAsync.when(
                      loading: () => const _GridShimmer(count: 4, height: 70),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (d) => _AcquisitionFunnel(data: d),
                    );
                  }),
                  const SizedBox(height: 20),

                  // ── Row 4: Business Health ─────────────────────────────────
                  const _SectionLabel('Business Health'),
                  const SizedBox(height: 10),
                  Consumer(builder: (_, ref, __) {
                    final healthAsync = ref.watch(healthStatusProvider);
                    return healthAsync.when(
                      loading: () => const LoadingShimmer(height: 140),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (d) => _HealthChecklist(data: d),
                    );
                  }),
                  const SizedBox(height: 20),

                  // ── Quick actions ──────────────────────────────────────────
                  const _SectionLabel('Quick Actions'),
                  const SizedBox(height: 10),
                  const _QuickActions(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Business header ───────────────────────────────────────────────────────────
class _BusinessHeader extends StatelessWidget {
  final BusinessProfile profile;
  const _BusinessHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = DateTime.now().hour;
    final greeting = h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            WaziBotColors.primary.withValues(alpha: 0.15),
            WaziBotColors.primary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: WaziBotColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: WaziBotColors.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: WaziBotColors.primary.withValues(alpha: 0.4)),
          ),
          child: const Icon(Icons.store_outlined,
              color: WaziBotColors.primary, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$greeting 👋',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
              Text(profile.name,
                  style: theme.textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Row(children: [
                _PlanBadge(plan: profile.displayPlan,
                    isOnTrial: profile.isOnTrial),
                if (profile.category != null) ...[
                  const SizedBox(width: 8),
                  Text(profile.category!,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  final String plan;
  final bool isOnTrial;
  const _PlanBadge({required this.plan, required this.isOnTrial});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: WaziBotColors.primary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: WaziBotColors.primary.withValues(alpha: 0.4)),
        ),
        child: Text(isOnTrial ? '$plan (Trial)' : plan,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: WaziBotColors.primary)),
      );
}

// ── Trial banner ──────────────────────────────────────────────────────────────
class _TrialBanner extends StatelessWidget {
  final int days;
  const _TrialBanner({required this.days});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: WaziBotColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: WaziBotColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_outlined,
            color: WaziBotColors.error, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            days <= 0
                ? 'Your trial has expired. Upgrade to continue.'
                : 'Trial expires in $days day${days == 1 ? '' : 's'} — upgrade now.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: WaziBotColors.error),
          ),
        ),
      ]),
    );
  }
}

// ── Reminders banner ──────────────────────────────────────────────────────────
class _RemindersBanner extends StatelessWidget {
  final int count;
  final WidgetRef ref;
  const _RemindersBanner({required this.count, required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Haptics.light();
          context.push('/reminders');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: WaziBotColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: WaziBotColors.warning.withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            const Icon(Icons.schedule_outlined,
                color: WaziBotColors.warning, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$count payment${count == 1 ? '' : 's'} awaiting reminder',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: WaziBotColors.warning),
              ),
            ),
            TextButton(
              onPressed: () async {
                Haptics.medium();
                try {
                  final api = ref.read(apiClientProvider);
                  await api.post('/payments/reminders/send?dry_run=false');
                  ref.invalidate(paymentRemindersProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reminders sent ✓')),
                    );
                  }
                } catch (_) {}
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                foregroundColor: WaziBotColors.warning,
              ),
              child: const Text('Send', style: TextStyle(fontSize: 12)),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}

// ── KPI Card (matches web dashboard card style) ───────────────────────────────
class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;
  const _KpiCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: color,
                    height: 1.1)),
            const SizedBox(height: 2),
            Text(sub,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ── Repeat rate card ──────────────────────────────────────────────────────────
class _RepeatRateCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RepeatRateCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rate = (data['repeat_rate_pct'] as num?)?.toDouble() ?? 0;
    final total = (data['total_customers'] as num?)?.toInt() ?? 0;
    final repeat = (data['repeat_customers'] as num?)?.toInt() ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.repeat_rounded,
                  size: 13, color: WaziBotColors.primary),
              const SizedBox(width: 5),
              Text('REPEAT RATE',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: theme.colorScheme.onSurfaceVariant)),
            ]),
            const SizedBox(height: 6),
            Text('${rate.toStringAsFixed(0)}%',
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: WaziBotColors.primary,
                    height: 1.1)),
            const SizedBox(height: 2),
            Text('$repeat of $total customers reordered',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ── Satisfaction card ─────────────────────────────────────────────────────────
class _SatisfactionCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SatisfactionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avg = data['avg_rating'];
    final rated = (data['rated_count'] as num?)?.toInt() ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.star_outline_rounded,
                  size: 13, color: WaziBotColors.warning),
              const SizedBox(width: 5),
              Text('SATISFACTION',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: theme.colorScheme.onSurfaceVariant)),
            ]),
            const SizedBox(height: 6),
            avg != null
                ? Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('$avg',
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: WaziBotColors.warning,
                            height: 1.1)),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4, left: 3),
                      child: Text('/5',
                          style: TextStyle(
                              fontSize: 12, color: WaziBotColors.warning)),
                    ),
                  ])
                : Container(
                    width: 28,
                    height: 3,
                    color: WaziBotColors.primary),
            const SizedBox(height: 2),
            Text(rated == 0 ? 'No ratings yet' : '$rated rating${rated == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ── Acquisition funnel ────────────────────────────────────────────────────────
class _AcquisitionFunnel extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AcquisitionFunnel({required this.data});

  @override
  Widget build(BuildContext context) {
    final today = data['today'] as Map? ?? {};
    final qrTotal = (data['qr_scans'] as num?)?.toInt() ?? 0;
    final clickTotal = (data['whatsapp_clicks'] as num?)?.toInt() ?? 0;
    final convTotal = (data['conversations_started'] as num?)?.toInt() ?? 0;
    final ordersTotal = (data['orders'] as num?)?.toInt() ?? 0;
    final convRate =
        (data['conversion_rate'] as num?)?.toDouble() ?? 0;

    final qrToday = (today['qr_scans'] as num?)?.toInt() ?? 0;
    final clickToday = (today['whatsapp_clicks'] as num?)?.toInt() ?? 0;
    final convToday =
        (today['conversations_started'] as num?)?.toInt() ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('QR → Chat → Orders',
                    style: TextStyle(
                        fontSize: 10,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _FunnelStat(
                    icon: Icons.qr_code_2,
                    label: 'QR SCANS',
                    value: qrTotal,
                    sub: qrToday > 0 ? '+$qrToday today' : '— today'),
                _FunnelArrow(),
                _FunnelStat(
                    icon: Icons.link_rounded,
                    label: 'LINK CLICKS',
                    value: clickTotal,
                    sub: clickToday > 0 ? '+$clickToday today' : '— today'),
                _FunnelArrow(),
                _FunnelStat(
                    icon: Icons.chat_bubble_outline,
                    label: 'CONVERSATIONS',
                    value: convTotal,
                    sub: convToday > 0 ? '+$convToday today' : '— today'),
                _FunnelArrow(),
                _FunnelStat(
                    icon: Icons.receipt_long_outlined,
                    label: 'ORDERS',
                    value: ordersTotal,
                    sub: 'All time'),
                _FunnelArrow(),
                _FunnelStat(
                    icon: Icons.percent_rounded,
                    label: 'CONVERSION',
                    value: null,
                    valueStr: '${convRate.toStringAsFixed(1)}%',
                    sub: 'QR scans → orders'),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _FunnelStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? value;
  final String? valueStr;
  final String sub;

  const _FunnelStat({
    required this.icon,
    required this.label,
    this.value,
    this.valueStr,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 100,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 12, color: WaziBotColors.primary),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: WaziBotColors.textSecondary)),
        ]),
        const SizedBox(height: 4),
        Container(width: 24, height: 2, color: WaziBotColors.primary),
        const SizedBox(height: 4),
        Text(
          valueStr ?? (value?.toString() ?? '—'),
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface),
        ),
        const SizedBox(height: 2),
        Text(sub,
            style: const TextStyle(
                fontSize: 9, color: WaziBotColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

class _FunnelArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(bottom: 16, left: 4, right: 4),
        child: Icon(Icons.chevron_right,
            size: 16, color: WaziBotColors.textMuted),
      );
}

// ── Health checklist (matches web 4/4 All systems go) ────────────────────────
class _HealthChecklist extends StatelessWidget {
  final Map<String, dynamic> data;
  const _HealthChecklist({required this.data});

  static const _labels = {
    'whatsapp': 'WhatsApp Connected',
    'ai': 'AI Engine Active',
    'database': 'Database Connected',
    'payments': 'Payment Method Configured',
    'pending_payments': 'Payment Queue',
    'last_message': 'Message Activity',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overall = data['overall'] as String? ?? 'unknown';
    final checks = data['checks'] as Map<String, dynamic>? ?? {};

    final passed =
        checks.values.where((v) => (v as Map)['status'] == 'green').length;
    final total = checks.length;

    final overallColor = overall == 'green'
        ? WaziBotColors.success
        : overall == 'yellow'
            ? WaziBotColors.warning
            : WaziBotColors.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Score row (matches web "4/4 All systems go!")
            Row(children: [
              Text('$passed/$total',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: overallColor)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(
                    overall == 'green' ? Icons.check_circle : Icons.warning,
                    size: 14,
                    color: overallColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    overall == 'green'
                        ? 'All systems go!'
                        : overall == 'yellow'
                            ? 'Needs attention'
                            : 'Action required',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: overallColor),
                  ),
                ]),
                Text(
                  overall == 'green'
                      ? 'Your AI employee is fully configured.'
                      : 'Check items below for details.',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ]),
            ]),
            const SizedBox(height: 14),
            const Divider(height: 0),
            const SizedBox(height: 10),
            // Check items
            ...checks.entries.map((entry) {
              final key = entry.key;
              final check = entry.value as Map<String, dynamic>;
              final status = check['status'] as String? ?? 'unknown';
              final msg = check['message'] as String? ?? '';
              final color = status == 'green'
                  ? WaziBotColors.success
                  : status == 'yellow'
                      ? WaziBotColors.warning
                      : WaziBotColors.error;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      status == 'green'
                          ? Icons.check_rounded
                          : status == 'yellow'
                              ? Icons.remove_rounded
                              : Icons.close_rounded,
                      size: 14,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(_labels[key] ?? key,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      if (status != 'green' && msg.isNotEmpty)
                        Text(msg,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: color, fontSize: 10)),
                    ]),
                  ),
                ]),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleSmall),
        ),
      ]);
}

// ── Quick actions ─────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QA(Icons.receipt_long_outlined, 'Orders', WaziBotColors.info,
          () => context.go(Routes.orders)),
      _QA(Icons.inbox_outlined, 'Inbox', WaziBotColors.primary,
          () => context.go(Routes.inbox)),
      _QA(Icons.qr_code_scanner, 'Scan QR', const Color(0xFF8B5CF6),
          () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ScannerPlaceholder(),
              ))),
      _QA(Icons.inventory_2_outlined, 'Products', WaziBotColors.warning,
          () => context.go(Routes.products)),
      _QA(Icons.analytics_outlined, 'Analytics', WaziBotColors.error,
          () => context.go(Routes.analytics)),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: actions.map((a) => _QuickActionButton(qa: a)).toList(),
    );
  }
}

class _QA {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QA(this.icon, this.label, this.color, this.onTap);
}

class _QuickActionButton extends StatelessWidget {
  final _QA qa;
  const _QuickActionButton({required this.qa});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = (MediaQuery.of(context).size.width - 52) / 3;
    return GestureDetector(
      onTap: () {
        Haptics.light();
        qa.onTap();
      },
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: qa.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(qa.icon, color: qa.color, size: 19),
          ),
          const SizedBox(height: 7),
          Text(qa.label,
              style: theme.textTheme.labelMedium,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

// ── Shimmer helpers ───────────────────────────────────────────────────────────
class _GridShimmer extends StatelessWidget {
  final int count;
  final double height;
  const _GridShimmer({required this.count, this.height = 85});

  @override
  Widget build(BuildContext context) => Row(
        children: List.generate(count, (i) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 10),
                child: LoadingShimmer(height: height),
              ),
            )),
      );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(Icons.error_outline, color: theme.colorScheme.error, size: 16),
        const SizedBox(width: 8),
        Expanded(
            child: Text(message,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer))),
      ]),
    );
  }
}

// ── Scanner placeholder (avoids circular import) ──────────────────────────────
class ScannerPlaceholder extends StatelessWidget {
  const ScannerPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Scan QR')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.qr_code_scanner, size: 60),
            const SizedBox(height: 12),
            const Text('QR Scanner'),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close')),
          ]),
        ),
      );
}
