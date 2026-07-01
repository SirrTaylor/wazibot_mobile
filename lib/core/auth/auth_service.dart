/// lib/core/auth/auth_service.dart
library;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import 'auth_models.dart';

/// On web, flutter_secure_storage uses localStorage which can behave
/// differently. We wrap all reads/writes in try/catch and fall back to
/// SharedPreferences on web for reliability in dev/Chrome.
class AuthService {
  final FlutterSecureStorage _storage;

  AuthService(this._storage);

  // ── Write ─────────────────────────────────────────────────────────────────
  Future<void> saveTokens(AuthTokens tokens) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.kAccessToken, tokens.accessToken);
        await prefs.setString(AppConstants.kRefreshToken, tokens.refreshToken);
        if (tokens.businessName != null) {
          await prefs.setString(AppConstants.kBusinessName, tokens.businessName!);
        }
        if (tokens.businessId != null) {
          await prefs.setInt(AppConstants.kBusinessId, tokens.businessId!);
        }
      } else {
        await Future.wait([
          _storage.write(
              key: AppConstants.kAccessToken, value: tokens.accessToken),
          _storage.write(
              key: AppConstants.kRefreshToken, value: tokens.refreshToken),
          if (tokens.businessName != null)
            _storage.write(
                key: AppConstants.kBusinessName, value: tokens.businessName!),
          if (tokens.businessId != null)
            _storage.write(
                key: AppConstants.kBusinessId,
                value: tokens.businessId.toString()),
        ]);
      }
    } catch (e) {
      // Non-fatal — log and continue
      debugPrint('AuthService.saveTokens error: $e');
    }
  }

  // ── Read ──────────────────────────────────────────────────────────────────
  Future<String?> getAccessToken() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(AppConstants.kAccessToken);
      }
      return await _storage.read(key: AppConstants.kAccessToken);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(AppConstants.kRefreshToken);
      }
      return await _storage.read(key: AppConstants.kRefreshToken);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getBusinessName() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(AppConstants.kBusinessName);
      }
      return await _storage.read(key: AppConstants.kBusinessName);
    } catch (_) {
      return null;
    }
  }

  Future<int?> getBusinessId() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getInt(AppConstants.kBusinessId);
      }
      final s = await _storage.read(key: AppConstants.kBusinessId);
      return s != null ? int.tryParse(s) : null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasSession() async {
    try {
      final token = await getAccessToken();
      return token != null && token.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ── Clear ──────────────────────────────────────────────────────────────────
  Future<void> clearSession() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await Future.wait([
          prefs.remove(AppConstants.kAccessToken),
          prefs.remove(AppConstants.kRefreshToken),
          prefs.remove(AppConstants.kBusinessName),
          prefs.remove(AppConstants.kBusinessId),
          prefs.remove(AppConstants.kUsername),
        ]);
      } else {
        await Future.wait([
          _storage.delete(key: AppConstants.kAccessToken),
          _storage.delete(key: AppConstants.kRefreshToken),
          _storage.delete(key: AppConstants.kBusinessName),
          _storage.delete(key: AppConstants.kBusinessId),
          _storage.delete(key: AppConstants.kUsername),
        ]);
      }
    } catch (e) {
      debugPrint('AuthService.clearSession error: $e');
    }
  }
}

// ── Providers ────────────────────────────────────────────────────────────────
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  ),
);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(secureStorageProvider)),
);

// Auth state
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final AuthUser? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, AuthUser? user, String? error}) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: error,
      );
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    try {
      final authService = ref.read(authServiceProvider);
      final hasSession = await authService.hasSession();
      if (!hasSession) {
        return const AuthState(status: AuthStatus.unauthenticated);
      }

      final businessName = await authService.getBusinessName();
      final businessId = await authService.getBusinessId();
      return AuthState(
        status: AuthStatus.authenticated,
        user: AuthUser(
          username: '',
          role: 'business',
          businessName: businessName,
          businessId: businessId,
        ),
      );
    } catch (_) {
      return const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> onLoginSuccess(AuthTokens tokens) async {
    final authService = ref.read(authServiceProvider);
    await authService.saveTokens(tokens);
    state = AsyncData(AuthState(
      status: AuthStatus.authenticated,
      user: AuthUser(
        username: '',
        role: tokens.role,
        businessName: tokens.businessName,
        businessId: tokens.businessId,
      ),
    ));
  }

  Future<void> logout() async {
    final authService = ref.read(authServiceProvider);
    await authService.clearSession();
    state = const AsyncData(AuthState(status: AuthStatus.unauthenticated));
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
