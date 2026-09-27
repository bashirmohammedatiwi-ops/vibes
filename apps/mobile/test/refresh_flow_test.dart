import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vibes/core/network/api_client.dart';
import 'package:vibes/core/storage/token_storage.dart';

class _NoopTokens extends TokenStorage {}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.handler});
  final Future<ResponseBody> Function(RequestOptions) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // محاكاة قناة التخزين الآمن (بلا تطبيق أصلي في الاختبارات)
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'read') return null;
    return null;
  });

  test('ApiException يحمل الرسالة والكود', () {
    const client = ApiException('انتهت الجلسة', statusCode: 401);
    expect(client.message, 'انتهت الجلسة');
    expect(client.toString(), client.message);
  });

  test('العميل يمرر 200 ويرمي ApiException برسالة السيرفر على 400', () async {
    final api = ApiClient(tokenStorage: _NoopTokens());
    api.dio.httpClientAdapter = _FakeAdapter(
      handler: (options) async {
        if (options.path.contains('/ok')) {
          return ResponseBody.fromString(
            '{"ok":true}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString(
          '{"message":"هذا التاريخ محجوز"}',
          400,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      },
    );

    final ok = await api.get('/ok');
    expect((ok as Map<String, dynamic>)['ok'], isTrue);

    await expectLater(
      () => api.get('/bad'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.message, 'message', contains('محجوز'))
            .having((e) => e.statusCode, 'code', 400),
      ),
    );
  });
}
