import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'session.dart';
import 'theme.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class Api {
  static Future<http.Response> _request(String path, {String method = 'GET', Object? body, bool retried = false}) async {
    final headers = {
      'Content-Type': 'application/json',
      if (Session.token != null) 'Authorization': 'Bearer ${Session.token}',
    };
    final uri = Uri.parse('$apiBase$path');
    final response = await switch (method) {
      'POST' => http.post(uri, headers: headers, body: jsonEncode(body ?? {})),
      'PATCH' => http.patch(uri, headers: headers, body: jsonEncode(body ?? {})),
      'DELETE' => http.delete(uri, headers: headers),
      _ => http.get(uri, headers: headers),
    };

    if (response.statusCode == 401 && !retried && !path.contains('/auth/')) {
      final ok = await Session.refreshAccess();
      if (ok) return _request(path, method: method, body: body, retried: true);
      // لا نُصفّر إن كانت الجلسة ما زالت موجودة (تحديث ناجح من طلب موازٍ)
      if (Session.token == null) {
        await Session.clear(notify: true);
      }
    }
    return response;
  }

  static Future<dynamic> send(String path, {String method = 'GET', Object? body}) async {
    final response = await _request(path, method: method, body: body);
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final message = decoded is Map ? decoded['message'] : null;
      throw ApiException(
        message is List ? message.join(' ') : (message?.toString() ?? 'خطأ ${response.statusCode}'),
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  static Future<Map<String, dynamic>> map(String path, {String method = 'GET', Object? body}) async {
    final data = await send(path, method: method, body: body);
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<List<dynamic>> list(String path) async {
    final data = await send(path);
    return data as List<dynamic>;
  }

  /// رفع ملف (multipart) مع نسبة تقدّم — للصور والفيديو والريلز وصور 360°.
  /// [fields] حقول نصية إضافية (kind, targetRatio ...).
  static Future<dynamic> uploadFile(
    String path,
    String filePath, {
    Map<String, String> fields = const {},
    void Function(double progress)? onProgress,
    String fileField = 'file',
    bool retried = false,
  }) async {
    final uri = Uri.parse('$apiBase$path');
    final request = _ProgressMultipartRequest('POST', uri, onBytes: (sent, total) {
      if (onProgress != null && total > 0) onProgress(sent / total);
    });
    if (Session.token != null) {
      request.headers['Authorization'] = 'Bearer ${Session.token}';
    }
    request.fields.addAll(fields);
    request.files.add(await http.MultipartFile.fromPath(fileField, filePath));
    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode == 401 && !retried) {
      if (await Session.refreshAccess()) {
        return uploadFile(path, filePath,
            fields: fields, onProgress: onProgress, fileField: fileField, retried: true);
      }
      if (Session.token == null) {
        await Session.clear(notify: true);
      }
    }
    final decoded = body.isEmpty ? null : jsonDecode(body);
    if (streamed.statusCode >= 400) {
      final message = decoded is Map ? decoded['message'] : null;
      throw ApiException(
        message is List ? message.join(' ') : (message?.toString() ?? 'خطأ ${streamed.statusCode}'),
        statusCode: streamed.statusCode,
      );
    }
    return decoded;
  }

  static Future<dynamic> uploadChatImage(String conversationId, String filePath) async {
    final uri = Uri.parse('$apiBase/api/conversations/$conversationId/messages/image');
    final request = http.MultipartRequest('POST', uri);
    if (Session.token != null) {
      request.headers['Authorization'] = 'Bearer ${Session.token}';
    }
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode == 401) {
      if (await Session.refreshAccess()) {
        return uploadChatImage(conversationId, filePath);
      }
      if (Session.token == null) {
        await Session.clear(notify: true);
      }
    }
    if (streamed.statusCode >= 400) {
      final decoded = body.isEmpty ? null : jsonDecode(body);
      final message = decoded is Map ? decoded['message'] : null;
      throw ApiException(message is List ? message.join(' ') : (message ?? 'خطأ ${streamed.statusCode}'));
    }
    return body.isEmpty ? null : jsonDecode(body);
  }
}

/// MultipartRequest يعلن عن عدد البايتات المرسلة أثناء الرفع.
class _ProgressMultipartRequest extends http.MultipartRequest {
  _ProgressMultipartRequest(super.method, super.url, {required this.onBytes});

  final void Function(int sent, int total) onBytes;

  @override
  http.ByteStream finalize() {
    final byteStream = super.finalize();
    final total = contentLength;
    var sent = 0;
    final transformer = StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (data, sink) {
        sent += data.length;
        onBytes(sent, total);
        sink.add(data);
      },
    );
    return http.ByteStream(byteStream.transform(transformer));
  }
}
