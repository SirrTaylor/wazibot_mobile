/// lib/core/sync/sync_engine.dart
///
/// Full data sync layer for WaziBot Mobile.
///
/// Responsibilities:
///  1. SyncQueue     — queues writes (order status, messages) when offline,
///                     replays them automatically when connectivity returns
///  2. BackgroundPoller — periodic re-fetch of all data while app is active
///  3. SyncNotifier  — Riverpod state for "last synced", "syncing", error
///
/// All sync is tenant-isolated: every request is JWT-authenticated
/// (the ApiClient adds the Bearer token automatically).
library;

import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../cache/cache_service.dart';

// ── Write-queue item ──────────────────────────────────────────────────────────
class QueuedWrite {
  final String id;          // UUID for deduplication
  final String method;      // 'PUT' | 'POST' | 'PATCH' | 'DELETE'
  final String path;        // e.g. '/orders/42/status'
  final Map<String, dynamic>? body;
  final DateTime createdAt;
  int retries;

  QueuedWrite({
    required this.id,
    required this.method,
    required this.path,
    this.body,
    required this.createdAt,
    this.retries = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'path': path,
        'body': body,
        'created_at': createdAt.toIso8601String(),
        'retries': retries,
      };

  factory QueuedWrite.fromJson(Map<String, dynamic> json) => QueuedWrite(
        id: json['id'] as String,
        method: json['method'] as String,
        path: json['path'] as String,
        body: json['body'] as Map<String, dynamic>?,
        createdAt: DateTime.parse(json['created_at'] as String),
        retries: json['retries'] as int? ?? 0,
      );
}

// ── Sync state ────────────────────────────────────────────────────────────────
class SyncState {
  final bool isSyncing;
  final DateTime? lastSyncedAt;
  final String? error;
  final int pendingWrites;
  final bool isOnline;

  const SyncState({
    this.isSyncing = false,
    this.lastSyncedAt,
    this.error,
    this.pendingWrites = 0,
    this.isOnline = true,
  });

  SyncState copyWith({
    bool? isSyncing,
    DateTime? lastSyncedAt,
    String? error,
    int? pendingWrites,
    bool? isOnline,
  }) =>
      SyncState(
        isSyncing: isSyncing ?? this.isSyncing,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        error: error,
        pendingWrites: pendingWrites ?? this.pendingWrites,
        isOnline: isOnline ?? this.isOnline,
      );

