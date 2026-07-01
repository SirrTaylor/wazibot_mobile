/// lib/core/notifications/notification_service.dart
///
/// Handles:
///  - Firebase Cloud Messaging (FCM) — push notifications from WaziBot backend
///  - flutter_local_notifications — display foreground notifications
///  - Deep-link routing on tap (new order → /orders/:id, etc.)
///
/// Call NotificationService.init(router) once in main() after Firebase.initializeApp().
library;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

// Background handler — must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised in main() before this fires
  debugPrint('FCM background message: ${message.messageId}');
}

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static GoRouter? _router;

  // ── Android notification channel ──────────────────────────────────────────
  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    'wazibot_high_importance',
    'WaziBot Alerts',
    description: 'Orders, payments and business alerts',
    importance: Importance.high,
    playSound: true,
  );

  // ── Initialise ────────────────────────────────────────────────────────────
  static Future<void> init(GoRouter router) async {
    _router = router;

    // Skip on web — FCM web requires extra service worker setup
    if (kIsWeb) return;

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Create Android channel
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Initialise local notifications
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );
    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Foreground messages → show local notification
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background tap (app in background, user taps notification)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // Terminated tap (app was closed, opened via notification)
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _handleMessageTap(initial);

    // Log FCM token for backend registration
    final token = await FirebaseMessaging.instance.getToken();
    debugPrint('FCM Token: $token');
    // Token is registered with the backend via NotificationService.registerToken()
    // called after login — see auth flow.

    // Token refresh — re-register with backend when token rotates
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      debugPrint('FCM Token refreshed: $newToken');
      _registerTokenWithBackend(newToken);
    });
  }

  /// Call this after login to register the FCM token with WaziBot backend.
  static Future<void> registerToken(
      Future<void> Function(String token) onRegister) async {
    if (kIsWeb) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await onRegister(token);
  }

  static void _registerTokenWithBackend(String token) {
    // Handled by the caller via registerToken() — kept here for refresh events.
    debugPrint('FCM token rotated, re-registration needed: $token');
  }

  // ── FCM token getter (use to register with backend) ───────────────────────
  static Future<String?> getToken() async {
    if (kIsWeb) return null;
    return FirebaseMessaging.instance.getToken();
  }

  // ── Foreground message handler ────────────────────────────────────────────
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final type = message.data['type'] as String? ?? '';
    final id = _notifId(type);

    await _local.show(
      id,
      notification.title ?? 'WaziBot',
      notification.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: _buildPayload(message.data),
    );
  }

  // ── Tap handlers ──────────────────────────────────────────────────────────
  static void _handleMessageTap(RemoteMessage message) =>
      _navigate(message.data);

  static void _onLocalNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    final parts = response.payload!.split(':');
    if (parts.length < 2) return;
    _navigate({'type': parts[0], 'id': parts[1]});
  }

  // ── Deep-link routing ─────────────────────────────────────────────────────
  static void _navigate(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    final id = data['id'] as String? ?? '';
    final router = _router;
    if (router == null) return;

    switch (type) {
      case 'new_order':
      case 'order_update':
        router.go(id.isNotEmpty ? '/orders/$id' : '/orders');
      case 'new_customer':
        router.go('/inbox');
      case 'payment':
        router.go('/analytics');
      case 'low_stock':
        router.go('/more/products');
      case 'campaign':
        router.go('/analytics');
      default:
        router.go('/home');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static int _notifId(String type) => type.hashCode.abs() % 100000;

  static String _buildPayload(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? 'general';
    final id = data['id'] as String? ?? '';
    return '$type:$id';
  }

  // ── Manual local notification (for testing / scheduled) ──────────────────
  static Future<void> showLocal({
    required String title,
    required String body,
    String type = 'general',
    String id = '',
  }) async {
    if (kIsWeb) return;
    await _local.show(
      _notifId(type),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: '$type:$id',
    );
  }
}
