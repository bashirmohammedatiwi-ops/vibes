import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_graphics.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../auth/auth_controller.dart';
import 'call_engine.dart';
import 'incoming_call.dart';

Future<bool> _ensureLogin(WidgetRef ref, BuildContext context) async {
  if (ref.read(authControllerProvider).loggedIn) return true;
  await context.push<bool>('/login');
  return ref.read(authControllerProvider).loggedIn;
}

Future<void> openPropertyChat(
  WidgetRef ref,
  BuildContext context,
  String propertyId,
) async {
  if (!await _ensureLogin(ref, context) || !context.mounted) return;
  try {
    final data = await ref
        .read(apiClientProvider)
        .post('/api/conversations/property', body: {'propertyId': propertyId});
    final id = (data as Map<String, dynamic>)['id'] as String?;
    if (!context.mounted || id == null) return;
    context.push('/chat/$id');
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(maisonError(e))));
  }
}

Future<void> startCall(
  WidgetRef ref,
  BuildContext context, {
  String? propertyId,
  String? conversationId,
  String? bookingId,
}) async {
  if (!await _ensureLogin(ref, context) || !context.mounted) return;
  try {
    final data =
        await ref
                .read(apiClientProvider)
                .post(
                  '/api/calls',
                  body: {
                    if (propertyId != null) 'propertyId': propertyId,
                    if (conversationId != null)
                      'conversationId': conversationId,
                    if (bookingId != null) 'bookingId': bookingId,
                  },
                )
            as Map<String, dynamic>;
    if (!context.mounted) return;
    context.push('/call', extra: data);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(maisonError(e))));
  }
}

Future<void> joinCall(
  WidgetRef ref,
  BuildContext context,
  String callId,
) async {
  try {
    final data =
        await ref.read(apiClientProvider).post('/api/calls/$callId/join')
            as Map<String, dynamic>;
    if (!context.mounted) return;
    context.push('/call', extra: data);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(maisonError(e))));
  }
}

/// يرفض المكالمة الواردة — يسجّلها فائتة عند الخادم
Future<void> declineCall(WidgetRef ref, String callId) async {
  try {
    await ref.read(apiClientProvider).post('/api/calls/$callId/decline');
  } catch (_) {}
}

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key, required this.payload});

  final Map<String, dynamic> payload;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

enum _CallPhase { connecting, waiting, dialing, active, ended, failed }

class _CallScreenState extends ConsumerState<CallScreen> {
  Room? _room;
  CallEngine? _engine;
  CallEngineState _engineState = const CallEngineState();
  Timer? _tick;
  StreamSubscription<List<int>>? _convSse;
  bool _muted = false;
  bool _speaker = false;
  _CallPhase _phase = _CallPhase.connecting;
  String _endNote = '';
  String _queueLabel = 'نبحث عن موظف';
  DateTime? _connectedAt;
  Map<String, dynamic> _live = {};

  String get _callId => widget.payload['callId'] as String? ?? '';
  String get _place => widget.payload['place'] as String? ?? 'مكالمة';
  String get _peer => widget.payload['peerName'] as String? ?? '';
  bool get _isCaller => widget.payload['role'] != 'callee';

  @override
  void initState() {
    super.initState();
    // أوقف مراقب الرنين أثناء المكالمة، وعُد بعدها
    ref.read(incomingCallProvider.notifier).suppress();
    _live = Map<String, dynamic>.from(widget.payload);
    _connect();
    _watchConversationEvents();
  }

