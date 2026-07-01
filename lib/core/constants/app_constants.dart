/// lib/core/constants/app_constants.dart
library;

class AppConstants {
  AppConstants._();

  // ── Backend ──────────────────────────────────────────────────────────────
  static const String baseUrl = 'https://wazibot-api-assistant.onrender.com';
  static const String webDashboardUrl =
      'https://wazibot-api-assistant.onrender.com/dashboard';

  // ── Storage keys ──────────────────────────────────────────────────────────
  // Used by both flutter_secure_storage (mobile) and SharedPreferences (web)
  static const String kAccessToken = 'wazibot_access_token';
  static const String kRefreshToken = 'wazibot_refresh_token';
  // NOTE: kBusinessId is stored as int in SharedPreferences on web,
  //       and as String in secure_storage on mobile.
  static const String kBusinessId = 'wazibot_business_id';
  static const String kBusinessName = 'wazibot_business_name';
  static const String kUsername = 'wazibot_username';

  // ── Shared preferences keys ───────────────────────────────────────────────
  static const String kThemeMode = 'theme_mode';
  static const String kRememberMe = 'remember_me';
  static const String kOnboardingDone = 'onboarding_done';

  // ── Timeouts ──────────────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ── Pagination ────────────────────────────────────────────────────────────
  static const int pageSize = 20;

  // ── Plan display names ────────────────────────────────────────────────────
  static const Map<String, String> planNames = {
    'free': 'Free',
    'growth': 'Growth',
    'pro': 'Pro',
    'enterprise': 'Enterprise',
  };
}
