import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/chat_stream.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/shift.dart' show bookingStatusAr;
import '../core/theme.dart';
import '../widgets/chat_ui.dart';
import '../widgets/kit.dart';
import '../widgets/ui.dart' show lightTap;
import 'calls.dart';

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.contactUserId,
    required this.contactName,
    this.contactPhone,
  });

  final String contactUserId;
  final String contactName;
  final String? contactPhone;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  List<Map<String, dynamic>> _messages = [];
  String? _primaryConversationId;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _ops;
  List<dynamic> _bookings = [];
  bool _loading = true;
  Timer? _poll;
  String? _lastCreatedAt;
  ConversationLiveStream? _live;

  @override
  void initState() {
    super.initState();
    _loadThread();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _loadThread(incremental: true, silent: true));
  }

  void _bindLiveStream(String? conversationId) {
    if (conversationId == null || conversationId.isEmpty) return;
    _live?.stop();
    _live = ConversationLiveStream(
      conversationId: conversationId,
      onMessage: _applyLiveMessage,
      onTick: () => _loadThread(incremental: true, silent: true),
    );
    _live!.start();
  }

  void _applyLiveMessage(Map<String, dynamic> raw) {
    if (!mounted) return;
    final id = raw['id']?.toString();
    if (id == null) {
      _loadThread(incremental: true, silent: true);
      return;
    }
    final map = Map<String, dynamic>.from(raw);
    map['threadLabel'] = map['threadLabel'] ?? '';
    setState(() {
      final pendingIdx = _messages.indexWhere(
        (m) => m['pending'] == true && m['body'] == map['body'] && messageFromMe(m),
      );
      if (pendingIdx >= 0) {
        _messages[pendingIdx] = map;
      } else {
        final existing = _messages.indexWhere((m) => m['id'] == id);
        if (existing >= 0) {
          _messages[existing] = map;
        } else {
          _messages.add(map);
        }
      }
      _lastCreatedAt = _messages.where((m) => m['pending'] != true).lastOrNull?['createdAt']?.toString();
    });
    _scrollToEnd();
  }

  Future<void> _loadThread({bool incremental = false, bool silent = false}) async {
    if (!incremental && mounted) setState(() => _loading = true);
    try {
      final after = incremental && _lastCreatedAt != null ? '?after=${Uri.encodeComponent(_lastCreatedAt!)}' : '';
      final data = await Api.map('/api/staff/customers/${widget.contactUserId}/thread$after');
      final primary = data['primaryConversationId']?.toString();
      if (primary != null && primary != _primaryConversationId) {
        _primaryConversationId = primary;
        _bindLiveStream(primary);
      } else {
        _primaryConversationId = primary;
      }
      final statsRaw = data['stats'];
      _stats = statsRaw is Map ? Map<String, dynamic>.from(statsRaw) : null;
      final opsRaw = data['ops'];
      if (opsRaw is Map && !incremental) {
        _ops = Map<String, dynamic>.from(opsRaw);
      }
      _bookings = data['bookings'] as List<dynamic>? ?? [];
      final incoming = (data['messages'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      var changed = false;
      if (incremental && incoming.isNotEmpty) {
        final ids = _messages.map((m) => m['id']).toSet();
        for (final m in incoming) {
          if (!ids.contains(m['id'])) {
            _messages.add(m);
            changed = true;
          }
        }
        // استبدال الرسائل المعلّقة بنفس النص عند وصول النسخة من السيرفر
        for (final server in incoming) {
          final pendingIdx = _messages.indexWhere(
            (m) => m['pending'] == true && m['body'] == server['body'] && messageFromMe(m),
          );
          if (pendingIdx >= 0) {
            _messages[pendingIdx] = server;
            changed = true;
          }
        }
      } else if (!incremental) {
        final pending = _messages.where((m) => m['pending'] == true || m['failed'] == true).toList();
        _messages = [...incoming, ...pending];
        changed = true;
      }

      if (_messages.isNotEmpty) {
        _lastCreatedAt = _messages.where((m) => m['pending'] != true).lastOrNull?['createdAt']?.toString();
      }
      if (mounted && (!silent || changed)) setState(() {});
      if (changed && !incremental) _scrollToEnd();
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (mounted && !incremental) setState(() => _loading = false);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send([String? text]) async {
    if (!Session.can('inbox.reply')) return;
    final convId = _primaryConversationId;
    if (convId == null) return;
    final body = (text ?? _input.text).trim();
    if (body.isEmpty) return;

    final tempId = 'pending-${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = {
      'id': tempId,
      'body': body,
      'kind': 'TEXT',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'senderId': Session.me['id'],
      'pending': true,
      'conversationId': convId,
      'threadLabel': '',
    };

    setState(() {
      _messages.add(optimistic);
      if (text == null) _input.clear();
    });
    lightTap();
    _scrollToEnd();

    try {
      final sent = await Api.send('/api/conversations/$convId/messages', method: 'POST', body: {'body': body});
      if (!mounted) return;
      setState(() {
        final i = _messages.indexWhere((m) => m['id'] == tempId);
        if (i >= 0 && sent is Map) {
          final map = Map<String, dynamic>.from(sent);
          map['threadLabel'] = _messages[i]['threadLabel'] ?? '';
          _messages[i] = map;
        }
        _lastCreatedAt = _messages.where((m) => m['pending'] != true).lastOrNull?['createdAt']?.toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final i = _messages.indexWhere((m) => m['id'] == tempId);
        if (i >= 0) {
          _messages[i] = {..._messages[i], 'pending': false, 'failed': true};
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _attachImage() async {
    final convId = _primaryConversationId;
    if (convId == null || !Session.can('inbox.reply')) return;
    final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (file == null) return;
    try {
      await Api.uploadChatImage(convId, file.path);
      await _loadThread(incremental: true, silent: true);
      _scrollToEnd();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _startCall() async {
    final convId = _primaryConversationId;
    if (convId == null) return;
    if (!Session.can('calls.outbound') && !Session.can('calls.answer')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا صلاحية للاتصال')));
      return;
    }
    try {
      var data = await Api.map('/api/calls', method: 'POST', body: {'conversationId': convId});
      if (data['url'] == null && data['callId'] != null) {
        data = await Api.map('/api/calls/${data['callId']}/join', method: 'POST');
      }
      if (!mounted) return;
      final caller = {
        'callerName': widget.contactName,
        'callerPhone': widget.contactPhone,
        'place': data['place'] ?? '',
        'conversationId': convId,
        'id': data['callId'],
      };
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CallRoomScreen(payload: data, caller: caller)),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _retryFailed(Map<String, dynamic> msg) async {
    final body = msg['body']?.toString() ?? '';
    if (body.isEmpty) return;
    setState(() {
      _messages.removeWhere((m) => m['id'] == msg['id']);
    });
    await _send(body);
  }

  Future<void> _claim() async {
    final id = _primaryConversationId;
    if (id == null) return;
    try {
      await Api.send('/api/conversations/$id/claim', method: 'POST');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تعيين المحادثة لك')));
        await _loadThread();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _setUrgent(bool urgent) async {
    final id = _primaryConversationId;
    if (id == null) return;
    try {
      await Api.send('/api/conversations/$id/ops', method: 'PATCH', body: {
        'priority': urgent ? 'URGENT' : 'NORMAL',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(urgent ? 'عُلّمت كعاجلة' : 'أُزيلت الأولوية')));
        await _loadThread();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _addNote() async {
    final id = _primaryConversationId;
    if (id == null || !Session.can('inbox.note')) return;
    final current = _ops?['staffNote']?.toString();
    final note = await showStaffSheet<String>(
      context,
      title: 'ملاحظة داخلية',
      child: _NoteForm(initial: current),
    );
    if (note == null || note.trim().isEmpty) return;
    try {
      await Api.send('/api/staff/inbox/$id/note', method: 'POST', body: {
        'staffNote': note.trim(),
        'followUp': false,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حُفظت الملاحظة')));
        await _loadThread();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  // ── تواصل خارجي ──
  Future<void> _dialPhone() async {
    final phone = widget.contactPhone;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWhatsApp() async {
    final phone = widget.contactPhone;
    if (phone == null || phone.isEmpty) return;
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _copyPhone() async {
    final phone = widget.contactPhone;
    if (phone == null || phone.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: phone));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نُسخ الرقم')));
  }

  bool get _canCall => Session.can('calls.outbound') || Session.can('calls.answer');
  bool get _urgent => _ops?['priority']?.toString() == 'URGENT';
  String? get _assignedTo => _ops?['assignedToId']?.toString();
  bool get _assignedToMe => _assignedTo != null && _assignedTo == Session.me['id']?.toString();

  void _showTools() {
    final urgent = _urgent;
    final note = _ops?['staffNote']?.toString();
    final hasPhone = widget.contactPhone != null && widget.contactPhone!.isNotEmpty;
    void run(BuildContext sheet, VoidCallback action) {
      Navigator.pop(sheet);
      action();
    }

    showStaffSheet<void>(
      context,
      title: 'أدوات المحادثة',
      child: Builder(
        builder: (sheet) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (note != null && note.isNotEmpty) ...[
                _InternalNoteCard(note: note),
                const SizedBox(height: 12),
              ],
              TileGroup(
                children: [
                  if (Session.can('inbox.reply'))
                    TaskTile(
                      icon: _assignedToMe ? Icons.how_to_reg_rounded : Icons.person_add_alt_1_rounded,
                      color: placeSuccess,
                      title: _assignedToMe ? 'مسندة لك' : 'تعيين لي',
                      subtitle: _assignedToMe ? 'أنت المسؤول عن هذه المحادثة' : 'استلم المحادثة لتكون المسؤول عنها',
                      onTap: () => run(sheet, _claim),
                    ),
                  TaskTile(
                    icon: urgent ? Icons.flag_rounded : Icons.outlined_flag_rounded,
                    color: placeDanger,
                    title: urgent ? 'إلغاء العاجل' : 'تعليم كعاجلة',
                    subtitle: urgent ? 'إعادة الأولوية إلى عادية' : 'تظهر أولاً في الوارد بعلامة حمراء',
                    onTap: () => run(sheet, () => _setUrgent(!urgent)),
                  ),
                  if (Session.can('inbox.note'))
                    TaskTile(
                      icon: Icons.sticky_note_2_outlined,
                      color: placeBrass,
                      title: note != null && note.isNotEmpty ? 'تعديل الملاحظة الداخلية' : 'إضافة ملاحظة داخلية',
                      subtitle: 'تظهر للموظفين فقط',
                      onTap: () => run(sheet, _addNote),
                    ),
                ],
              ),
              if (hasPhone) ...[
                const SizedBox(height: 12),
                TileGroup(
                  children: [
                    if (_canCall)
                      TaskTile(
                        icon: Icons.headset_mic_rounded,
                        color: placeNavyHigh,
                        title: 'مكالمة عبر التطبيق',
                        onTap: () => run(sheet, _startCall),
                      ),
                    TaskTile(
                      icon: Icons.phone_rounded,
                      color: placeSuccess,
                      title: 'اتصال هاتفي',
                      subtitle: widget.contactPhone,
                      onTap: () => run(sheet, _dialPhone),
                    ),
                    TaskTile(
                      icon: Icons.chat_rounded,
                      color: const Color(0xFF25D366),
                      title: 'فتح في واتساب',
                      onTap: () => run(sheet, _openWhatsApp),
                    ),
                    TaskTile(
                      icon: Icons.copy_rounded,
                      color: placeInk2,
                      title: 'نسخ الرقم',
                      onTap: () => run(sheet, _copyPhone),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    _live?.stop();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  PreferredSizeWidget _appBar() {
    final phone = widget.contactPhone;
    return AppBar(
      backgroundColor: Colors.white,
      titleSpacing: 0,
      shape: const Border(bottom: BorderSide(color: placeLine)),
      title: InkWell(
        onTap: _showTools,
        borderRadius: BorderRadius.circular(StaffRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              ContactAvatar(name: widget.contactName, phone: phone, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.contactName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 16, color: placeInk, height: 1.3),
                    ),
                    if (phone != null && phone.isNotEmpty)
                      Text(
                        phone,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: placeInk2, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (_canCall)
          IconButton(
            onPressed: _startCall,
            tooltip: 'مكالمة',
            style: IconButton.styleFrom(backgroundColor: placeSuccess.withValues(alpha: .1)),
            icon: const Icon(Icons.call_rounded, color: placeSuccess),
          )
        else if (phone != null && phone.isNotEmpty)
          IconButton(
            onPressed: _dialPhone,
            tooltip: 'اتصال هاتفي',
            icon: const Icon(Icons.phone_outlined),
          ),
        IconButton(onPressed: _showTools, icon: const Icon(Icons.more_vert_rounded), tooltip: 'أدوات المحادثة'),
        const SizedBox(width: 4),
      ],
    );
  }

  /// شريط الحالة: الإسناد، الأولوية، حالة المحادثة.
  Widget _statusStrip() {
    final status = _ops?['status']?.toString();
    final statusLabel = switch (status) {
      'OPEN' => 'مفتوحة',
      'PENDING' => 'معلّقة',
      'RESOLVED' => 'محلولة',
      'CLOSED' => 'مغلقة',
      _ => null,
    };
    final statusColor = switch (status) {
      'OPEN' => placeInfo,
      'PENDING' => placeWarning,
      _ => placeInk3,
    };
    final assigned = _assignedTo != null;
    final canClaim = Session.can('inbox.reply') && !_assignedToMe && _primaryConversationId != null;
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(StaffSpace.page, 8, StaffSpace.page, 8),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (_urgent) const StatusChip('عاجلة', color: placeDanger, dense: true),
                if (_assignedToMe)
                  const StatusChip('مسندة لك', color: placeSuccess, dense: true)
                else if (assigned)
                  const StatusChip('مسندة لزميل', color: placeInfo, dense: true)
                else
                  const StatusChip('غير مسندة', color: placeWarning, dense: true),
                if (statusLabel != null) StatusChip(statusLabel, color: statusColor, dense: true),
              ],
            ),
          ),
          if (canClaim)
            TextButton.icon(
              onPressed: _claim,
              style: TextButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 10)),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('استلام'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: placePaper,
      appBar: _appBar(),
      body: Column(
        children: [
          if (!_loading) _statusStrip(),
          if (!_loading) const Divider(height: 1),
          Expanded(
            child: _loading
                ? const _ThreadSkeleton()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: _messages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Column(
                          children: [
                            _CustomerContextCard(
                              name: widget.contactName,
                              phone: widget.contactPhone,
                              stats: _stats,
                              bookings: _bookings,
                              staffNote: _ops?['staffNote']?.toString(),
                              onCall: _startCall,
                              onDial: _dialPhone,
                              onWhatsApp: _openWhatsApp,
                              onEditNote: Session.can('inbox.note') ? _addNote : null,
                            ),
                            if (_messages.isEmpty)
                              const EmptyView(
                                icon: Icons.chat_bubble_outline_rounded,
                                title: 'لا رسائل بعد',
                                subtitle: 'ابدأ المحادثة برسالة ترحيب أو رد سريع',
                              ),
                          ],
                        );
                      }
                      final msg = _messages[index - 1];
                      final created = msg['createdAt']?.toString();
                      final dt = created != null ? DateTime.tryParse(created)?.toLocal() : null;
                      final prev = index > 1 ? _messages[index - 2] : null;
                      DateTime? prevDt;
                      if (prev != null && prev['createdAt'] != null) {
                        prevDt = DateTime.tryParse(prev['createdAt'].toString())?.toLocal();
                      }
                      final showDate = dt != null && (prevDt == null || prevDt.day != dt.day || prevDt.month != dt.month || prevDt.year != dt.year);
                      final showThread = prev != null &&
                          msg['conversationId'] != null &&
                          prev['conversationId'] != msg['conversationId'] &&
                          (msg['threadLabel']?.toString() ?? '').isNotEmpty;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showDate) DateSeparator(label: dateSeparatorLabel(dt)),
                          if (showThread) ThreadSeparator(label: msg['threadLabel']?.toString() ?? ''),
                          MessageBubble(
                            message: msg,
                            mine: messageFromMe(msg),
                            onRetry: msg['failed'] == true ? () => _retryFailed(msg) : null,
                          ),
                        ],
                      );
                    },
                  ),
          ),
          if (Session.can('inbox.reply'))
            ChatComposer(
              controller: _input,
              enabled: _primaryConversationId != null || _loading,
              onSend: () => _send(),
              onQuickReply: _send,
              onAttach: _attachImage,
            )
          else
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.visibility_outlined, size: 18, color: placeInk3),
                  SizedBox(width: 8),
                  Text('عرض فقط — لا صلاحية للرد', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700, color: placeInk2)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// ملاحظة داخلية — مميّزة بلون ذهبي وقفل «للموظفين فقط».
class _InternalNoteCard extends StatelessWidget {
  const _InternalNoteCard({required this.note, this.onTap});

  final String note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return StaffCard(
      onTap: onTap,
      color: placeGoldSoft,
      borderColor: placeGold.withValues(alpha: .45),
      radius: StaffRadius.md,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.lock_outline_rounded, size: 18, color: placeBrass),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ملاحظة داخلية · للموظفين فقط', style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.w900, color: placeBrass)),
                const SizedBox(height: 2),
                Text(note, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13.5, fontWeight: FontWeight.w600, color: placeInk, height: 1.5)),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            const Icon(Icons.edit_outlined, size: 17, color: placeBrass),
          ],
        ],
      ),
    );
  }
}

/// بطاقة سياق الزبون أعلى المحادثة: إحصاءات، ملاحظة، حجوزات، وتواصل.
class _CustomerContextCard extends StatefulWidget {
  const _CustomerContextCard({
    required this.name,
    this.phone,
    this.stats,
    required this.bookings,
    this.staffNote,
    required this.onCall,
    required this.onDial,
    required this.onWhatsApp,
    this.onEditNote,
  });

  final String name;
  final String? phone;
  final Map<String, dynamic>? stats;
  final List<dynamic> bookings;
  final String? staffNote;
  final VoidCallback onCall;
  final VoidCallback onDial;
  final VoidCallback onWhatsApp;
  final VoidCallback? onEditNote;

  @override
  State<_CustomerContextCard> createState() => _CustomerContextCardState();
}

class _CustomerContextCardState extends State<_CustomerContextCard> {
  bool _expanded = true;

  static Color _bookingColor(String? s) => switch (s) {
        'CONFIRMED' => placeSuccess,
        'COMPLETED' => placeInfo,
        'CANCELLED' => placeDanger,
        'AWAITING_PAYMENT' => placeWarning,
        _ => placeBrass,
      };

  @override
  Widget build(BuildContext context) {
    final hasPhone = widget.phone != null && widget.phone!.isNotEmpty;
    final canCall = Session.can('calls.outbound') || Session.can('calls.answer');
    final note = widget.staffNote;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(StaffRadius.lg),
          border: Border.all(color: placeLine),
          boxShadow: staffCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(StaffRadius.lg),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    const IconBox(icon: Icons.badge_outlined, color: placeNavyHigh, size: 36),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('ملف الزبون', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 15, color: placeInk)),
                    ),
                    _StatPill(icon: Icons.event_available_rounded, value: '${widget.stats?['bookingCount'] ?? 0}', label: 'حجز'),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _expanded ? .5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(Icons.expand_more_rounded, color: placeInk2),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              secondChild: const SizedBox(width: double.infinity),
              firstChild: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _MiniKpi(label: 'حجوزات مؤكدة', value: '${widget.stats?['bookingCount'] ?? 0}', color: placeNavyHigh),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MiniKpi(label: 'إجمالي الإنفاق', value: formatIqd(widget.stats?['totalSpend']), color: placeBrass),
                        ),
                      ],
                    ),
                    if (note != null && note.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _InternalNoteCard(note: note, onTap: widget.onEditNote),
                    ] else if (widget.onEditNote != null) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: widget.onEditNote,
                          icon: const Icon(Icons.add_comment_outlined, size: 18),
                          label: const Text('إضافة ملاحظة داخلية'),
                        ),
                      ),
                    ],
                    if (widget.bookings.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('آخر الحجوزات', style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w800, color: placeInk2)),
                      const SizedBox(height: 6),
                      for (final raw in widget.bookings.take(3))
                        Builder(builder: (context) {
                          final b = raw as Map;
                          final status = b['status']?.toString();
                          final start = DateTime.tryParse(b['startDate']?.toString() ?? '');
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                const Icon(Icons.home_work_outlined, size: 18, color: placeInk3),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${(b['property'] as Map?)?['name'] ?? 'حجز'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 13.5, fontWeight: FontWeight.w800, color: placeInk),
                                      ),
                                      if (start != null)
                                        Text(
                                          DateFormat('d MMMM', 'ar').format(start),
                                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.w600, color: placeInk3),
                                        ),
                                    ],
                                  ),
                                ),
                                StatusChip(bookingStatusAr(status), color: _bookingColor(status), dense: true),
                              ],
                            ),
                          );
                        }),
                    ],
                    if (hasPhone || canCall) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (hasPhone)
                            Expanded(
                              child: _ContactButton(icon: Icons.phone_outlined, label: 'اتصال', color: placeInk, onTap: widget.onDial),
                            ),
                          if (hasPhone) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ContactButton(icon: Icons.chat_outlined, label: 'واتساب', color: const Color(0xFF128C7E), onTap: widget.onWhatsApp),
                            ),
                          ],
                          if (canCall) ...[
                            if (hasPhone) const SizedBox(width: 8),
                            Expanded(
                              child: _ContactButton(icon: Icons.headset_mic_rounded, label: 'مكالمة', color: placeSuccess, filled: true, onTap: widget.onCall),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: placeLineSoft, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: placeInk2),
          const SizedBox(width: 4),
          Text('$value $label', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.w800, color: placeInk2)),
        ],
      ),
    );
  }
}