  String get statusLabel {
    if (!isOnline) return 'Offline';
    if (pendingWrites > 0) return '$pendingWrites pending';
    if (isSyncing) return 'Syncing…';
    if (lastSyncedAt == null) return 'Not synced';
    final diff = DateTime.now().difference(lastSyncedAt!);
    if (diff.inSeconds < 30) return 'Just synced';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

// ── Sync notifier ─────────────────────────────────────────────────────────────
class SyncNotifier extends StateNotifier<SyncState> {
  final ApiClient _api;
  final CacheService _cache;
  final SharedPreferences _prefs;

  static const String _queueKey = 'wazibot_write_queue';
  static const Duration _pollInterval = Duration(minutes: 2);
  static const int _maxRetries = 5;

  Timer? _pollTimer;
  StreamSubscription? _connectivitySub;
  bool _wasOffline = false;

  SyncNotifier(this._api, this._cache, this._prefs)
      : super(const SyncState()) {
    _init();
  }

  void _init() {
    // Subscribe directly to the platform connectivity stream (rather than
    // going through Riverpod's connectivityProvider) since this notifier
    // needs to react to changes outside the widget tree's build cycle.
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      state = state.copyWith(isOnline: online);

      if (online && _wasOffline) {
        // Just came back online — replay queue + full sync
        debugPrint('SyncEngine: back online, replaying queue');
        _replayQueue();
        syncAll();
      }
      _wasOffline = !online;
    });

    // Start background poll
    _startPolling();

    // Immediate first sync
    syncAll();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (state.isOnline && !state.isSyncing) syncAll();
    });
  }

  // ── Full sync ───────────────────────────────────────────────────────────────
  Future<void> syncAll() async {
    if (state.isSyncing) return;
    state = state.copyWith(isSyncing: true, error: null);

    try {
      await Future.wait([
        _syncProfile(),
        _syncStats(),
        _syncOrders(),
        _syncProducts(),
        _syncConversations(),
        _syncLowStock(),
        _syncAcquisition(),
        _syncRepeatCustomers(),
        _syncSatisfaction(),
        _syncHealthStatus(),
        _syncCrmSegments(),
        _syncPaymentReminders(),
      ], eagerError: false);

      state = state.copyWith(
        isSyncing: false,
        lastSyncedAt: DateTime.now(),
        pendingWrites: _loadQueue().length,
      );
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        error: apiErrorMessage(e),
      );
    }
  }

  // ── Individual sync tasks ────────────────────────────────────────────────
  Future<void> _syncProfile() async {
    try {
      final resp = await _api.get('/me');
      await _cache.set(CacheService.kProfile, resp.data,
          ttl: CacheService.ttlLong);
    } catch (_) {}
  }

  Future<void> _syncStats() async {
    try {
      final resp = await _api.get('/analytics/stats');
      await _cache.set(CacheService.kAnalytics, resp.data,
          ttl: CacheService.ttlShort);
    } catch (_) {}
  }

  Future<void> _syncOrders() async {
    try {
      // Sync all statuses
      final resp = await _api.get('/orders');
      final list = resp.data is List
          ? resp.data as List
          : (resp.data['orders'] as List? ?? []);
      await _cache.set(CacheService.kOrders, list,
          ttl: CacheService.ttlShort);
      // Also cache by status for tab views
      final byStatus = <String, List>{};
      for (final o in list) {
        final s = o['status'] as String? ?? 'pending';
        byStatus.putIfAbsent(s, () => []).add(o);
      }
      for (final entry in byStatus.entries) {
        await _cache.set('${CacheService.kOrders}_${entry.key}',
            entry.value, ttl: CacheService.ttlShort);
      }
    } catch (_) {}
  }

  Future<void> _syncProducts() async {
    try {
      final resp = await _api.get('/products');
      await _cache.set(CacheService.kProducts, resp.data,
          ttl: CacheService.ttlMedium);
    } catch (_) {}
  }

  Future<void> _syncConversations() async {
    try {
      final resp = await _api.get('/chat/conversations');
      final list = resp.data as List? ?? [];
      await _cache.set(CacheService.kConversations, list,
          ttl: CacheService.ttlShort);
      // Also mark unread count in cache
      final unread = list.where((c) =>
          ((c['unread_count'] as num?)?.toInt() ?? 0) > 0).length;
      await _cache.set('inbox_unread_count', unread,
          ttl: CacheService.ttlShort);
    } catch (_) {}
  }

  Future<void> _syncLowStock() async {
    try {
      final resp = await _api.get('/analytics/low-stock');
      await _cache.set('low_stock', resp.data,
          ttl: CacheService.ttlMedium);
    } catch (_) {}
  }

  /// Web dashboard overview — Customer Acquisition funnel
  Future<void> _syncAcquisition() async {
    try {
      final resp = await _api.get('/analytics/acquisition');
      await _cache.set('acquisition', resp.data,
          ttl: CacheService.ttlShort);
    } catch (_) {}
  }

  /// Web dashboard overview — Repeat Rate card
  Future<void> _syncRepeatCustomers() async {
    try {
      final resp = await _api.get('/analytics/repeat-customers');
      await _cache.set('repeat_customers', resp.data,
          ttl: CacheService.ttlMedium);
    } catch (_) {}
  }

  /// Web dashboard overview — Satisfaction card
  Future<void> _syncSatisfaction() async {
    try {
      final resp = await _api.get('/analytics/satisfaction');
      await _cache.set('satisfaction', resp.data,
          ttl: CacheService.ttlMedium);
    } catch (_) {}
  }

  /// Web dashboard overview — Business Health checklist
  Future<void> _syncHealthStatus() async {
    try {
      final resp = await _api.get('/health/status');
      await _cache.set('health_status', resp.data,
          ttl: CacheService.ttlShort);
    } catch (_) {}
  }

  /// CRM segments — used by customer screens
  Future<void> _syncCrmSegments() async {
    try {
      final resp = await _api.get('/crm/segments');
      await _cache.set('crm_segments', resp.data,
          ttl: CacheService.ttlMedium);
    } catch (_) {}
  }

  /// Payment reminders badge on home screen
  Future<void> _syncPaymentReminders() async {
    try {
      final resp = await _api.get('/payments/reminders/pending');
      await _cache.set('payment_reminders', resp.data,
          ttl: CacheService.ttlShort);
    } catch (_) {}
  }

  // ── Write queue ──────────────────────────────────────────────────────────
  /// Enqueue a write for offline replay. Call this instead of calling
  /// the API directly when you want offline support.
  Future<void> enqueueWrite(QueuedWrite write) async {
    final queue = _loadQueue();
    queue.add(write);
    await _saveQueue(queue);
    state = state.copyWith(pendingWrites: queue.length);

    // If online, try immediately
    if (state.isOnline) await _replayQueue();
  }

  Future<void> _replayQueue() async {
    final queue = _loadQueue();
    if (queue.isEmpty) return;

    final remaining = <QueuedWrite>[];
    for (final item in queue) {
      try {
        await _executeWrite(item);
        debugPrint('SyncEngine: replayed ${item.method} ${item.path}');
      } catch (e) {
        item.retries++;
        if (item.retries < _maxRetries) {
          remaining.add(item);
        } else {
          debugPrint(
              'SyncEngine: dropping write after $_maxRetries retries: ${item.path}');
        }
      }
    }
    await _saveQueue(remaining);
    state = state.copyWith(pendingWrites: remaining.length);

    // Sync data after replaying writes
    if (remaining.length < queue.length) await syncAll();
  }

  Future<void> _executeWrite(QueuedWrite w) async {
    switch (w.method) {
      case 'PUT':
        await _api.put(w.path, data: w.body);
      case 'POST':
        await _api.post(w.path, data: w.body);
      case 'PATCH':
        await _api.patch(w.path, data: w.body);
      case 'DELETE':
        await _api.delete(w.path);
    }
  }

  List<QueuedWrite> _loadQueue() {
    final raw = _prefs.getString(_queueKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => QueuedWrite.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveQueue(List<QueuedWrite> queue) async {
    await _prefs.setString(
        _queueKey, jsonEncode(queue.map((w) => w.toJson()).toList()));
  }

  // ── Manual trigger ─────────────────────────────────────────────────────────
  Future<void> forceSync() => syncAll();

  @override
  void dispose() {
    _pollTimer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────
/// Override this in ProviderScope (see main.dart)
final sharedPrefsForSyncProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override sharedPrefsForSyncProvider in ProviderScope');
});

final syncProvider =
    StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(
    ref.watch(apiClientProvider),
    ref.watch(cacheServiceProvider),
    ref.watch(sharedPrefsForSyncProvider),
  );
});

// Unread count from cache (for nav badge)
final inboxUnreadCountProvider = Provider<int>((ref) {
  final cache = ref.watch(cacheServiceProvider);
  return (cache.getStale('inbox_unread_count') as num?)?.toInt() ?? 0;
});

// Low stock alerts from cache
final lowStockProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final cache = ref.watch(cacheServiceProvider);
  final raw = cache.getStale('low_stock');
  if (raw is! List) return [];
  return raw.whereType<Map<String, dynamic>>().toList();
});
