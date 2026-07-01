/// lib/features/orders/presentation/screens/orders_screen.dart
///
/// Phase 4 — Performance: paginated list (20 items/page) with load-more
/// Phase 7 — UX: swipe-left=Accept, swipe-right=Reject with haptic feedback
///              pull-to-refresh with haptic
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../shared/models/business_models.dart';
import '../../../../core/cache/cache_service.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../../shared/providers/cached_providers.dart';
import '../../../../shared/widgets/loading_shimmer.dart';

// ── Pagination constants ──────────────────────────────────────────────────────
const int _kPageSize = 20;

// ── Status config ─────────────────────────────────────────────────────────────
const _statuses = ['all', 'new', 'preparing', 'completed', 'cancelled'];

const _statusColors = {
  'new': WaziBotColors.info,
  'preparing': WaziBotColors.warning,
  'completed': WaziBotColors.success,
  'cancelled': WaziBotColors.error,
};

const _statusLabels = {
  'all': 'All',
  'new': 'New',
  'preparing': 'Preparing',
  'completed': 'Done',
  'cancelled': 'Cancelled',
};

// ── Paginated orders state ────────────────────────────────────────────────────
class PaginatedOrdersState {
  final List<Order> orders;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final int page;

  const PaginatedOrdersState({
    this.orders = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.page = 0,
  });

  PaginatedOrdersState copyWith({
    List<Order>? orders,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    int? page,
  }) =>
      PaginatedOrdersState(
        orders: orders ?? this.orders,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        error: error,
        page: page ?? this.page,
      );
}

class PaginatedOrdersNotifier
    extends FamilyNotifier<PaginatedOrdersState, String?> {
  @override
  PaginatedOrdersState build(String? status) {
    // Auto-load on init
    Future.microtask(loadInitial);
    return const PaginatedOrdersState(isLoading: true);
  }

  Future<void> loadInitial() async {
    state = const PaginatedOrdersState(isLoading: true);
    try {
      final api = ref.read(apiClientProvider);
      final params = <String, dynamic>{
        'limit': _kPageSize,
        'offset': 0,
        if (arg != null && arg != 'all') 'status': arg,
      };
      final resp = await api.get('/orders', params: params);
      final list = _extractList(resp.data);
      // Also update shared cache
      final cache = ref.read(cacheServiceProvider);
      await cache.set(
          'orders_${arg ?? 'all'}', list,
          ttl: const Duration(minutes: 5));
      state = PaginatedOrdersState(
        orders: list.map(_parseOrder).toList(),
        isLoading: false,
        hasMore: list.length == _kPageSize,
        page: 1,
      );
    } catch (e) {
      // Try stale cache on error
      final cache = ref.read(cacheServiceProvider);
      final stale = cache.getStale('orders_${arg ?? 'all'}');
      if (stale != null) {
        final list = stale as List<dynamic>;
        state = PaginatedOrdersState(
          orders: list
              .map((e) =>
                  Order.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList(),
          isLoading: false,
          hasMore: false,
          error: 'Showing cached data',
        );
      } else {
        state = PaginatedOrdersState(
            isLoading: false, error: e.toString());
      }
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final api = ref.read(apiClientProvider);
      final params = <String, dynamic>{
        'limit': _kPageSize,
        'offset': state.page * _kPageSize,
        if (arg != null && arg != 'all') 'status': arg,
      };
      final resp = await api.get('/orders', params: params);
      final list = _extractList(resp.data);
      state = state.copyWith(
        orders: [...state.orders, ...list.map(_parseOrder)],
        isLoadingMore: false,
        hasMore: list.length == _kPageSize,
        page: state.page + 1,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> refresh() async {
    await Haptics.refresh();
    await loadInitial();
  }

  Future<void> updateStatus(String orderId, String newStatus) async {
    // Use write queue so status updates work offline
    final write = QueuedWrite(
      id: 'order_status_${orderId}_${DateTime.now().millisecondsSinceEpoch}',
      method: 'PUT',
      path: '/orders/$orderId/status',
      body: {'status': newStatus},
      createdAt: DateTime.now(),
    );
    await ref.read(syncProvider.notifier).enqueueWrite(write);
    // Optimistic update in list
    state = state.copyWith(
      orders: state.orders.map<Order>((o) {
        if (o.id == orderId) {
          return Order(
            id: o.id,
            customerId: o.customerId,
            status: newStatus,
            rawStatus: newStatus, // required field added
            total: o.total,
            createdAt: o.createdAt,
            customerName: o.customerName,
            customerPhone: o.customerPhone,
            currency: o.currency,
            notes: o.notes,
            items: o.items,
            fulfillmentMethod: o.fulfillmentMethod,
            deliveryAddress: o.deliveryAddress,
          );
        }
        return o;
      }).toList(), // typed correctly — map returns Iterable<Order>
    );
  }

  static List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) return data['orders'] as List<dynamic>? ?? [];
    return [];
  }

  static Order _parseOrder(dynamic e) =>
      Order.fromJson(Map<String, dynamic>.from(e as Map));
}

final paginatedOrdersProvider = NotifierProviderFamily<
    PaginatedOrdersNotifier, PaginatedOrdersState, String?>(
  PaginatedOrdersNotifier.new,
);

// ── Screen ────────────────────────────────────────────────────────────────────
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});
  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _statuses.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) Haptics.selection();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          Consumer(builder: (_, ref, __) {
            final remAsync = ref.watch(paymentRemindersProvider);
            final count = remAsync.valueOrNull?['count'] as int? ?? 0;
            return IconButton(
              tooltip: 'Payment reminders',
              icon: Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                backgroundColor: WaziBotColors.warning,
                child: const Icon(Icons.schedule_outlined),
              ),
              onPressed: () {
                Haptics.light();
                context.push('/reminders');
              },
            );
          }),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _statuses
              .map((s) => Tab(text: _statusLabels[s]))
              .toList(),
        ),
      ),
      body: OfflineWrapper(
        child: TabBarView(
          controller: _tabCtrl,
          children: _statuses
              .map((s) => _OrdersTab(
                  status: s == 'all' ? null : s))
              .toList(),
        ),
      ),
    );
  }
}

