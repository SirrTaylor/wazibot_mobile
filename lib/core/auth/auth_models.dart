/// lib/core/auth/auth_models.dart
library;

class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final String role;
  final String? businessName;
  final int? businessId;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.role,
    this.businessName,
    this.businessId,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        role: json['role'] as String? ?? 'business',
        businessName: json['business_name'] as String?,
        businessId: json['business_id'] as int?,
      );
}

class AuthUser {
  final String username;
  final String? businessName;
  final int? businessId;
  final String role;

  const AuthUser({
    required this.username,
    required this.role,
    this.businessName,
    this.businessId,
  });
}
