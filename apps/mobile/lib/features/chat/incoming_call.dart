import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/vibes_net_image.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/vibes_graphics.dart';
import '../auth/auth_controller.dart';
import 'call_screen.dart';

/// مكالمة ترنّ الآن للمستخدم الحالي
class IncomingCall {
  const IncomingCall({
    required this.id,
    required this.conversationId,
    required this.place,
    required this.callerName,
    required this.createdAt,
    required this.expiresInSeconds,
  });

  factory IncomingCall.fromJson(Map<String, dynamic> j) {
    final call = (j['call'] ?? const {}) as Map;
    if (call.isEmpty) throw const FormatException('no ringing call');
    return IncomingCall(
      id: call['id'] as String,
      conversationId: call['conversationId'] as String? ?? '',
      place: (call['place'] as String? ?? 'مكالمة'.tr).tr,
      callerName: call['callerName'] as String? ?? I18n.appName,
      createdAt: DateTime.tryParse('${call['createdAt']}') ?? DateTime.now(),
      expiresInSeconds: (call['expiresInSeconds'] as num?)?.toInt() ?? 45,
    );
  }

  final String id;
  final String conversationId;
  final String place;
  final String callerName;
  final DateTime createdAt;
  final int expiresInSeconds;
}

/// مراقب المكالمات الواردة — يستطلع الخادم كل 4 ثوانٍ أما التطبيق نشط،
/// ويُبقي آخر مكالمة رنّت حتى يقبلها المستخدم أو تنتهي مهلتها.
final incomingCallProvider =
    NotifierProvider<IncomingCallNotifier, IncomingCall?>(
      IncomingCallNotifier.new,
    );

class IncomingCallNotifier extends Notifier<IncomingCall?> {
  Timer? _timer;
  bool _busy = false;

  @override
  IncomingCall? build() {
    ref.onDispose(() => _timer?.cancel());
    ref.listen(authControllerProvider, (prev, next) {
      if (next.loggedIn) {
        start();
      } else {
        stop();
      }
    });
    if (ref.read(authControllerProvider).loggedIn) {
      scheduleMicrotask(start);
    }
    return null;
  }

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
    scheduleMicrotask(_poll);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    state = null;
  }

  /// يوقف المراقبة أثناء مكالمة جارية حتى لا يرنّ الغطاء فوقها
  void suppress() => _timer?.cancel();

  void resume() {
    if (_timer == null && ref.read(authControllerProvider).loggedIn) start();
  }

  Future<void> _poll() async {
    if (_busy || !isAppResumed) return;
    // ضيف أو جلسة منتهية — لا طلبات محمية (كانت تولّد 401 متكرراً)
    if (!ref.read(authControllerProvider).loggedIn) return;
    _busy = true;
    try {
      final data = await ref.read(apiClientProvider).get('/api/calls/incoming');
      final next = IncomingCall.fromJson(data as Map<String, dynamic>);
      final current = state;
      if (current?.id != next.id) {
        HapticFeedback.heavyImpact();
        // نبضات متكررة طوال الرنين
        for (var i = 0; i < 3; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 700));
          HapticFeedback.lightImpact();
        }
      }
      state = next;
    } catch (_) {
      // لا مكالمة ترنّ — نظف الحالة
      if (state != null) state = null;
    } finally {
      _busy = false;
    }
  }

  /// يُستدعى بعد قبول/رفض الغطاء — يوقف الرنين ويعيد المراقبة بعد حين
  void handled() {
    suppress();
    state = null;
    Timer(const Duration(seconds: 5), resume);
  }
}

/// غطاء المكالمة الواردة — ملء الشاشة بهوية VIBES:
/// منتصف الليل، مونوغرام نابض، قبول نحاسي ورفض هادئ.
class IncomingCallSheet extends ConsumerWidget {
  const IncomingCallSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.watch(incomingCallProvider);
    if (call == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: Vibes.midnightFill),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(),
                const _RingPulse(),
                const SizedBox(height: 26),
                Text(
                  call.callerName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'مكالمة صوتية · {place}'.trArgs({'place': call.place}),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                MaisonKicker(
                  'مكالمة {app}'.trArgs({'app': I18n.appName}),
                  light: true,
                  color: Vibes.tealBright,
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CallChoice(
                      icon: Icons.call_end_rounded,
                      label: 'رفض'.tr,
                      color: const Color(0xFFC2402F),
                      onTap: () {
                        final notifier = ref.read(
                          incomingCallProvider.notifier,
                        );
                        final call = ref.read(incomingCallProvider);
                        notifier.handled();
                        if (call != null) declineCall(ref, call.id);
                      },
                    ),
                    _CallChoice(
                      icon: Icons.call_rounded,
                      label: 'قبول'.tr,
                      color: Vibes.teal,
                      iconColor: themed(Colors.white, Vibes.onTeal),
                      onTap: () {
                        final notifier = ref.read(
                          incomingCallProvider.notifier,
                        );
                        final call = ref.read(incomingCallProvider);
                        notifier.handled();
                        if (call != null) joinCall(ref, context, call.id);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 42),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPulse extends StatefulWidget {
  const _RingPulse();

  @override
  State<_RingPulse> createState() => _RingPulseState();
}

class _RingPulseState extends State<_RingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
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
      return Opacity(
        opacity: .6,
        child: VibesMonogram(size: 120, color: Vibes.teal),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (final delay in const [0.0, 0.33, 0.66])
                () {
                  final local = ((t - delay) % 1.0).clamp(0.0, 1.0);
                  return Transform.scale(
                    scale: 0.55 + local * 0.75,
                    child: Opacity(
                      opacity: (1 - local) * 0.35,
                      child: CircleAvatar(
                        backgroundColor: Vibes.teal,
                        radius: 70,
                      ),
                    ),
                  );
                }(),
              VibesMonogram(size: 92, color: Vibes.tealBright, strokeWidth: 3),
            ],
          ),
        );
      },
    );
  }
}

class _CallChoice extends StatelessWidget {
  const _CallChoice({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: ShapeDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: .85), color],
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadiusDirectional.only(
                  topEnd: Radius.circular(12),
                  topStart: Radius.circular(18),
                  bottomStart: Radius.circular(12),
                  bottomEnd: Radius.circular(16),
                ),
                side: BorderSide(color: Color(0x66FFFFFF)),
              ),
              shadows: [
                BoxShadow(
                  color: color.withValues(alpha: .45),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 34),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
