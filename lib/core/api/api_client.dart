/// lib/core/api/api_client.dart
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../auth/auth_service.dart';
import '../auth/auth_models.dart';

class ApiClient {
  late final Dio _dio;
  final AuthService _authService;
  final Ref _ref;

  ApiClient(this._authService, this._ref) {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(_AuthInterceptor(_authService, _dio, _ref));
    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
      error: true,
    ));
  }

  Dio get dio => _dio;

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? params}) =>
      _dio.get<T>(path, queryParameters: params);

  Future<Response<T>> post<T>(String path, {dynamic data}) =>
      _dio.post<T>(path, data: data);

  Future<Response<T>> patch<T>(String path, {dynamic data}) =>
      _dio.patch<T>(path, data: data);

  Future<Response<T>> put<T>(String path, {dynamic data}) =>
      _dio.put<T>(path, data: data);

  Future<Response<T>> delete<T>(String path) => _dio.delete<T>(path);
}

class _AuthInterceptor extends Interceptor {
  final AuthService _authService;
  final Dio _dio;
  final Ref _ref;

  _AuthInterceptor(this._authService, this._dio, this._ref);

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _authService.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final refreshToken = await _authService.getRefreshToken();
      if (refreshToken != null) {
        try {
          final resp = await _dio.post(
            '/auth/refresh',
            data: {'refresh_token': refreshToken},
            options: Options(headers: {'Authorization': null}),
          );
          final data = resp.data as Map<String, dynamic>;
          // AuthTokens is imported above — fixes the undefined_identifier error
          final tokens = AuthTokens.fromJson(data);
          await _authService.saveTokens(tokens);

          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
          final response = await _dio.fetch(opts);
          return handler.resolve(response);
        } catch (_) {
          await _ref.read(authNotifierProvider.notifier).logout();
        }
      } else {
        await _ref.read(authNotifierProvider.notifier).logout();
      }
    }
    handler.next(err);
  }
}

String apiErrorMessage(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map) {
      return data['detail']?.toString() ?? e.message ?? 'Request failed';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please check your internet.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection.';
    }
    return e.message ?? 'Request failed';
  }
  return e.toString();
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final authService = ref.watch(authServiceProvider);
  return ApiClient(authService, ref);
});
