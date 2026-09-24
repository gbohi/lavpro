import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'config.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.status]);
  final String message;
  final int? status;
  @override
  String toString() => message;
}

/// Client HTTP : ajoute le jeton et traduit les erreurs de l'API en messages lisibles.
class ApiClient {
  ApiClient(this._storage) {
    dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiUrl,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = _token ??= await _storage.read(key: _tokenKey);
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (e, handler) {
        if (e.response?.statusCode == 401) onUnauthorized?.call();
        handler.next(e);
      },
    ));
  }

  static const _tokenKey = 'lavpro_token';
  final FlutterSecureStorage _storage;
  late final Dio dio;
  String? _token;
  void Function()? onUnauthorized;

  Future<String?> readToken() async => _token ??= await _storage.read(key: _tokenKey);

  Future<void> saveToken(String? token) async {
    _token = token;
    if (token == null) {
      await _storage.delete(key: _tokenKey);
    } else {
      await _storage.write(key: _tokenKey, value: token);
    }
  }

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) =>
      _wrap(() => dio.get<T>(path, queryParameters: _clean(query)));
  Future<T> post<T>(String path, [Object? data]) => _wrap(() => dio.post<T>(path, data: data ?? {}));
  Future<T> patch<T>(String path, Object data) => _wrap(() => dio.patch<T>(path, data: data));
  Future<T> put<T>(String path, Object data) => _wrap(() => dio.put<T>(path, data: data));
  Future<void> delete(String path) => _wrap(() => dio.delete<void>(path));

  Map<String, dynamic>? _clean(Map<String, dynamic>? q) =>
      q == null ? null : (Map.of(q)..removeWhere((_, v) => v == null));

  Future<T> _wrap<T>(Future<Response<T>> Function() call) async {
    try {
      final r = await call();
      return r.data as T;
    } on DioException catch (e) {
      throw ApiException(_message(e), e.response?.statusCode);
    }
  }

  String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] is String) return data['detail'] as String;
    if (data is Map && data['detail'] is List && (data['detail'] as List).isNotEmpty) {
      return ((data['detail'] as List).first as Map)['msg']?.toString() ?? 'Données invalides';
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return 'Connexion impossible. Vérifiez votre réseau.';
      default:
        return 'Une erreur est survenue (${e.response?.statusCode ?? '—'})';
    }
  }
}
