import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

/// ═══════════════════════════════════════════════════════════
/// محرك الاتصال VIBEES — طبقة احترافية فوق LiveKit:
/// جودة تكيفية، مراقبة شبكة حية، استعادة تلقائية للانقطاعات،
/// ومستوى صوت حي لتحريك الواجهة.
/// ═══════════════════════════════════════════════════════════

/// جودة الخط المبسطة لعرضها في الواجهة.
enum CallLine {
  excellent,
  good,
  poor,
  lost;

  String get label => switch (this) {
    CallLine.excellent => 'ممتاز',
    CallLine.good => 'جيد',
    CallLine.poor => 'ضعيف',
    CallLine.lost => 'منقطع',
  };

  int get bars => switch (this) {
    CallLine.excellent => 3,
    CallLine.good => 2,
    CallLine.poor => 1,
    CallLine.lost => 0,
  };
}

CallLine _lineFromQuality(ConnectionQuality? q) => switch (q) {
  ConnectionQuality.excellent => CallLine.excellent,
  ConnectionQuality.good => CallLine.good,
  ConnectionQuality.poor || ConnectionQuality.unknown => CallLine.poor,
  ConnectionQuality.lost => CallLine.lost,
  null => CallLine.poor,
};

/// سبب فشل الاتصال — لرسائل واضحة للمستخدم وإعادة محاولة ذكية.
enum CallFailure {
  network,
  token,
  server,
  unknown;

  String get userMessage => switch (this) {
    CallFailure.network =>
      'تعذّر الوصول لخادم المكالمات — تحقق من اتصال الإنترنت',
    CallFailure.token => 'انتهت صلاحية المكالمة، أعد المحاولة',
    CallFailure.server => 'خدمة المكالمات غير متاحة حالياً',
    CallFailure.unknown => 'تعذّر بدء المكالمة',
  };

  /// هل يستحق الفشل إعادة محاولة تلقائية؟
  bool get retryable => this == CallFailure.network;
}

/// تصنيف استثناءات LiveKit إلى فشل مفهوم.
CallFailure _classifyError(Object e) {
  final msg = e.toString().toLowerCase();
  if (msg.contains('token') ||
      msg.contains('jwt') ||
      msg.contains('unauthorized') ||
      msg.contains('permission') ||
      msg.contains('401') ||
      msg.contains('403')) {
    return CallFailure.token;
  }
  if (msg.contains('timeout') ||
      msg.contains('network') ||
      msg.contains('socket') ||
      msg.contains('connection refused') ||
      msg.contains('unreachable') ||
      msg.contains('ws') ||
      msg.contains('websocket') ||
      msg.contains('handshake')) {
    return CallFailure.network;
  }
  if (msg.contains('503') ||
      msg.contains('service unavailable') ||
      msg.contains('500')) {
    return CallFailure.server;
  }
  return CallFailure.unknown;
}

/// حالة المحرك المُندفعة للواجهة.
class CallEngineState {
  const CallEngineState({
    this.line = CallLine.poor,
    this.reconnecting = false,
    this.micLevel = 0.0,
    this.peerLevel = 0.0,
  });

  final CallLine line;
  final bool reconnecting;

  /// مستوى الميكروفون المنعّم 0..1 — لتحريك المونوغرام بصوت المتحدث.
  final double micLevel;

  /// مستوى صوت الطرف الآخر المنعّم 0..1.
  final double peerLevel;

  CallEngineState copyWith({
    CallLine? line,
    bool? reconnecting,
    double? micLevel,
    double? peerLevel,
  }) {
    return CallEngineState(
      line: line ?? this.line,
      reconnecting: reconnecting ?? this.reconnecting,
      micLevel: micLevel ?? this.micLevel,
      peerLevel: peerLevel ?? this.peerLevel,
    );
  }
}

/// محرك مكالمة — يُنشأ لكل مكالمة ويُتلف بعدها.
///
/// يفعّل dynacast + adaptiveStream لجودة تكيفية بأقل نطاق،
/// يراقب جودة الطرفين وأحداث الاستعادة، ويحدّث الواجهة بحالة حية.
/// عند فشل الاتصال الأولي يجري حتى 3 محاولات بتراجع أسّي مع jitter،
/// وإذا انقطعت الشبكة أثناء المكالمة يترك LiveKit يعيد الاتصال
/// تلقائياً ويرفع حالة "إعادة الاتصال" للواجهة.
class CallEngine {
  CallEngine({
    this.onState,
    this.onPeerLeft,
    this.onPeerJoined,
    this.onFailure,
  });

  final void Function(CallEngineState state)? onState;
  final VoidCallback? onPeerLeft;
  final VoidCallback? onPeerJoined;

  /// يُستدعى عند فشل الاتصال النهائي (بعد استنفاد المحاولات)
  /// برسالة جاهزة للعرض للمستخدم.
  final void Function(CallFailure failure, String detail)? onFailure;

  Room? _room;
  EventsListener<RoomEvent>? _listener;
  Timer? _sampleTimer;
  CallEngineState _state = const CallEngineState();
  bool _disposed = false;

