import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../auth/auth_controller.dart';

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
    final data = await ref.read(apiClientProvider).post(
      '/api/conversations/property',
      body: {'propertyId': propertyId},
    );
    final id = (data as Map<String, dynamic>)['id'] as String?;
    if (!context.mounted || id == null) return;
    context.push('/chat/$id');
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(maisonError(e))));
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
    final data = await ref.read(apiClientProvider).post(
      '/api/calls',
      body: {
        if (propertyId != null) 'propertyId': propertyId,
        if (conversationId != null) 'conversationId': conversationId,
        if (bookingId != null) 'bookingId': bookingId,
      },
    ) as Map<String, dynamic>;
    if (!context.mounted) return;
    context.push('/call', extra: data);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(maisonError(e))));
  }
}

Future<void> joinCall(WidgetRef ref, BuildContext context, String callId) async {
  try {
    final data = await ref.read(apiClientProvider).post('/api/calls/$callId/join')
        as Map<String, dynamic>;
    if (!context.mounted) return;
    context.push('/call', extra: data);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(maisonError(e))));
  }
}

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key, required this.payload});

  final Map<String, dynamic> payload;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  Room? _room;
  Timer? _tick;
  bool _muted = false;
  bool _failed = false;
  DateTime? _connectedAt;

  String get _callId => widget.payload['callId'] as String? ?? '';
  String get _place => widget.payload['place'] as String? ?? 'مكالمة';
  String get _peer => widget.payload['peerName'] as String? ?? '';

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    final url = widget.payload['url'] as String?;
    final token = widget.payload['token'] as String?;
    if (url == null || token == null) {
      setState(() => _failed = true);
      return;
    }
    final room = Room();
    try {
      await room.connect(url, token);
      await room.localParticipant?.setMicrophoneEnabled(true);
      if (!mounted) {
        await room.disconnect();
        return;
      }
      setState(() {
        _room = room;
        _connectedAt = DateTime.now();
      });
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
      await room.disconnect();
    }
  }

  Future<void> _hangUp() async {
    try {
      if (_callId.isNotEmpty) {
        await ref.read(apiClientProvider).post('/api/calls/$_callId/end');
      }
    } catch (_) {}
    await _room?.disconnect();
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _room?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _connectedAt == null
        ? 'جارٍ الاتصال'
        : _clock(DateTime.now().difference(_connectedAt!));
    return Scaffold(
      backgroundColor: VibesDark.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            children: [
              const VibesLogo.mark(size: 42),
              const SizedBox(height: 18),
              Text(
                _place,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              if (_peer.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  _peer,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              Text(
                _failed ? 'تعذر الاتصال' : elapsed,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Vibes.tealBright,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RoundAction(
                    icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    label: _muted ? 'تشغيل' : 'كتم',
                    onTap: _room == null
                        ? null
                        : () async {
                            final next = !_muted;
                            await _room!.localParticipant?.setMicrophoneEnabled(!next);
                            if (mounted) setState(() => _muted = next);
                          },
                  ),
                  const SizedBox(width: 28),
                  _RoundAction(
                    icon: Icons.call_end_rounded,
                    label: 'إنهاء',
                    danger: true,
                    onTap: _hangUp,
                  ),
                ],
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
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          FolioPanel(
            color: danger ? Vibes.danger : VibesDark.surface,
            borderColor: danger ? Vibes.danger : Vibes.teal,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Icon(icon, color: Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
