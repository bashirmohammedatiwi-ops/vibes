import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/chat_stream.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/shift.dart' show bookingStatusAr;
import '../core/theme.dart';
import '../widgets/chat_ui.dart';
import '../widgets/ui.dart';
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
    final note = await promptText(context, title: 'ملاحظة داخلية', hint: 'تظهر للموظفين فقط', maxLines: 3);
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

  void _showTools() {
    final urgent = _ops?['priority']?.toString() == 'URGENT';
    final note = _ops?['staffNote']?.toString();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('أدوات المحادثة', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              ),
            ),
            if (note != null && note.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.sticky_note_2_outlined, color: placeBrass),
                title: const Text('ملاحظة حالية'),
                subtitle: Text(note, maxLines: 3, overflow: TextOverflow.ellipsis),
              ),
            if (Session.can('inbox.reply'))
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_outlined),
                title: const Text('تعيين لي'),
                onTap: () {
                  Navigator.pop(context);
                  _claim();
                },
              ),
            ListTile(
              leading: Icon(urgent ? Icons.flag : Icons.outlined_flag, color: urgent ? placeDanger : placeInk),
              title: Text(urgent ? 'إلغاء العاجل' : 'تعليمليم كعاجل'),
              onTap: () {
                Navigator.pop(context);
                _setUrgent(!urgent);
              },
            ),
            if (Session.can('inbox.note'))
              ListTile(
                leading: const Icon(Icons.edit_note_outlined),
                title: const Text('إضافة ملاحظة داخلية'),
                onTap: () {
                  Navigator.pop(context);
                  _addNote();
                },
              ),
            const SizedBox(height: 8),
          ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        backgroundColor: placeInk,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.contactName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            if (widget.contactPhone != null)
              Text(widget.contactPhone!, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          if (Session.can('calls.outbound') || Session.can('calls.answer'))
            IconButton(onPressed: _startCall, icon: const Icon(Icons.call_rounded)),
          IconButton(onPressed: _showTools, icon: const Icon(Icons.more_vert_rounded), tooltip: 'أدوات'),
        ],
      ),
      body: Column(
        children: [
          if (_ops?['priority']?.toString() == 'URGENT')
            Material(
              color: placeDanger.withValues(alpha: 0.12),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.flag, size: 16, color: placeDanger),
                    SizedBox(width: 8),
                    Text('محادثة عاجلة', style: TextStyle(color: placeDanger, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: _messages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _CustomerContextCard(
                          name: widget.contactName,
                          phone: widget.contactPhone,
                          stats: _stats,
                          bookings: _bookings,
                          staffNote: _ops?['staffNote']?.toString(),
                          onCall: _startCall,
                        );
                      }
                      final msg = _messages[index - 1];
                      final created = msg['createdAt']?.toString();
                      final dt = created != null ? DateTime.tryParse(created)?.toLocal() : null;
                      final prev = index > 1 ? _messages[index - 2] : null;
                      DateTime? prevDt;
                      if (prev != null && prev['createdAt'] != null) {
                        prevDt = DateTime.tryParse(prev['createdAt'] as String)?.toLocal();
                      }
                      final showDate = dt != null && (prevDt == null || prevDt.day != dt.day || prevDt.month != dt.month || prevDt.year != dt.year);
                      final showThread = prev != null &&
                          msg['conversationId'] != null &&
                          prev['conversationId'] != msg['conversationId'] &&
                          (msg['threadLabel']?.toString() ?? '').isNotEmpty;
                      return Column(
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
              enabled: true,
              onSend: () => _send(),
              onQuickReply: _send,
              onAttach: _attachImage,
            ),
        ],
      ),
    );
  }
}

class _CustomerContextCard extends StatefulWidget {
  const _CustomerContextCard({
    required this.name,
    this.phone,
    this.stats,
    required this.bookings,
    this.staffNote,
    required this.onCall,
  });

  final String name;
  final String? phone;
  final Map<String, dynamic>? stats;
  final List<dynamic> bookings;
  final String? staffNote;
  final VoidCallback onCall;

  @override
  State<_CustomerContextCard> createState() => _CustomerContextCardState();
}

class _CustomerContextCardState extends State<_CustomerContextCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: placeLine),
        boxShadow: [BoxShadow(color: placeInk.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                ContactAvatar(name: widget.name, phone: widget.phone, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      Text(
                        'حجوزات: ${widget.stats?['bookingCount'] ?? 0} · ${formatIqd(widget.stats?['totalSpend'])}',
                        style: const TextStyle(color: placeInk2, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: placeInk2),
              ],
            ),
          ),
          if (_expanded && widget.staffNote != null && widget.staffNote!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: placeBrass.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('ملاحظة: ${widget.staffNote}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
          if (_expanded && widget.bookings.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            for (final b in widget.bookings.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.home_work_outlined, size: 16, color: placeBrass),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${(b as Map)['property']?['name'] ?? 'حجز'} · ${bookingStatusAr((b)['status']?.toString())}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (_expanded) const SizedBox(height: 8),
          if (_expanded)
          Row(
            children: [
              if (widget.phone != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse('tel:${widget.phone}');
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                    icon: const Icon(Icons.phone_outlined, size: 18),
                    label: const Text('اتصال'),
                  ),
                ),
              if (Session.can('calls.outbound') || Session.can('calls.answer')) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.onCall,
                    style: FilledButton.styleFrom(backgroundColor: placeSuccess),
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('مكالمة'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
