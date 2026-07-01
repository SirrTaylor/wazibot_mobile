/// lib/core/cache/cache_service.dart
///
/// Lightweight key-value cache backed by SharedPreferences.
/// Stores JSON strings with an optional TTL (time-to-live).
/// Used to cache products, orders, analytics and business profile
/// so the app renders instantly while fresh data loads in background.
library;

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheEntry {
  final dynamic data;
  final DateTime storedAt;
  final Duration? ttl;

  CacheEntry({required this.data, required this.storedAt, this.ttl});

  bool get isExpired {
    if (ttl == null) return false;
    return DateTime.now().isAfter(storedAt.add(ttl!));
  }

  Map<String, dynamic> toJson() => {
        'data': data,
        'stored_at': storedAt.toIso8601String(),
        'ttl_seconds': ttl?.inSeconds,
      };

  factory CacheEntry.fromJson(Map<String, dynamic> json) => CacheEntry(
        data: json['data'],
        storedAt: DateTime.parse(json['stored_at'] as String),
        ttl: json['ttl_seconds'] != null
            ? Duration(seconds: json['ttl_seconds'] as int)
            : null,
      );
}

class CacheService {
  static const String _prefix = 'wazibot_cache_';

  // ── Standard cache keys ───────────────────────────────────────────────────
  static const String kProducts = 'products';
  static const String kOrders = 'orders';
  static const String kOrdersNew = 'orders_new';
  static const String kAnalytics = 'analytics';
  static const String kProfile = 'business_profile';
  static const String kConversations = 'conversations';

  // ── Default TTLs ──────────────────────────────────────────────────────────
  static const Duration ttlShort = Duration(minutes: 5);
  static const Duration ttlMedium = Duration(minutes: 30);
  static const Duration ttlLong = Duration(hours: 6);

  final SharedPreferences _prefs;

  CacheService(this._prefs);

  /// Write data to cache with optional TTL.
  Future<void> set(String key, dynamic data, {Duration? ttl}) async {
    final entry = CacheEntry(
      data: data,
      storedAt: DateTime.now(),
      ttl: ttl,
    );
    await _prefs.setString(
      '$_prefix$key',
      jsonEncode(entry.toJson()),
    );
  }

  /// Read cached data. Returns null if missing or expired.
  dynamic get(String key, {bool ignoreExpiry = false}) {
    final raw = _prefs.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      final entry =
          CacheEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (!ignoreExpiry && entry.isExpired) return null;
      return entry.data;
    } catch (_) {
      return null;
    }
  }

  /// Read stale cached data (ignores TTL) — used for offline fallback.
  dynamic getStale(String key) => get(key, ignoreExpiry: true);

  /// True if key exists and is not expired.
  bool isFresh(String key) {
    final raw = _prefs.getString('$_prefix$key');
    if (raw == null) return false;
    try {
      final entry =
          CacheEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return !entry.isExpired;
    } catch (_) {
      return false;
    }
  }

  /// Delete a single cache entry.
  Future<void> invalidate(String key) async =>
      _prefs.remove('$_prefix$key');

  /// Clear all WaziBot cache entries.
  Future<void> clearAll() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(_prefix));
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }

  /// How old is the cached data (null if not cached).
  Duration? age(String key) {
    final raw = _prefs.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      final entry =
          CacheEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return DateTime.now().difference(entry.storedAt);
    } catch (_) {
      return null;
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final cacheServiceProvider = Provider<CacheService>((ref) {
  throw UnimplementedError(
      'cacheServiceProvider must be overridden in ProviderScope');
});

/// Override this in main() after SharedPreferences is initialised:
///
///   final prefs = await SharedPreferences.getInstance();
///   runApp(ProviderScope(
///     overrides: [
///       cacheServiceProvider.overrideWithValue(CacheService(prefs)),
///     ],
///     child: const WaziBotApp(),
///   ));
