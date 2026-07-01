/// lib/core/router/app_router.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../shared/widgets/main_shell.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/inbox/presentation/screens/inbox_screen.dart';
import '../../features/inbox/presentation/screens/conversation_screen.dart';
import '../../features/orders/presentation/screens/orders_screen.dart';
import '../../features/orders/presentation/screens/order_detail_screen.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/products/presentation/screens/products_screen.dart';
import '../../features/products/presentation/screens/add_product_screen.dart';
import '../../features/qr/presentation/screens/qr_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/scanner/presentation/screens/scanner_screen.dart';
import '../../features/customers/presentation/screens/customer_profile_screen.dart';
import '../../features/reminders/presentation/screens/reminders_screen.dart';
import '../auth/auth_service.dart';

class Routes {
  static const splash = '/';
  static const login = '/login';
  static const home = '/home';
  static const inbox = '/inbox';
  static const orders = '/orders';
  static const analytics = '/analytics';
  static const more = '/more';
  static const products = '/more/products';
  static const addProduct = '/more/products/add';
  static const qr = '/more/qr';
  static const settings = '/more/settings';
  static const scanner = '/scanner';
  static const customerProfile = '/customer/:phone';
  static const reminders = '/reminders';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: _AuthStateListenable(ref),
    redirect: (context, state) {
      final authData = authState.valueOrNull;
      if (authState.isLoading) return null;
      final isAuthenticated = authData?.status == AuthStatus.authenticated;
      final isOnAuth = state.matchedLocation == Routes.login ||
          state.matchedLocation == Routes.splash;
      if (!isAuthenticated && !isOnAuth) return Routes.login;
      if (isAuthenticated && isOnAuth) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),

      // Full-screen routes outside the shell (no bottom nav)
      GoRoute(
        path: Routes.scanner,
        builder: (_, __) => ScannerScreen(
          onScanned: (value) {
            // Handle scanned QR — navigate based on content
            // Most WaziBot QRs are store URLs, customer phones, or order IDs
          },
        ),
      ),
      GoRoute(
        path: '/customer/:phone',
        builder: (_, state) => CustomerProfileScreen(
          phone: state.pathParameters['phone']!,
        ),
      ),
      GoRoute(
        path: Routes.reminders,
        builder: (_, __) => const RemindersScreen(),
      ),

      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: Routes.inbox,
            builder: (_, __) => const InboxScreen(),
            routes: [
              GoRoute(
                path: ':phone',
                builder: (_, state) => ConversationScreen(
                  phone: state.pathParameters['phone']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: Routes.orders,
            builder: (_, __) => const OrdersScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => OrderDetailScreen(
                  orderId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
              path: Routes.analytics,
              builder: (_, __) => const AnalyticsScreen()),
          GoRoute(
            path: Routes.more,
            builder: (_, __) => const MoreScreen(),
            routes: [
              GoRoute(
                path: 'products',
                builder: (_, __) => const ProductsScreen(),
                routes: [
                  GoRoute(
                      path: 'add',
                      builder: (_, __) => const AddProductScreen()),
                ],
              ),
              GoRoute(path: 'qr', builder: (_, __) => const QrScreen()),
              GoRoute(
                  path: 'settings',
                  builder: (_, __) => const SettingsScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});

class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(Ref ref) {
    ref.listen(authNotifierProvider, (_, __) => notifyListeners());
  }
}

// ── More screen ───────────────────────────────────────────────────────────────
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MoreTile(
            icon: Icons.inventory_2_outlined,
            label: 'Products',
            subtitle: 'Manage your catalogue',
            onTap: () => context.go(Routes.products),
          ),
          const SizedBox(height: 8),
          _MoreTile(
            icon: Icons.qr_code_2,
            label: 'QR Code',
            subtitle: 'Generate, share and download your QR',
            onTap: () => context.go(Routes.qr),
          ),
          const SizedBox(height: 8),
          _MoreTile(
            icon: Icons.qr_code_scanner,
            label: 'Scan QR',
            subtitle: 'Scan a customer or product QR code',
            onTap: () => context.push(Routes.scanner),
          ),
          const SizedBox(height: 8),
          _MoreTile(
            icon: Icons.settings_outlined,
            label: 'Settings',
            subtitle: 'Profile, theme, notifications',
            onTap: () => context.go(Routes.settings),
          ),
          const SizedBox(height: 24),

          // Web Dashboard redirect card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.15),
                  theme.colorScheme.primary.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.open_in_browser,
                      color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('Advanced Tools',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: theme.colorScheme.primary)),
                ]),
                const SizedBox(height: 6),
                Text(
                  'Campaign builder, website editor, automations, bulk import, '
                  'API keys and more are available on the desktop dashboard.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.launch, size: 16),
                  label: const Text('Open Web Dashboard'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 40)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _MoreTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 22),
        ),
        title: Text(label, style: theme.textTheme.titleMedium),
        subtitle: Text(subtitle,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        trailing: Icon(Icons.chevron_right,
            color: theme.colorScheme.onSurfaceVariant),
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }
}
