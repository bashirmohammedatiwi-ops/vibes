import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'session.dart';
import 'theme.dart';

/// يستمع لبث SSE للمحادثة.
/// [onMessage] يُستدعى عند وصول حمولة رسالة؛ [onTick] للتحديث الاحتياطي.
class ConversationLiveStream {
  ConversationLiveStream({
    required this.conversationId,
    this.onMessage,
    this.onTick,
  });

  final String conversationId;
  final void Function(Map<String, dynamic> payload)? onMessage;
  final void Function()? onTick;

  http.Client? _client;
  StreamSubscription<List<int>>? _sub;
  Timer? _fallback;
  Timer? _reconnect;
  final _lineBuf = StringBuffer();
  bool _stopped = false;

  Future<void> start() async {
    _stopped = false;
    await _connect();
    // احتياطي سريع حتى لو SSE بطيء/مقطوع
    _fallback ??= Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_stopped) onTick?.call();
    });
  }

  Future<void> _connect() async {
    await _sub?.cancel();
    _sub = null;
    _client?.close();
    _client = http.Client();
    _lineBuf.clear();

    final request = http.Request('GET', Uri.parse('$apiBase/api/conversations/$conversationId/stream'));
    if (Session.token != null) {
      request.headers['Authorization'] = 'Bearer ${Session.token}';
    }
    request.headers['Accept'] = 'text/event-stream';
    request.headers['Cache-Control'] = 'no-cache';

    try {
      final response = await _client!.send(request);
      if (response.statusCode >= 400) {
        _scheduleReconnect();
        return;
      }
      _sub = response.stream.listen(
        _onChunk,
        onError: (_) => _scheduleReconnect(),
        onDone: () => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onChunk(List<int> bytes) {
    _lineBuf.write(utf8.decode(bytes, allowMalformed: true));
    final raw = _lineBuf.toString();
    final parts = raw.split('\n');
    _lineBuf
      ..clear()
      ..write(parts.isEmpty ? '' : parts.removeLast());

    for (final line in parts) {
      final trimmed = line.trimRight();
      if (!trimmed.startsWith('data:')) continue;
      final payload = trimmed.substring(5).trim();
      if (payload.isEmpty || payload == 'ping') continue;
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          if (map['type'] == 'ping') continue;
          if (map['id'] != null || map['body'] != null || map['kind'] != null) {
            onMessage?.call(map);
            continue;
          }
        }
      } catch (_) {
        /* تجاهل أجزاء غير JSON */
      }
      onTick?.call();
    }
  }

  void _scheduleReconnect() {
    if (_stopped) return;
    _reconnect?.cancel();
    _reconnect = Timer(const Duration(seconds: 2), () {
      if (!_stopped) _connect();
    });
  }

  Future<void> stop() async {
    _stopped = true;
    _reconnect?.cancel();
    _reconnect = null;
    await _sub?.cancel();
    _sub = null;
    _client?.close();
    _client = null;
    _fallback?.cancel();
    _fallback = null;
    _lineBuf.clear();
  }
}
