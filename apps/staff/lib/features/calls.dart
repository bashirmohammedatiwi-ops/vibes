import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart' hide Session;
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../core/shift.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';

class IncomingCallOverlay extends StatefulWidget {
  const IncomingCallOverlay({super.key, required this.call, required this.onDismiss, this.onOpenChat});

  final Map<String, dynamic> call;
  final VoidCallback onDismiss;
  final VoidCallback? onOpenChat;

  @override
  State<IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends State<IncomingCallOverlay> {
  Timer? _pulse;

  @override
  void initState() {
    super.initState();
    strongTap();
    SystemSound.play(SystemSoundType.alert);
    _pulse = Timer.periodic(const Duration(seconds: 2), (_) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    });
  }

  @override
  void dispose() {
    _pulse?.cancel();
    super.dispose();
  }

  Future<void> _accept(BuildContext context) async {
    lightTap();
    try {
      final data = await Api.map('/api/calls/${widget.call['id']}/join', method: 'POST');
      if (!context.mounted) return;
      widget.onDismiss();
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CallRoomScreen(payload: data, caller: widget.call)));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _decline() async {
    lightTap();
    try {
      await Api.send('/api/calls/${widget.call['id']}/decline', method: 'POST');
    } catch (_) {}
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.call['callerName']?.toString() ?? 'زبون';
    final place = widget.call['place']?.toString() ?? 'دعم';
    final phone = widget.call['callerPhone']?.toString();
    return Material(
      color: placeInk,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('مكالمة واردة', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: placeBrass, fontWeight: FontWeight.w800)),
              const SizedBox(height: 24),
              const AudioWaveBars(active: true),
              const SizedBox(height: 24),
              Text(name, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                child: Text(place, style: const TextStyle(color: Colors.white70)),
              ),
              if (phone != null) ...[
                const SizedBox(height: 8),
                Text(phone, textDirection: TextDirection.ltr, style: const TextStyle(color: Colors.white54)),
              ],
              if (widget.call['bookingStatus'] != null) ...[
                const SizedBox(height: 12),
                Text('حجز: ${bookingStatusAr(widget.call['bookingStatus']?.toString())}', style: const TextStyle(color: placeBrass)),
              ],
              const Spacer(),
              if (widget.onOpenChat != null && widget.call['conversationId'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OutlinedButton.icon(
                    onPressed: widget.onOpenChat,
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white30)),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('فتح المحادثة'),
                  ),
                ),
              FilledButton(
                onPressed: () => _accept(context),
                style: FilledButton.styleFrom(backgroundColor: placeSuccess, padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('رد على المكالمة'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _decline,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white30)),
                child: const Text('رفض'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CallRoomScreen extends StatefulWidget {
  const CallRoomScreen({super.key, required this.payload, required this.caller});

  final Map<String, dynamic> payload;
  final Map<String, dynamic> caller;

  @override
  State<CallRoomScreen> createState() => _CallRoomScreenState();
}

enum _StaffCallPhase { connecting, ringing, active }

class _CallRoomScreenState extends State<CallRoomScreen> {
  Room? _room;
  String _quality = 'جيد';
  ConnectionQuality? _cq;
  bool _muted = false;
  bool _speaker = true;
  String? _error;
  _StaffCallPhase _phase = _StaffCallPhase.connecting;
  DateTime? _answeredAt;
  Timer? _tick;
  Timer? _qualityTick;
  Timer? _ringPulse;
  Timer? _statusPoll;

  String get _callId => (widget.payload['callId'] ?? widget.caller['id'])?.toString() ?? '';

  Duration get _elapsed {
    if (_answeredAt == null) return Duration.zero;
    return DateTime.now().difference(_answeredAt!);
  }

  void _markAnswered() {
    if (_answeredAt != null) return;
    _answeredAt = DateTime.now();
    _phase = _StaffCallPhase.active;
    _ringPulse?.cancel();
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _connect();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _answeredAt != null) setState(() {});
    });
    _qualityTick = Timer.periodic(const Duration(seconds: 12), (_) => _reportQuality());
    _statusPoll = Timer.periodic(const Duration(seconds: 2), (_) => _pollCallStatus());
  }

  Future<void> _pollCallStatus() async {
    if (_callId.isEmpty || _answeredAt != null) return;
    try {
      final data = await Api.map('/api/calls/$_callId');
      if (data['status'] == 'ACTIVE') _markAnswered();
    } catch (_) {}
  }

  Future<void> _reportQuality() async {
    final callId = widget.payload['callId'] ?? widget.caller['id'];
    if (callId == null || _cq == null) return;
    final packetLoss = switch (_cq!) {
      ConnectionQuality.lost => 22.0,
      ConnectionQuality.poor => 9.0,
      ConnectionQuality.good => 2.5,
      ConnectionQuality.excellent => 0.8,
      _ => 2.0,
    };
    final rtt = switch (_cq!) {
      ConnectionQuality.lost => 320,
      ConnectionQuality.poor => 180,
      ConnectionQuality.good => 90,
      ConnectionQuality.excellent => 45,
      _ => 90,
    };
    try {
      await Api.send('/api/calls/$callId/quality', method: 'POST', body: {
        'packetLossPct': packetLoss,
        'rttMs': rtt,
      });
    } catch (_) {}
  }

