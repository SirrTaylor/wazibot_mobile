/// lib/shared/widgets/main_shell.dart
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    _Tab(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home', path: '/home'),
    _Tab(icon: Icons.inbox_outlined, activeIcon: Icons.inbox, label: 'Inbox', path: '/inbox'),
    _Tab(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'Orders', path: '/orders'),
    _Tab(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, label: 'Analytics', path: '/analytics'),
    _Tab(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view, label: 'More', path: '/more'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentIndex = _currentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outline,
              width: 0.5,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (i) => context.go(_tabs[i].path),
          destinations: _tabs
              .map((t) => NavigationDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.activeIcon),
                    label: t.label,
                  ))
              .toList(),
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
      ),
    );
  }
}

class _Tab {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;

  const _Tab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });
}