  static const int _maxConnectAttempts = 3;
  int _connectAttempts = 0;

  /// يتصل بالغرفة بخيارات الأداء العالي — مع إعادة محاولة تلقائية
  /// للأعطال الشبكية (تراجع أسّي + jitter لتجنب العواصف المتزامنة).
  Future<Room> connect(String url, String token) async {
    Object? lastError;
    while (_connectAttempts < _maxConnectAttempts) {
      if (_disposed) throw StateError('CallEngine disposed');
      _connectAttempts++;
      try {
        final room = await _connectOnce(url, token);
        _connectAttempts = 0;
        return room;
      } catch (e) {
        lastError = e;
        final failure = _classifyError(e);
        debugPrint(
          '[CallEngine] محاولة $_connectAttempts/$_maxConnectAttempts فشلت: $e',
        );
        if (failure.retryable && _connectAttempts < _maxConnectAttempts) {
          final backoffMs =
              (600 * pow(2, _connectAttempts - 1)).toInt() +
              Random().nextInt(300);
          await Future<void>.delayed(Duration(milliseconds: backoffMs));
          continue;
        }
        break;
      }
    }
    final failure = _classifyError(lastError ?? StateError('unknown'));
    onFailure?.call(failure, lastError.toString());
    throw CallConnectException(failure, lastError.toString());
  }

  Future<Room> _connectOnce(String url, String token) async {
    final room = Room(
      roomOptions: const RoomOptions(
        dynacast: true,
        adaptiveStream: true,
        // صوت فقط: إلغاء صدى + كبح ضوضاء + تحكم تلقائي بالمكسب —
        // عبر معالجات WebRTC الأصلية على المنصة (Opus is the default codec).
        defaultAudioCaptureOptions: AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
          highPassFilter: true,
          voiceIsolation: true,
          typingNoiseDetection: true,
        ),
      ),
    );

    await room.connect(url, token);

    _room = room;
    _listener = room.createListener();
    _bindEvents();

    // جولة أخذ عينات كل 100ms — مستويات الصوت تحتاج سرعة،
    // والجودة تُقرأ في نفس الجولة (رخيصة — قراءة خاصية).
    _sampleTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _sample();
    });

    return room;
  }

  void _bindEvents() {
    final listener = _listener;
    if (listener == null) return;

    listener
      ..on<RoomReconnectingEvent>((_) {
        if (_disposed) return;
        _emit(_state.copyWith(reconnecting: true, line: CallLine.lost));
      })
      ..on<RoomReconnectedEvent>((_) {
        if (_disposed) return;
        _emit(_state.copyWith(reconnecting: false));
      })
      ..on<RoomDisconnectedEvent>((_) {
        if (_disposed) return;
        _emit(_state.copyWith(line: CallLine.lost));
      })
      ..on<RoomAttemptReconnectEvent>((e) {
        if (_disposed) return;
        // إعادة الاتصال قيد التنفيذ — الواجهة تعرض "جارٍ الاستعادة…"
        _emit(_state.copyWith(reconnecting: true));
      })
      ..on<ParticipantConnectedEvent>((_) {
        onPeerJoined?.call();
      })
      ..on<ParticipantDisconnectedEvent>((_) {
        onPeerLeft?.call();
      });
  }

  void _sample() {
    final room = _room;
    if (room == null || _disposed) return;

    // جودة الطرف الآخر أولاً — هي ما يسمعه المستخدم.
    ConnectionQuality? peerQuality;
    double peerLevel = 0;
    for (final p in room.remoteParticipants.values) {
      peerQuality = p.connectionQuality;
      peerLevel = p.audioLevel;
      break;
    }
    final line = _lineFromQuality(
      peerQuality ?? room.localParticipant?.connectionQuality,
    );

    // تنعيم أسي — يرتفع فوراً ويخبو بلطف.
    final rawMic = room.localParticipant?.audioLevel ?? 0;
    final mic = rawMic > _state.micLevel ? rawMic : _state.micLevel * 0.86;
    final peer = peerLevel > _state.peerLevel
        ? peerLevel
        : _state.peerLevel * 0.86;

    _emit(
      _state.copyWith(
        line: line,
        micLevel: mic.clamp(0.0, 1.0),
        peerLevel: peer.clamp(0.0, 1.0),
      ),
    );
  }

  void _emit(CallEngineState state) {
    if (_disposed) return;
    _state = state;
    onState?.call(state);
  }

  Room? get room => _room;

  Future<void> dispose() async {
    _disposed = true;
    _sampleTimer?.cancel();
    await _listener?.dispose();
    await _room?.disconnect();
    _room = null;
  }
}

/// استثناء اتصال مصنّف — تحمله الواجهة لعرض رسالة مناسبة
/// وقرار إعادة المحاولة اليدوية.
class CallConnectException implements Exception {
  const CallConnectException(this.failure, [this.detail = '']);

  final CallFailure failure;
  final String detail;

  String get userMessage => failure.userMessage;

  @override
  String toString() => 'CallConnectException(${failure.name}): $detail';
}