  Future<void> _connect() async {
    final url = widget.payload['url'] as String?;
    final token = widget.payload['token'] as String?;
    if (url == null || token == null) {
      setState(() => _error = 'تعذّر تهيئة الصوت');
      return;
    }
    try {
      final room = Room();
      await room.connect(url, token);
      await room.localParticipant?.setMicrophoneEnabled(true);
      try {
        await AudioManager.instance.setSpeakerOutputPreferred(true);
      } catch (_) {}
      room.addListener(_onRoom);
      final hasPeer = room.remoteParticipants.isNotEmpty;
      if (hasPeer) _markAnswered();
      if (mounted) {
        setState(() {
          _room = room;
          _phase = _answeredAt != null ? _StaffCallPhase.active : _StaffCallPhase.ringing;
        });
      }
      if (_answeredAt == null) {
        SystemSound.play(SystemSoundType.alert);
        _ringPulse = Timer.periodic(const Duration(seconds: 2), (_) {
          HapticFeedback.mediumImpact();
          SystemSound.play(SystemSoundType.alert);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر الاتصال — تحقق من الشبكة');
    }
  }

  void _onRoom() {
    if (_room != null && _room!.remoteParticipants.isNotEmpty) {
      _markAnswered();
    }
    final q = _room?.localParticipant?.connectionQuality;
    if (q == null) return;
    _cq = q;
    final label = switch (q) {
      ConnectionQuality.excellent => 'ممتاز',
      ConnectionQuality.good => 'جيد',
      ConnectionQuality.poor => 'ضعيف — اقترب من النافذة',
      ConnectionQuality.lost => 'نعيد الربط…',
      _ => 'جيد',
    };
    if (mounted) setState(() => _quality = label);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _toggleMute() async {
    _muted = !_muted;
    await _room?.localParticipant?.setMicrophoneEnabled(!_muted);
    lightTap();
    setState(() {});
  }

  Future<void> _toggleSpeaker() async {
    _speaker = !_speaker;
    try {
      await AudioManager.instance.setSpeakerOutputPreferred(_speaker);
    } catch (_) {}
    lightTap();
    setState(() {});
  }

  Future<void> _openPhone(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWhatsApp(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _end() async {
    await _room?.disconnect();
    final callId = widget.payload['callId'] ?? widget.caller['id'];
    try {
      await Api.send('/api/calls/$callId/end', method: 'POST');
    } catch (_) {}
    if (!mounted) return;
    final tag = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('تغليف المكالمة', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ),
            for (final item in ['تم الحل', 'يحتاج متابعة', 'حجز', 'دفع'])
              ListTile(
                title: Text(item, style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(context, item),
              ),
            ListTile(title: const Text('تخطي'), onTap: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
    final conversationId = widget.payload['conversationId'] ?? widget.caller['conversationId'];
    if (tag != null && tag.isNotEmpty && conversationId != null && Session.can('inbox.note')) {
      await Api.send('/api/staff/inbox/$conversationId/note', method: 'POST', body: {
        'staffNote': '$tag · ${Session.displayName}',
        'followUp': tag == 'يحتاج متابعة',
      });
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _tick?.cancel();
    _qualityTick?.cancel();
    _ringPulse?.cancel();
    _statusPoll?.cancel();
    _room?.removeListener(_onRoom);
    _room?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.caller['callerName']?.toString() ?? 'زبون';
    final phone = widget.caller['callerPhone']?.toString();
    final poor = _cq == ConnectionQuality.poor || _cq == ConnectionQuality.lost;
    final ringing = _phase != _StaffCallPhase.active;
    final statusLine = _error ??
        switch (_phase) {
          _StaffCallPhase.connecting => 'جارٍ الاتصال…',
          _StaffCallPhase.ringing => 'يرنّ الآن…',
          _StaffCallPhase.active => _formatDuration(_elapsed),
        };
    return Scaffold(
      backgroundColor: placeInk,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: poor ? placeDanger.withValues(alpha: 0.2) : (ringing ? placeBrass.withValues(alpha: 0.25) : placeSuccess.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      ringing ? 'رنين' : (_error ?? _quality),
                      style: TextStyle(color: ringing ? placeBrass : (poor ? placeDanger : placeSuccess), fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Spacer(),
                  if (!ringing)
                    Text(_formatDuration(_elapsed), style: const TextStyle(color: Colors.white54, fontFeatures: [FontFeature.tabularFigures()])),
                ],
              ),
              const SizedBox(height: 32),
              Text(name, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(widget.caller['place']?.toString() ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
              const SizedBox(height: 12),
              Text(
                statusLine,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ringing ? placeBrass : Colors.white70,
                  fontSize: ringing ? 22 : 16,
                  fontWeight: FontWeight.w800,
                  fontFeatures: ringing ? null : const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 24),
              AudioWaveBars(active: ringing || !_muted, color: placeBrass),
              const Spacer(),
              if (Session.can('users.read') && phone != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RoundAction(icon: Icons.phone_outlined, label: 'اتصال', onTap: () => _openPhone(phone)),
                    const SizedBox(width: 12),
                    _RoundAction(icon: Icons.chat_outlined, label: 'واتساب', onTap: () => _openWhatsApp(phone)),
                  ],
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _CallControl(icon: _muted ? Icons.mic_off : Icons.mic, label: _muted ? 'كتم' : 'ميك', onTap: _toggleMute)),
                  Expanded(child: _CallControl(icon: _speaker ? Icons.volume_up : Icons.hearing, label: _speaker ? 'سماعة' : 'أذن', onTap: _toggleSpeaker)),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _end,
                style: FilledButton.styleFrom(backgroundColor: placeDanger, padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('إنهاء المكالمة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _CallControl extends StatelessWidget {
  const _CallControl({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(height: 6),
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
