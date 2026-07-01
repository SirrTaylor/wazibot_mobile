/// lib/core/connectivity/connectivity_service.dart
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Provider ──────────────────────────────────────────────────────────────────
final connectivityProvider =
    StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

final isOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.when(
    data: (results) => results.any((r) => r != ConnectivityResult.none),
    loading: () => true, // assume online while loading
    error: (_, __) => true,
  );
});

// ── Offline Banner Widget ─────────────────────────────────────────────────────
/// Wrap any screen body with this to show an offline indicator.
/// Usage:
///   body: OfflineWrapper(child: MyScreen()),
class OfflineWrapper extends ConsumerWidget {
  final Widget child;
  const OfflineWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: isOnline ? 0 : 32,
          color: const Color(0xFFF59E0B),
          child: isOnline
              ? null
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, size: 14, color: Colors.black),
                    SizedBox(width: 6),
                    Text(
                      'You\'re offline — showing cached data',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// Snackbar helper for one-shot connectivity events
void showOfflineSnackBar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Row(children: [
        Icon(Icons.wifi_off, size: 16, color: Colors.white),
        SizedBox(width: 8),
        Text('No internet connection'),
      ]),
      backgroundColor: Color(0xFFF59E0B),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 3),
    ),
  );
}
