import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/chat_ui.dart';
import '../widgets/ui.dart';
import 'chat_room.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic> _data = {};
  bool _loading = true;
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _data = await Api.map('/api/staff/requests');
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _reviewCancellation(Map row, bool approve) async {
    final note = await promptText(context, title: approve ? 'موافقة على الإلغاء' : 'رفض الإلغاء', hint: 'ملاحظة اختيارية', maxLines: 2);
    if (!approve && note == null) return;
    await Api.send('/api/staff/requests/cancellations/${row['id']}', method: 'POST', body: {'approve': approve, 'note': note ?? ''});
    _load();
  }

  Future<void> _reviewRefund(Map row, bool approve) async {
    final note = await promptText(context, title: approve ? 'موافقة على الاسترداد' : 'رفض الاسترداد', hint: 'ملاحظة اختيارية', maxLines: 2);
    if (!approve && note == null) return;
    await Api.send('/api/staff/requests/refunds/${row['id']}', method: 'POST', body: {'approve': approve, 'note': note ?? ''});
    _load();
  }

  Future<void> _openUserChat(Map? user) async {
    final userId = user?['id']?.toString();
    if (userId == null) return;
    try {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            contactUserId: userId,
            contactName: user?['name']?.toString() ?? user?['phone']?.toString() ?? 'زبون',
            contactPhone: user?['phone']?.toString(),
          ),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cancellations = (_data['cancellations'] as List<dynamic>? ?? []);
    final refunds = (_data['refunds'] as List<dynamic>? ?? []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MaisonHeader(title: 'الطلبات', subtitle: 'إلغاء واسترداد — مع سياق الحجز'),
        TabBar(
          controller: _tabs,
          labelColor: placeInk,
          indicatorColor: placeBrass,
          tabs: [
            Tab(text: 'إلغاء (${cancellations.length})'),
            Tab(text: 'استرداد (${refunds.length})'),
          ],
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _RequestList(
                      empty: 'لا طلبات إلغاء معلّقة',
                      onRefresh: _load,
                      children: cancellations.map((row) {
                        final map = row as Map;
                        final booking = map['booking'] as Map?;
                        final user = map['user'] as Map? ?? booking?['user'] as Map?;
                        final created = map['createdAt']?.toString();
                        return _RequestCard(
                          title: map['reason']?.toString() ?? 'طلب إلغاء',
                          subtitle: booking?['property']?['name']?.toString() ?? '',
                          meta: '${user?['name'] ?? ''} · ${formatIqd(map['expectedRefund'])}',
                          time: created != null ? DateFormat('d MMM HH:mm', 'ar').format(DateTime.parse(created).toLocal()) : null,
                          user: user,
                          canReview: Session.can('cancellations.review'),
                          onChat: () => _openUserChat(user),
                          onApprove: () => _reviewCancellation(map, true),
                          onReject: () => _reviewCancellation(map, false),
                        );
                      }).toList(),
                    ),
                    _RequestList(
                      empty: 'لا طلبات استرداد معلّقة',
                      onRefresh: _load,
                      children: refunds.map((row) {
                        final map = row as Map;
                        final booking = map['booking'] as Map?;
                        final user = map['user'] as Map?;
                        final created = map['createdAt']?.toString();
                        return _RequestCard(
                          title: formatIqd(map['amount']),
                          subtitle: map['reason']?.toString() ?? booking?['property']?['name']?.toString() ?? '',
                          meta: user?['phone']?.toString() ?? '',
                          time: created != null ? DateFormat('d MMM HH:mm', 'ar').format(DateTime.parse(created).toLocal()) : null,
                          user: user,
                          canReview: Session.can('refunds.review'),
                          onChat: () => _openUserChat(user),
                          onApprove: () => _reviewRefund(map, true),
                          onReject: () => _reviewRefund(map, false),
                        );
                      }).toList(),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _RequestList extends StatelessWidget {
  const _RequestList({required this.children, required this.empty, required this.onRefresh});

  final List<Widget> children;
  final String empty;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: children.isEmpty
          ? ListView(children: [EmptyState(title: empty)])
          : ListView(padding: const EdgeInsets.only(bottom: 24, top: 8), children: children),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.title,
    required this.subtitle,
    required this.meta,
    this.time,
    this.user,
    required this.canReview,
    required this.onChat,
    required this.onApprove,
    required this.onReject,
  });

  final String title;
  final String subtitle;
  final String meta;
  final String? time;
  final Map? user;
  final bool canReview;
  final VoidCallback onChat;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (user != null) ContactAvatar(name: user!['name']?.toString() ?? '', phone: user!['phone']?.toString(), size: 42),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(color: placeBrass, fontWeight: FontWeight.w600)),
                      Text(meta, style: const TextStyle(color: placeInk2, fontSize: 13)),
                    ],
                  ),
                ),
                if (time != null) Text(time!, style: const TextStyle(fontSize: 11, color: placeInk2)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (Session.can('inbox.read') && user != null)
                  TextButton.icon(onPressed: onChat, icon: const Icon(Icons.chat_outlined, size: 18), label: const Text('محادثة')),
                const Spacer(),
                if (canReview) ...[
                  FilledButton(onPressed: onApprove, style: FilledButton.styleFrom(backgroundColor: placeSuccess, padding: const EdgeInsets.symmetric(horizontal: 16)), child: const Text('موافقة')),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: onReject, child: const Text('رفض')),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