// ── Tab content with pagination ───────────────────────────────────────────────
class _OrdersTab extends ConsumerStatefulWidget {
  final String? status;
  const _OrdersTab({this.status});

  @override
  ConsumerState<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends ConsumerState<_OrdersTab> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      ref
          .read(paginatedOrdersProvider(widget.status).notifier)
          .loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(paginatedOrdersProvider(widget.status));

    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: ShimmerList(count: 6, itemHeight: 90),
      );
    }

    if (state.orders.isEmpty && state.error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline,
              size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(state.error!,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => ref
                .read(paginatedOrdersProvider(widget.status)
                    .notifier)
                .loadInitial(),
            child: const Text('Retry'),
          ),
        ]),
      );
    }

    if (state.orders.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.receipt_long_outlined,
              size: 52,
              color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('No orders',
              style: theme.textTheme.titleMedium),
          if (widget.status != null)
            Text('No ${widget.status} orders yet',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
        ]),
      );
    }

    return RefreshIndicator(
      color: WaziBotColors.primary,
      onRefresh: () => ref
          .read(paginatedOrdersProvider(widget.status).notifier)
          .refresh(),
      child: ListView.separated(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(12),
        itemCount: state.orders.length + (state.isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          if (i == state.orders.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                    color: WaziBotColors.primary, strokeWidth: 2),
              ),
            );
          }
          return _SwipeableOrderCard(
            order: state.orders[i],
            onStatusChange: (newStatus) => ref
                .read(paginatedOrdersProvider(widget.status)
                    .notifier)
                .updateStatus(state.orders[i].id, newStatus),
          );
        },
      ),
    );
  }
}

// ── Swipeable order card ──────────────────────────────────────────────────────
class _SwipeableOrderCard extends StatelessWidget {
  final Order order;
  final Future<void> Function(String status) onStatusChange;

  const _SwipeableOrderCard({
    required this.order,
    required this.onStatusChange,
  });

  bool get _canAccept => order.status == 'new';
  bool get _canComplete => order.status == 'preparing';
  bool get _canReject =>
      order.status == 'new' || order.status == 'preparing';

  @override
  Widget build(BuildContext context) {
    // Only swipeable for actionable statuses
    if (!_canAccept && !_canComplete && !_canReject) {
      return _OrderCard(order: order);
    }

    return Slidable(
      key: ValueKey(order.id),
      // Left swipe → positive action (Accept / Complete)
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.28,
        children: [
          if (_canAccept)
            SlidableAction(
              onPressed: (_) async {
                await Haptics.success();
                await onStatusChange('preparing');
              },
              backgroundColor: WaziBotColors.success,
              foregroundColor: Colors.black,
              icon: Icons.check_rounded,
              label: 'Accept',
              borderRadius: BorderRadius.circular(12),
            ),
          if (_canComplete)
            SlidableAction(
              onPressed: (_) async {
                await Haptics.success();
                await onStatusChange('completed');
              },
              backgroundColor: WaziBotColors.success,
              foregroundColor: Colors.black,
              icon: Icons.done_all_rounded,
              label: 'Done',
              borderRadius: BorderRadius.circular(12),
            ),
        ],
      ),
      // Right swipe → destructive (Reject / Cancel)
      startActionPane: _canReject
          ? ActionPane(
              motion: const BehindMotion(),
              extentRatio: 0.28,
              children: [
                SlidableAction(
                  onPressed: (_) async {
                    await Haptics.error();
                    await onStatusChange('cancelled');
                  },
                  backgroundColor: WaziBotColors.error,
                  foregroundColor: Colors.white,
                  icon: Icons.close_rounded,
                  label: 'Reject',
                  borderRadius: BorderRadius.circular(12),
                ),
              ],
            )
          : null,
      child: _OrderCard(order: order),
    );
  }
}

// ── Order card ────────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _statusColors[order.status] ?? WaziBotColors.info;
    final currency =
        NumberFormat.currency(symbol: r'$', decimalDigits: 2);
    final shortId =
        order.id.length > 8 ? order.id.substring(0, 8) : order.id;

    return Card(
      child: InkWell(
        onTap: () {
          Haptics.light();
          context.go('/orders/${order.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('#$shortId',
                      style: theme.textTheme.titleSmall),
                  _StatusChip(status: order.status, color: color),
                ],
              ),
              const SizedBox(height: 8),
              if (order.customerName != null ||
                  order.customerPhone != null)
                Row(children: [
                  Icon(Icons.person_outline,
                      size: 13,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                      order.customerName ??
                          order.customerPhone ??
                          '',
                      style: theme.textTheme.bodySmall),
                ]),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.items.length} item${order.items.length == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(currency.format(order.total),
                      style: theme.textTheme.titleSmall?.copyWith(
                          color: WaziBotColors.primary)),
                ],
              ),
              // Swipe hint for actionable orders
              if (order.status == 'new' ||
                  order.status == 'preparing') ...[
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.swipe,
                      size: 11,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text('Swipe to act',
                      style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5))),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusChip({required this.status, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          status[0].toUpperCase() + status.substring(1),
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color),
        ),
      );
}
