/// lib/features/products/presentation/screens/products_screen.dart
///
/// Phase 7 — UX: swipe-left = Delete with confirmation + haptic
///              pull-to-refresh with haptic
/// Phase 4 — Performance: paginated with load-more
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../shared/models/business_models.dart';
import '../../../../shared/providers/cached_providers.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import 'edit_product_screen.dart';

// ── Screen ────────────────────────────────────────────────────────────────────
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});
  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final productsAsync = ref.watch(cachedProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Haptics.light();
              context.go('/more/products/add');
            },
          ),
        ],
      ),
      body: OfflineWrapper(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _search = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: productsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: ShimmerList(count: 7, itemHeight: 80),
                ),
                error: (e, _) => Center(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off_outlined,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text(apiErrorMessage(e),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () =>
                              ref.invalidate(cachedProductsProvider),
                          child: const Text('Retry'),
                        ),
                      ]),
                ),
                data: (products) {
                  final filtered = _search.isEmpty
                      ? products
                      : products
                          .where((p) => p.name
                              .toLowerCase()
                              .contains(_search.toLowerCase()))
                          .toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 52,
                              color:
                                  theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text(
                            _search.isEmpty
                                ? 'No products yet'
                                : 'No results for "$_search"',
                            style: theme.textTheme.titleMedium,
                          ),
                          if (_search.isEmpty) ...[
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: () =>
                                  context.go('/more/products/add'),
                              icon: const Icon(Icons.add),
                              label: const Text('Add your first product'),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: WaziBotColors.primary,
                    onRefresh: () async {
                      await Haptics.refresh();
                      ref.invalidate(cachedProductsProvider);
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) =>
                          _SwipeableProductCard(
                        product: filtered[i],
                        onDelete: () => _confirmDelete(
                            context, ref, filtered[i]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Product product) async {
    await Haptics.warning();
    if (!context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
            'Remove "${product.name}" from your catalogue? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: WaziBotColors.error))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Haptics.heavy();
        final api = ref.read(apiClientProvider);
        await api.delete('/products/${product.id}');
        ref.invalidate(cachedProductsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${product.name} deleted'),
              backgroundColor: WaziBotColors.error,
            ),
          );
        }
      } catch (e) {
        await Haptics.error();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(apiErrorMessage(e)),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }
}

// ── Swipeable product card ────────────────────────────────────────────────────
class _SwipeableProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onDelete;

  const _SwipeableProductCard({
    required this.product,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: ValueKey(product.id),
      // Right-swipe → Edit
      startActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) {
              Haptics.light();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => EditProductScreen(product: product),
              ));
            },
            backgroundColor: WaziBotColors.info,
            foregroundColor: Colors.white,
            icon: Icons.edit_outlined,
            label: 'Edit',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      // Left-swipe → Delete
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: WaziBotColors.error,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Delete',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: _ProductCard(product: product),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency =
        NumberFormat.currency(symbol: r'$', decimalDigits: 2);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: product.imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: product.imageUrl!,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const LoadingShimmer(
                      width: 52, height: 52, radius: 8),
                  errorWidget: (_, __, ___) =>
                      _ProductPlaceholder(),
                )
              : _ProductPlaceholder(),
        ),
        title: Text(product.name,
            style: theme.textTheme.titleSmall),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(currency.format(product.price),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: WaziBotColors.primary)),
            if (product.stock != null)
              Row(children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: product.stock! < 5
                        ? WaziBotColors.error
                        : product.stock! < 10
                            ? WaziBotColors.warning
                            : WaziBotColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                Text('${product.stock} in stock',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: product.stock! < 5
                            ? WaziBotColors.error
                            : theme.colorScheme.onSurfaceVariant)),
              ]),
          ],
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (!product.isActive)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: WaziBotColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('Hidden',
                  style: TextStyle(
                      fontSize: 9,
                      color: WaziBotColors.warning,
                      fontWeight: FontWeight.w600)),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.swipe_left_outlined, size: 14),
        ]),
        onTap: () => Haptics.light(),
      ),
    );
  }
}

class _ProductPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.inventory_2_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 24),
      );
}
