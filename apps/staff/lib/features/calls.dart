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
import '../widgets/kit.dart';
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
    final booking = widget.call['bookingStatus']?.toString();
    return Material(
      color: placeNavy,
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: placeNavyFill),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LiveDot(color: placeGold),
                    SizedBox(width: 8),
                    Text('مكالمة واردة', style: TextStyle(fontFamily: 'Cairo', color: placeGold, fontSize: 15, fontWeight: FontWeight.w900)),
                  ],
                ),
                const Spacer(flex: 2),
                Center(child: _CallAvatar(name: name, ringing: true)),
                const SizedBox(height: 20),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, height: 1.3),
                ),
                if (phone != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    phone,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontFamily: 'Montserrat', color: Colors.white60, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DarkChip(icon: Icons.home_work_outlined, label: place),
                    if (booking != null) _DarkChip(icon: Icons.event_note_outlined, label: 'حجز: ${bookingStatusAr(booking)}', color: placeGold),
                  ],
                ),
                const SizedBox(height: 28),
                const AudioWaveBars(active: true),
                const Spacer(flex: 3),
                if (widget.onOpenChat != null && widget.call['conversationId'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: widget.onOpenChat,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: .08),
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 19),
                        label: const Text('فتح المحادثة'),
                      ),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _RoundButton(
                      icon: Icons.call_end_rounded,
                      label: 'رفض',
                      color: placeDanger,
                      onTap: _decline,
                    ),
                    _RoundButton(
                      icon: Icons.call_rounded,
                      label: 'رد',
                      color: placeSuccess,
                      onTap: () => _accept(context),
                    ),
                  ],
                ),
              ],
            ),
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
    final tag = await showStaffSheet<String>(
      context,
      title: 'تغليف المكالمة',
      child: Builder(
        builder: (sheet) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('كيف انتهت المكالمة؟ تُحفظ كملاحظة على المحادثة.', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: placeInk2)),
            const SizedBox(height: 12),
            TileGroup(
              children: [
                for (final item in const [
                  ('تم الحل', Icons.check_circle_outline_rounded, placeSuccess),
                  ('يحتاج متابعة', Icons.update_rounded, placeWarning),
                  ('حجز', Icons.event_available_rounded, placeInfo),
                  ('دفع', Icons.payments_outlined, placeBrass),
                ])
                  TaskTile(
                    icon: item.$2,
                    color: item.$3,
                    title: item.$1,
                    trailing: const SizedBox.shrink(),
                    onTap: () => Navigator.pop(sheet, item.$1),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () => Navigator.pop(sheet), child: const Text('تخطي')),
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
    final place = widget.caller['place']?.toString() ?? '';
    final poor = _cq == ConnectionQuality.poor || _cq == ConnectionQuality.lost;
    final ringing = _phase != _StaffCallPhase.active;
    final statusLine = _error ??
        switch (_phase) {
          _StaffCallPhase.connecting => 'جارٍ الاتصال…',
          _StaffCallPhase.ringing => 'يرنّ الآن…',
          _StaffCallPhase.active => _formatDuration(_elapsed),
        };
    final chipColor = _error != null || poor ? placeDanger : (ringing ? placeGold : placeSuccess);
    return Scaffold(
      backgroundColor: placeNavy,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: placeNavyFill),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: chipColor.withValues(alpha: .18), borderRadius: BorderRadius.circular(999)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LiveDot(color: chipColor),
                          const SizedBox(width: 6),
                          Text(
                            ringing ? 'رنين' : (_error ?? 'الاتصال: $_quality'),
                            style: TextStyle(fontFamily: 'Cairo', color: chipColor, fontWeight: FontWeight.w800, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (!ringing)
                      Text(
                        _formatDuration(_elapsed),
                        style: const TextStyle(fontFamily: 'Montserrat', color: Colors.white60, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                  ],
                ),
                const Spacer(flex: 2),
                Center(child: _CallAvatar(name: name, ringing: ringing)),
                const SizedBox(height: 20),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, height: 1.3),
                ),
                if (place.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Center(child: _DarkChip(icon: Icons.home_work_outlined, label: place)),
                ],
                const SizedBox(height: 14),
                Text(
                  statusLine,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: ringing ? 'Cairo' : 'Montserrat',
                    color: _error != null ? placeDanger : (ringing ? placeGold : Colors.white),
                    fontSize: ringing ? 20 : 30,
                    fontWeight: FontWeight.w800,
                    fontFeatures: ringing ? null : const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 20),
                AudioWaveBars(active: ringing || !_muted, color: placeGold),
                const Spacer(flex: 3),
                if (Session.can('users.read') && phone != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PillAction(icon: Icons.phone_outlined, label: 'اتصال هاتفي', onTap: () => _openPhone(phone)),
                      const SizedBox(width: 10),
                      _PillAction(icon: Icons.chat_outlined, label: 'واتساب', onTap: () => _openWhatsApp(phone)),
                    ],
                  ),
                  const SizedBox(height: 28),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ToggleControl(
                      icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      label: _muted ? 'مكتوم' : 'كتم',
                      active: _muted,
                      onTap: _toggleMute,
                    ),
                    _RoundButton(icon: Icons.call_end_rounded, label: 'إنهاء', color: placeDanger, onTap: _end),
                    _ToggleControl(
                      icon: _speaker ? Icons.volume_up_rounded : Icons.hearing_rounded,
                      label: _speaker ? 'السماعة' : 'الأذن',
                      active: _speaker,
                      onTap: _toggleSpeaker,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// صورة المتصل بالأحرف الأولى مع حلقة ذهبية نابضة أثناء الرنين.
class _CallAvatar extends StatefulWidget {
  const _CallAvatar({required this.name, this.ringing = false});

  final String name;
  final bool ringing;

  @override
  State<_CallAvatar> createState() => _CallAvatarState();
}

class _CallAvatarState extends State<_CallAvatar> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    if (widget.ringing) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant _CallAvatar old) {
    super.didUpdateWidget(old);
    if (widget.ringing && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.ringing && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String get _initials {
    final parts = widget.name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '؟';
    if (parts.length == 1) return parts.first.characters.first;
    return '${parts.first.characters.first}${parts.last.characters.first}';
  }

  @override
  Widget build(BuildContext context) {
    const size = 112.0;
    return SizedBox(
      width: size + 48,
      height: size + 48,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = _c.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.ringing)
                Container(
                  width: size + 48 * t,
                  height: size + 48 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: placeGold.withValues(alpha: (1 - t) * .55), width: 2),
                  ),
                ),
              child!,
            ],
          );
        },
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: .08),
            border: Border.all(color: placeGold.withValues(alpha: .7), width: 2),
          ),
          child: Text(
            _initials,
            style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, height: 1.2),
          ),
        ),
      ),
    );
  }
}

/// نقطة حالة صغيرة.
class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}

/// شارة على الخلفية الداكنة.
class _DarkChip extends StatelessWidget {
  const _DarkChip({required this.icon, required this.label, this.color = Colors.white70});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Cairo', color: color, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// زر دائري كبير (رد / رفض / إنهاء).
class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          elevation: 6,
          shadowColor: color.withValues(alpha: .5),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 72, height: 72, child: Icon(icon, color: Colors.white, size: 32)),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

/// زر تبديل دائري (كتم / سماعة).
class _ToggleControl extends StatelessWidget {
  const _ToggleControl({required this.icon, required this.label, required this.onTap, this.active = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: active ? Colors.white : Colors.white.withValues(alpha: .1),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(width: 60, height: 60, child: Icon(icon, color: active ? placeNavy : Colors.white, size: 26)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// زر كبسولة على الخلفية الداكنة (اتصال هاتفي / واتساب).
class _PillAction extends StatelessWidget {
  const _PillAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .08),
      shape: StadiumBorder(side: BorderSide(color: Colors.white.withValues(alpha: .12))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 19),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
