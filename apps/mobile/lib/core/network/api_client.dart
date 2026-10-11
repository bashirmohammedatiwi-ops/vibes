import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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

/// إشارة انتهاء الجلسة فعلياً (رفض الخادم رمز التحديث) — تستمع لها
/// [AuthController] لتخرج بنظافة بدل البقاء في حالة «Unauthorized».
final sessionExpiredSignal = ValueNotifier<int>(0);

/// وقت انتهاء JWT من حمولته (بلا تحقق من التوقيع — للتحديث المسبق فقط).
DateTime? _jwtExpiry(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    final exp = payload is Map ? payload['exp'] : null;
    if (exp is! num) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
  } catch (_) {
    return null;
  }
}

enum _RefreshResult { ok, rejected, offline }

class ApiClient {
  ApiClient({required this.tokenStorage}) {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 60),
        validateStatus: (_) => true, // نعالج الحالات يدوياً لرسائل أدق
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          var token = await tokenStorage.readAccess();
          // تحديث مسبق: إن قارب الرمز على الانتهاء نجدّده قبل الطلب
          // بدل انتظار 401 (يمنع موجات الرفض عند فتح التطبيق).
          if (token != null &&
              token.isNotEmpty &&
              options.path != '/api/auth/refresh') {
            final exp = _jwtExpiry(token);
            if (exp != null &&
                exp.isBefore(DateTime.now().add(const Duration(seconds: 45)))) {
              final r = await _coordinatedRefresh();
              if (r == _RefreshResult.ok) {
                token = await tokenStorage.readAccess();
              }
            }
          }
          if (token != null && token.isNotEmpty) {
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
              response.requestOptions.extra['authRetried'] != true &&
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

  /// طابور تحديث واحد لكل التطبيق (static) — حتى لو أُعيد إنشاء
  /// العميل، لا يُرسل رمز التحديث نفسه مرتين بالتوازي (الخادم يدوّره).
  static Future<_RefreshResult>? _refreshFuture;

  Future<_RefreshResult> _coordinatedRefresh() {
    final running = _refreshFuture;
    if (running != null) return running;
    final f = _performRefresh().whenComplete(() => _refreshFuture = null);
    _refreshFuture = f;
    return f;
  }

  Future<_RefreshResult> _performRefresh() async {
    final refresh = await tokenStorage.readRefresh();
    if (refresh == null || refresh.isEmpty) return _RefreshResult.rejected;
    try {
      final res = await Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          validateStatus: (_) => true,
        ),
      ).post('/api/auth/refresh', data: {'refreshToken': refresh});
      final code = res.statusCode ?? 0;
      if (code >= 200 &&
          code < 300 &&
          res.data is Map &&
          res.data['accessToken'] != null) {
        await tokenStorage.saveTokens(
          access: res.data['accessToken'] as String,
          refresh: (res.data['refreshToken'] as String?) ?? refresh,
        );
        return _RefreshResult.ok;
      }
      if (code == 401 || code == 403) {
        // ربما جدّد طلب آخر الرمز للتو — إن تغيّر المخزَّن فالجلسة سليمة
        final current = await tokenStorage.readRefresh();
        if (current != null && current.isNotEmpty && current != refresh) {
          return _RefreshResult.ok;
        }
        // رفض نهائي من الخادم: الجلسة انتهت فعلاً
        await tokenStorage.clear();
        sessionExpiredSignal.value++;
        return _RefreshResult.rejected;
      }
      // 5xx أو ردّ غير متوقع: لا نمسح الجلسة بسبب عطل مؤقت
      return _RefreshResult.offline;
    } catch (_) {
      // انقطاع شبكة/مهلة: نحتفظ بالرموز ونحاول لاحقاً
      return _RefreshResult.offline;
    }
  }

  /// يحدّث التوكن مرة واحدة (طابور موحّد) ويعيد المحاولة
  Future<Response?> _retryWithRefresh(RequestOptions original) async {
    final used = (original.headers['Authorization'] as String?)?.replaceFirst(
      'Bearer ',
      '',
    );
    final stored = await tokenStorage.readAccess();
    // طلب آخر جدّد الرمز بعد إرسال هذا الطلب — أعد المحاولة مباشرة
    if (stored == null || stored.isEmpty || stored == used) {
      final r = await _coordinatedRefresh();
      if (r != _RefreshResult.ok) return null;
    }
    final newToken = await tokenStorage.readAccess();
    if (newToken == null || newToken.isEmpty) return null;
    final headers = Map<String, dynamic>.from(original.headers);
    headers['Authorization'] = 'Bearer $newToken';
    final retry = await dio.fetch<dynamic>(original.copyWith(headers: headers));
    return retry;
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

  /// طلبات القراءة تُعاد تلقائياً عند الأعطال العابرة (انقطاع، مهلة، 5xx/429):
  /// أول فتح على iOS تُهيّأ فيه الشبكة وتظهر نوافذ الأذونات بالتزامن مع
  /// عشرات الطلبات، فيفشل بعضها مؤقتاً — والمحاولة الثانية تنجح.
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    const delays = [Duration(milliseconds: 700), Duration(milliseconds: 1800)];
    for (var attempt = 0; ; attempt++) {
      try {
        final res = await dio.get(path, queryParameters: queryParameters);
        final code = res.statusCode ?? 0;
        final transient =
            code == 429 || code == 502 || code == 503 || code == 504;
        if (transient && attempt < delays.length) {
          await Future<void>.delayed(delays[attempt]);
          continue;
        }
        return _unwrap(res);
      } on DioException catch (e) {
        final transient =
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.unknown;
        if (transient && attempt < delays.length) {
          await Future<void>.delayed(delays[attempt]);
          continue;
        }
        throw _surface(e);
      }
    }
  }

  Future<dynamic> post(String path, {Object? body}) async {
    try {
      final res = await dio.post(path, data: body);
      return _unwrap(res);
    } on DioException catch (e) {
      throw _surface(e);
    }
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    try {
      final res = await dio.patch(path, data: body);
      return _unwrap(res);
    } on DioException catch (e) {
      throw _surface(e);
    }
  }

  Future<dynamic> delete(String path) async {
    try {
      final res = await dio.delete(path);
      return _unwrap(res);
    } on DioException catch (e) {
      throw _surface(e);
    }
  }

  Future<String> getText(String path) async {
    try {
      final res = await dio.get<String>(
        path,
        options: Options(
          responseType: ResponseType.plain,
          headers: const {'Accept': 'text/html, text/plain;q=0.9, */*;q=0.8'},
        ),
      );
      if (res.statusCode != null && res.statusCode! >= 400) {
        throw ApiException(_extractMessage(res), statusCode: res.statusCode);
      }
      return res.data ?? '';
    } on DioException catch (e) {
      throw _surface(e);
    }
  }

  /// يرفع الاستثناء الداخلي (ApiException برسالة عربية) إن وُجد
  Object _surface(DioException e) {
    final inner = e.error;
    if (inner is ApiException) return inner;
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return const ApiException(
        'تعذّر الاتصال بالخادم — تحقق من الشبكة وحاول مجدداً',
      );
    }
    return ApiException(e.message ?? 'حدث خطأ غير متوقع');
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
