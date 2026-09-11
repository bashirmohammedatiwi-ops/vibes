import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';
import '../storage/token_storage.dart';

/// ═══════════════════════════════════════════════════════════
/// عميل VIBES المقوّى — اعتراض 401 → تحديث تلقائي → إعادة محاولة
/// مع طابور موحّد أثناء التحديث وخرائط أخطاء عربية
/// ═══════════════════════════════════════════════════════════

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required this.tokenStorage}) {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        sendTimeout: const Duration(seconds: 60),
        validateStatus: (_) => true, // نعالج الحالات يدوياً لرسائل أدق
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenStorage.readAccess();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) async {
          if (response.statusCode! < 400) {
            handler.next(response);
            return;
          }

          if (response.statusCode == 401 &&
              response.requestOptions.path != '/api/auth/refresh') {
            final retried = await _retryWithRefresh(response.requestOptions);
            if (retried != null) {
              handler.resolve(retried);
              return;
            }
          }

          handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              error: ApiException(
                _extractMessage(response),
                statusCode: response.statusCode,
              ),
              type: DioExceptionType.badResponse,
            ),
          );
        },
        onError: (error, handler) async {
          if (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.sendTimeout ||
              error.type == DioExceptionType.connectionError) {
            handler.next(
              error.copyWith(
                error: const ApiException(
                  'تعذّر الاتصال بالخادم — تحقق من الشبكة وحاول مجدداً',
                ),
              ),
            );
            return;
          }
          handler.next(error);
        },
      ),
    );
  }

  late final Dio dio;
  final TokenStorage tokenStorage;

  Completer<String?>? _refreshCompleter;

  /// يحدّث التوكن مرة واحدة (طابور موحّد) ويعيد المحاولة
  Future<Response?> _retryWithRefresh(RequestOptions original) async {
    try {
      final completer = _refreshCompleter ??= Completer<String?>();

      if (identical(completer, _refreshCompleter) && !completer.isCompleted) {
        // أول طالب ينفّذ التحديث فعلياً
        final refresh = await tokenStorage.readRefresh();
        if (refresh == null) {
          completer.complete(null);
        } else {
          try {
            final res = await Dio(BaseOptions(baseUrl: ApiConstants.baseUrl))
                .post('/api/auth/refresh', data: {'refreshToken': refresh});
            if (res.statusCode == 200 && res.data['accessToken'] != null) {
              await tokenStorage.saveTokens(
                access: res.data['accessToken'] as String,
                refresh: (res.data['refreshToken'] as String?) ?? refresh,
              );
              completer.complete(res.data['accessToken'] as String);
            } else {
              await tokenStorage.clear();
              completer.complete(null);
            }
          } catch (_) {
            await tokenStorage.clear();
            completer.complete(null);
          }
        }
      }

      final newToken = await completer.future;
      _refreshCompleter = null;
      if (newToken == null) return null;

      final headers = Map<String, dynamic>.from(original.headers);
      headers['Authorization'] = 'Bearer $newToken';

      return await Dio(BaseOptions(baseUrl: ApiConstants.baseUrl))
          .fetch(original.copyWith(headers: headers));
    } catch (_) {
      _refreshCompleter = null;
      return null;
    }
  }

  String _extractMessage(Response response) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is List && message.isNotEmpty) {
        return message.first.toString();
      }
      if (message is String && message.isNotEmpty) return message;
    }
    return switch (response.statusCode) {
      400 => 'طلب غير صالح',
      401 => 'انتهت الجلسة — سجّل الدخول من جديد',
      403 => 'لا تملك صلاحية لهذا الإجراء',
      404 => 'العنصر غير موجود',
      429 => 'طلبات كثيرة — انتظر قليلاً',
      _ => 'حدث خطأ غير متوقع (${response.statusCode})',
    };
  }

  // ── الواجهة العامة ──

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final res = await dio.get(path, queryParameters: queryParameters);
    return _unwrap(res);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final res = await dio.post(path, data: body);
    return _unwrap(res);
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    final res = await dio.patch(path, data: body);
    return _unwrap(res);
  }

  Future<dynamic> delete(String path) async {
    final res = await dio.delete(path);
    return _unwrap(res);
  }

  /// رفع ملف متعدد الأجزاء (صور/فيديو/إثباتات)
  Future<dynamic> upload(
    String path, {
    required String fieldName,
    required MultipartFile file,
    Map<String, String>? fields,
  }) async {
    final form = FormData();
    form.files.add(MapEntry(fieldName, file));
    fields?.forEach((k, v) => form.fields.add(MapEntry(k, v)));
    final res = await dio.post(path, data: form);
    return _unwrap(res);
  }

  dynamic _unwrap(Response res) {
    if (res.statusCode! >= 400) {
      throw ApiException(_extractMessage(res), statusCode: res.statusCode);
    }
    return res.data;
  }
}

/// مزوّد Riverpod — يُنشأ مرة واحدة
final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(tokenStorage: ref.watch(tokenStorageProvider)),
);