class _MiniKpi extends StatelessWidget {
  const _MiniKpi({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: .06), borderRadius: BorderRadius.circular(StaffRadius.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.w700, color: placeInk2)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w900, color: color)),
          ),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({required this.icon, required this.label, required this.color, required this.onTap, this.filled = false});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final style = filled
        ? FilledButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 8))
        : OutlinedButton.styleFrom(foregroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 8));
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
    return filled
        ? FilledButton(onPressed: onTap, style: style, child: child)
        : OutlinedButton(onPressed: onTap, style: style, child: child);
  }
}

/// نموذج الملاحظة الداخلية.
class _NoteForm extends StatefulWidget {
  const _NoteForm({this.initial});

  final String? initial;

  @override
  State<_NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends State<_NoteForm> {
  late final _c = TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: placeGoldSoft, borderRadius: BorderRadius.circular(StaffRadius.sm)),
          child: const Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 16, color: placeBrass),
              SizedBox(width: 6),
              Expanded(
                child: Text('تظهر للموظفين فقط — لا يراها الزبون', style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w800, color: placeBrass)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _c,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'اكتب الملاحظة…'),
        ),
        const SizedBox(height: 14),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _c,
          builder: (context, v, _) => FilledButton.icon(
            onPressed: v.text.trim().isEmpty ? null : () => Navigator.of(context).pop(_c.text.trim()),
            icon: const Icon(Icons.check_rounded),
            label: const Text('حفظ الملاحظة'),
          ),
        ),
      ],
    );
  }
}

/// هيكل تحميل للمحادثة.
class _ThreadSkeleton extends StatelessWidget {
  const _ThreadSkeleton();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return ListView(
      padding: const EdgeInsets.all(12),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const SkeletonBox(height: 64),
        const SizedBox(height: 20),
        for (var i = 0; i < 6; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Align(
              alignment: i.isEven ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
              child: SkeletonBox(width: w * (i % 3 == 0 ? .62 : .45), height: i % 3 == 0 ? 58 : 42, radius: 18),
            ),
          ),
      ],
    );
  }
}