  Future<void> _watchConversationEvents() async {
    final convId = _live['conversationId'] as String?;
    if (convId == null || convId.isEmpty || _callId.isEmpty) return;
    try {
      final res = await ref
          .read(apiClientProvider)
          .dio
          .get<ResponseBody>(
            '/api/conversations/$convId/stream',
            options: Options(
              responseType: ResponseType.stream,
              headers: const {'Accept': 'text/event-stream'},
              receiveTimeout: const Duration(minutes: 30),
            ),
          );
      final stream = res.data?.stream;
      if (stream == null) return;
      await _convSse?.cancel();
      _convSse = stream.listen((chunk) {
        if (!mounted) return;
        final text = String.fromCharCodes(chunk);
        if (text.contains('call-answered') && text.contains(_callId)) {
          if (_phase == _CallPhase.dialing || _phase == _CallPhase.waiting) {
            setState(() {
              _phase = _CallPhase.active;
              _connectedAt = DateTime.now();
            });
          }
        }
        if (text.contains('call-ended') &&
            text.contains(_callId) &&
            _phase != _CallPhase.ended) {
          _hangUp(auto: true, note: 'انتهت المكالمة');
        }
      });
    } catch (_) {}
  }

  Future<void> _pollQueue() async {
    if (!mounted) return;
    setState(() => _phase = _CallPhase.waiting);
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted || _callId.isEmpty) return;
      try {
        final data =
            await ref.read(apiClientProvider).get('/api/calls/$_callId')
                as Map<String, dynamic>;
        final status = data['status'] as String?;
        final queue = data['queue'] as String?;
        if (status == 'MISSED' || queue == 'ABANDONED') {
          _tick?.cancel();
          if (mounted) {
            setState(() {
              _phase = _CallPhase.failed;
              _endNote = 'الفريق مشغول — أرسل رسالة';
            });
          }
          return;
        }
        if (queue == 'OFFERED') {
          if (mounted) setState(() => _queueLabel = 'جارٍ التوصيل');
        }
        final token = data['token'] as String?;
        final url = data['url'] as String?;
        if (token != null && url != null) {
          _tick?.cancel();
          _live = {..._live, ...data};
          await _connect();
        }
      } catch (_) {}
    });
  }

  Future<void> _connect() async {
    final url = _live['url'] as String?;
    final token = _live['token'] as String?;
    if (url == null || token == null) {
      if (_tick == null) await _pollQueue();
      return;
    }
    final engine = CallEngine(
      onState: (s) {
        if (mounted) setState(() => _engineState = s);
      },
      onPeerJoined: _onRoomChanged,
      onPeerLeft: _onRoomChanged,
      onFailure: (failure, _) {
        // رسالة فشل مفهومة — يعرضها الطور failed بدل تحذير تقني
        if (mounted) setState(() => _endNote = failure.userMessage);
      },
    );
    try {
      final room = await engine.connect(url, token);
      await room.localParticipant?.setMicrophoneEnabled(true);
      if (!mounted) {
        await engine.dispose();
        return;
      }
      _engine = engine;

      // المتصل يدخل غرفة فارغة وينتظر — المتلقّي دخوله يعني «أجاب»
      final peerJoined = room.remoteParticipants.isNotEmpty;
      setState(() {
        _room = room;
        _phase = peerJoined ? _CallPhase.active : _CallPhase.dialing;
        _connectedAt = peerJoined ? DateTime.now() : null;
      });

      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _phase == _CallPhase.active) setState(() {});
      });

      room.addListener(_onRoomChanged);
      _onRoomChanged();

      // مهلة رنين المتصل — لا أحد أجاب خلال 45 ثانية
      if (!peerJoined && _isCaller) {
        Timer(const Duration(seconds: 46), () {
          if (mounted && _phase == _CallPhase.dialing) {
            _hangUp(auto: true, note: 'لا رد على المكالمة');
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _phase = _CallPhase.failed);
      await engine.dispose();
    }
  }

  void _onRoomChanged() {
    final room = _room;
    if (room == null || !mounted) return;
    final hasPeer = room.remoteParticipants.isNotEmpty;

    if (hasPeer && _phase != _CallPhase.active) {
      HapticFeedback.mediumImpact();
      setState(() {
        _phase = _CallPhase.active;
        _connectedAt = DateTime.now();
      });
    }
  }

  Future<void> _hangUp({
    bool auto = false,
    String note = 'انتهت المكالمة',
  }) async {
    if (_phase == _CallPhase.ended) return;
    setState(() {
      _phase = _CallPhase.ended;
      _endNote = note;
    });
    try {
      if (_callId.isNotEmpty) {
        await ref.read(apiClientProvider).post('/api/calls/$_callId/end');
      }
    } catch (_) {}
    await _engine?.dispose();
    if (!mounted) return;
    // لحظة وداع قصيرة قبل العودة — تمنع الوميض الفج
    Timer(const Duration(milliseconds: 900), () {
      if (mounted) context.pop();
    });
  }

  void _toggleMute() async {
    final room = _room;
    if (room == null) return;
    final next = !_muted;
    await room.localParticipant?.setMicrophoneEnabled(!next);
    HapticFeedback.selectionClick();
    if (mounted) setState(() => _muted = next);
  }

  void _toggleSpeaker() async {
    final room = _room;
    if (room == null) return;
    final next = !_speaker;
    try {
      await AudioManager.instance.setSpeakerOutputPreferred(next);
    } catch (_) {
      // المنصة لا تدعم التبديل — نتجاهل بصمت
    }
    HapticFeedback.selectionClick();
    if (mounted) setState(() => _speaker = next);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _convSse?.cancel();
    _room?.removeListener(_onRoomChanged);
    _engine?.dispose();
    ref.read(incomingCallProvider.notifier).resume();
    super.dispose();
  }

  String get _statusLine => switch (_phase) {
    _CallPhase.connecting => 'جارٍ الاتصال…',
    _CallPhase.waiting => _queueLabel,
    _CallPhase.dialing => _isCaller ? 'يرنّ الآن…' : 'جارٍ الربط…',
    _CallPhase.active => _clock(
      DateTime.now().difference(_connectedAt ?? DateTime.now()),
    ),
    _CallPhase.ended => _endNote,
    _CallPhase.failed => 'تعذّر الاتصال — تحقق من الشبكة والصلاحيات',
  };

  @override
  Widget build(BuildContext context) {
    final busy =
        _phase == _CallPhase.connecting ||
        _phase == _CallPhase.waiting ||
        _phase == _CallPhase.dialing;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: Vibes.midnightFill),
        child: SafeArea(
          child: Stack(
            children: [
              // مونوغرام مائي نابض أثناء الرنين، ويتنفس بصوت المتحدث في المكالمة
              if (busy) Center(child: _PulseMonogram(active: true)),
              if (_phase == _CallPhase.active)
                Center(
                  child: IgnorePointer(
                    child: AnimatedScale(
                      scale: 1 + (_engineState.micLevel.clamp(0.0, 1.0) * 0.35),
                      duration: const Duration(milliseconds: 110),
                      curve: Curves.easeOut,
                      child: Opacity(
                        opacity:
                            .08 + _engineState.peerLevel.clamp(0.0, 1.0) * 0.12,
                        child: const VibesMonogram(
                          size: 260,
                          color: Vibes.tealBright,
                        ),
                      ),
                    ),
                  ),
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
                  child: Column(
                    children: [
                      const VibesLogo.mark(size: 40),
                      const SizedBox(height: 20),
                      Text(
                        _peer.isEmpty ? _place : _peer,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _peer.isEmpty ? '' : _place,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      AnimatedSwitcher(
                        duration: VibesMotion.base,
                        child: Text(
                          _engineState.reconnecting
                              ? 'انقطع الاتصال — جارٍ الاستعادة…'
                              : _statusLine,
                          key: ValueKey(
                            _engineState.reconnecting
                                ? 'reconnecting'
                                : _statusLine,
                          ),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: _phase == _CallPhase.failed
                                    ? const Color(0xFFE8A3A3)
                                    : Vibes.tealBright,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ),
                      // مؤشر جودة الخط الحي
                      if (_phase == _CallPhase.active) ...[
                        const SizedBox(height: 10),
                        _LineIndicator(line: _engineState.line, muted: _muted),
                      ],
                      const Spacer(),
                      if (_phase == _CallPhase.failed)
                        Column(
                          children: [
                            if (_endNote.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  _endNote,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: const Color(0xFFE8A3A3),
                                      ),
                                ),
                              ),
                            VibesButton(
                              label: 'إعادة المحاولة',
                              icon: Icons.refresh_rounded,
                              expanded: false,
                              onPressed: () {
                                setState(() {
                                  _phase = _CallPhase.connecting;
                                  _endNote = '';
                                });
                                _connect();
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                        )
                      else if (_phase != _CallPhase.ended)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _RoundAction(
                              icon: _muted
                                  ? Icons.mic_off_rounded
                                  : Icons.mic_rounded,
                              label: _muted ? 'إلغاء الكتم' : 'كتم',
                              onTap: _phase == _CallPhase.active
                                  ? _toggleMute
                                  : null,
                            ),
                            const SizedBox(width: 26),
                            _RoundAction(
                              icon: Icons.call_end_rounded,
                              label: _isCaller || _phase == _CallPhase.active
                                  ? 'إنهاء'
                                  : 'رفض',
                              danger: true,
                              onTap: _hangUp,
                            ),
                            const SizedBox(width: 26),
                            _RoundAction(
                              icon: _speaker
                                  ? Icons.volume_up_rounded
                                  : Icons.hearing_outlined,
                              label: _speaker ? 'الأذن' : 'السماعة',
                              onTap: _phase == _CallPhase.active
                                  ? _toggleSpeaker
                                  : null,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _clock(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// نبض المونوغرام — طبقتان متعاقبتان تخبوان أثناء الرنين
class _PulseMonogram extends StatefulWidget {
  const _PulseMonogram({required this.active});

  final bool active;

  @override
  State<_PulseMonogram> createState() => _PulseMonogramState();
}

class _PulseMonogramState extends State<_PulseMonogram>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      return const Opacity(
        opacity: .3,
        child: VibesMonogram(size: 150, color: Vibes.teal),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            for (final delay in const [0.0, 0.35])
              () {
                final local = ((t - delay) % 1.0).clamp(0.0, 1.0);
                final scale = 0.7 + local * 0.85;
                final opacity = (1 - local) * 0.28;
                return Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: const VibesMonogram(
                      size: 150,
                      color: Vibes.teal,
                      strokeWidth: 2,
                    ),
                  ),
                );
              }(),
            const Opacity(
              opacity: .55,
              child: VibesMonogram(size: 96, color: Vibes.tealBright),
            ),
          ],
        );
      },
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: VibesMotion.base,
            curve: VibesMotion.curve,
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: danger
                  ? const Color(0xFFC2402F)
                  : (enabled
                        ? Vibes.teal
                        : Colors.white.withValues(alpha: .06)),
              shape: BoxShape.circle,
              border: danger
                  ? null
                  : Border.all(
                      color: enabled
                          ? Vibes.tealBright
                          : Colors.white.withValues(alpha: .12),
                    ),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: (danger ? const Color(0xFFC2402F) : Vibes.teal)
                            .withValues(alpha: .35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              color: enabled ? Colors.white : VibesDark.inkTertiary,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: enabled ? Colors.white : VibesDark.inkTertiary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// مؤشر جودة الخط — أعمدة صغيرة تلتقط اللون حسب الجودة،
/// مع شارة كتم مدمجة عندما يكون الميكروفون مكتوماً.
class _LineIndicator extends StatelessWidget {
  const _LineIndicator({required this.line, required this.muted});

  final CallLine line;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color = switch (line) {
      CallLine.excellent => const Color(0xFF4CAF7D),
      CallLine.good => Vibes.tealBright,
      CallLine.poor => const Color(0xFFE0B15C),
      CallLine.lost => const Color(0xFFE07A6C),
    };

    return AnimatedContainer(
      duration: VibesMotion.base,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // أعمدة الجودة
          for (var i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsetsDirectional.only(end: 2),
              width: 3,
              height: 5.0 + i * 3,
              decoration: BoxDecoration(
                color: i < line.bars
                    ? color
                    : Colors.white.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          const SizedBox(width: 7),
          Text(
            muted ? 'مكتوم · ${line.label}' : line.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: .75),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
