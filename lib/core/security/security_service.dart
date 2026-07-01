/// lib/core/security/security_service.dart
///
/// Phase 6 — Security
///
/// Features:
///  - Session timeout: auto-logout after 15 minutes of inactivity
///  - Activity tracking: any user interaction resets the timer
///  - Biometric lock: prompt Face ID / fingerprint after 2 min in background
///  - Background detector: uses WidgetsBindingObserver
///  - Graceful fallback when biometrics not available
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../auth/auth_service.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const Duration _kSessionTimeout = Duration(minutes: 15);
const Duration _kBiometricTimeout = Duration(minutes: 2);

// ── Security state ────────────────────────────────────────────────────────────
class SecurityState {
  final bool isLocked;
  final bool biometricAvailable;
  final DateTime? lastActivity;
  final DateTime? backgroundedAt;

  const SecurityState({
    this.isLocked = false,
    this.biometricAvailable = false,
    this.lastActivity,
    this.backgroundedAt,
  });

  SecurityState copyWith({
    bool? isLocked,
    bool? biometricAvailable,
    DateTime? lastActivity,
    DateTime? backgroundedAt,
  }) =>
      SecurityState(
        isLocked: isLocked ?? this.isLocked,
        biometricAvailable: biometricAvailable ?? this.biometricAvailable,
        lastActivity: lastActivity ?? this.lastActivity,
        backgroundedAt: backgroundedAt ?? this.backgroundedAt,
      );
}

// ── Security notifier ─────────────────────────────────────────────────────────
class SecurityNotifier extends StateNotifier<SecurityState>
    with WidgetsBindingObserver {
  final LocalAuthentication _localAuth;
  final Ref _ref;
  Timer? _sessionTimer;
  Timer? _biometricTimer;

  SecurityNotifier(this._localAuth, this._ref)
      : super(SecurityState(lastActivity: DateTime.now())) {
    WidgetsBinding.instance.addObserver(this);
    _checkBiometricAvailability();
    _resetSessionTimer();
  }

  // ── Biometric check ───────────────────────────────────────────────────────
  Future<void> _checkBiometricAvailability() async {
    if (kIsWeb) return;
    try {
      final available = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      state = state.copyWith(biometricAvailable: available);
    } catch (_) {
      state = state.copyWith(biometricAvailable: false);
    }
  }

  // ── Activity tracking ─────────────────────────────────────────────────────
  void recordActivity() {
    state = state.copyWith(lastActivity: DateTime.now());
    _resetSessionTimer();
  }

  void _resetSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(_kSessionTimeout, _onSessionExpired);
  }

  Future<void> _onSessionExpired() async {
    debugPrint('SecurityService: session expired — logging out');
    await _ref.read(authNotifierProvider.notifier).logout();
  }

  // ── App lifecycle ─────────────────────────────────────────────────────────
  // 'lifecycleState' is intentional — naming it 'state' would shadow the
  // inherited StateNotifier.state getter used throughout this class.
  @override
  // ignore: avoid_renaming_method_parameters
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    // NOTE: 'state' here refers to the StateNotifier's SecurityState getter.
    // 'lifecycleState' is the AppLifecycleState enum value from the system.
    switch (lifecycleState) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        state = state.copyWith(backgroundedAt: DateTime.now());
        // Start biometric timer
        _biometricTimer?.cancel();
        _biometricTimer =
            Timer(_kBiometricTimeout, () => _lockWithBiometric());
        _sessionTimer?.cancel();
        break;

      case AppLifecycleState.resumed:
        _biometricTimer?.cancel();
        final bg = state.backgroundedAt;
        if (bg != null) {
          final away = DateTime.now().difference(bg);
          // Session expired while in background?
          if (away >= _kSessionTimeout) {
            _onSessionExpired();
            return;
          }
          // Biometric lock threshold?
          if (away >= _kBiometricTimeout && state.biometricAvailable) {
            _lockWithBiometric();
            return;
          }
        }
        state = state.copyWith(backgroundedAt: null);
        _resetSessionTimer();
        break;

      default:
        break;
    }
  }

  // ── Biometric lock / unlock ───────────────────────────────────────────────
  Future<void> _lockWithBiometric() async {
    if (kIsWeb) return;
    state = state.copyWith(isLocked: true);
  }

  Future<bool> unlockWithBiometric() async {
    if (kIsWeb || !state.biometricAvailable) {
      state = state.copyWith(isLocked: false);
      return true;
    }
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason:
            'Verify your identity to continue using WaziBot',
        options: const AuthenticationOptions(
          biometricOnly: false, // allow PIN fallback
          stickyAuth: true,
        ),
      );
      if (authenticated) {
        state = state.copyWith(
            isLocked: false, backgroundedAt: null);
        recordActivity();
      }
      return authenticated;
    } on PlatformException catch (e) {
      debugPrint('Biometric error: ${e.code} ${e.message}');
      // Fallback — unlock without biometric
      state = state.copyWith(isLocked: false);
      return true;
    }
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _biometricTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _localAuthProvider = Provider<LocalAuthentication>(
    (_) => LocalAuthentication());

final securityProvider =
    StateNotifierProvider<SecurityNotifier, SecurityState>((ref) {
  return SecurityNotifier(
    ref.watch(_localAuthProvider),
    ref,
  );
});

// ── Activity tracker widget ───────────────────────────────────────────────────
/// Wrap the root navigator with this to track any tap/drag as activity.
/// Usage:
///   builder: (context, child) => ActivityTracker(child: child!),
class ActivityTracker extends ConsumerWidget {
  final Widget child;
  const ActivityTracker({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) =>
          ref.read(securityProvider.notifier).recordActivity(),
      onPointerMove: (_) =>
          ref.read(securityProvider.notifier).recordActivity(),
      child: child,
    );
  }
}

// ── Biometric lock overlay ────────────────────────────────────────────────────
/// Shown fullscreen when app is locked. Auto-prompts biometric on build.
class BiometricLockScreen extends ConsumerStatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  ConsumerState<BiometricLockScreen> createState() =>
      _BiometricLockScreenState();
}

class _BiometricLockScreenState
    extends ConsumerState<BiometricLockScreen> {
  bool _unlocking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Auto-prompt after frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    setState(() {
      _unlocking = true;
      _error = null;
    });
    final success = await ref
        .read(securityProvider.notifier)
        .unlockWithBiometric();
    if (mounted && !success) {
      setState(() {
        _unlocking = false;
        _error = 'Authentication failed. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary
                        .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: theme.colorScheme.primary
                            .withValues(alpha: 0.3),
                        width: 2),
                  ),
                  child: Icon(
                    Icons.fingerprint,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text('WaziBot Locked',
                    style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Verify your identity to continue',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (_unlocking)
                  const CircularProgressIndicator()
                else
                  ElevatedButton.icon(
                    onPressed: _unlock,
                    icon: const Icon(Icons.fingerprint,
                        color: Colors.black),
                    label: const Text('Unlock'),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error),
                      textAlign: TextAlign.center),
                ],
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () => ref
                      .read(authNotifierProvider.notifier)
                      .logout(),
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Sign out instead'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
