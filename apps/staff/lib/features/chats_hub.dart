import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/chat_ui.dart';
import '../widgets/ui.dart';
import 'chat_room.dart';

class ChatsHubScreen extends StatefulWidget {
  const ChatsHubScreen({super.key});

  @override
  State<ChatsHubScreen> createState() => _ChatsHubScreenState();
}

class _ChatsHubScreenState extends State<ChatsHubScreen> {
  List<dynamic> _contacts = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String _filter = 'all';
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _load();
    _refresh = Timer.periodic(const Duration(seconds: 12), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await Api.map('/api/staff/contacts');
      _contacts = data['items'] as List<dynamic>? ?? [];
      _error = null;
    } catch (e) {
      if (!silent) _error = e is ApiException ? e.message : '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _searchByPhone() async {
    final phone = await promptText(context, title: 'بحث برقم الهاتف', hint: '07…', maxLines: 1);
    if (phone == null || phone.trim().isEmpty) return;
    try {
      final found = await Api.map('/api/staff/customers?phone=${Uri.encodeComponent(phone.trim())}');
      final user = found['user'];
      if (user == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يُعثر على زبون')));
        return;
      }
      await _openContact(Map<String, dynamic>.from(user as Map));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openContact(Map<String, dynamic> user) async {
    final userId = user['id']?.toString();
    if (userId == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          contactUserId: userId,
          contactName: user['name']?.toString() ?? user['phone']?.toString() ?? 'زبون',
          contactPhone: user['phone']?.toString(),
        ),
      ),
    );
    _load(silent: true);
  }

  List<dynamic> get _visible {
    final q = _query.trim().toLowerCase();
    return _contacts.where((row) {
      final map = row as Map;
      final user = map['user'] as Map?;
      final name = user?['name']?.toString().toLowerCase() ?? '';
      final phone = user?['phone']?.toString() ?? '';
      if (q.isNotEmpty && !name.contains(q) && !phone.contains(q)) return false;
      final unread = (map['unread'] as num?)?.toInt() ?? 0;
      if (_filter == 'unread' && unread == 0) return false;
      final urgent = (map['conversations'] as List?)?.any((c) => (c as Map)['priority'] == 'URGENT') ?? false;
      if (_filter == 'urgent' && !urgent) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: placeInk,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المحادثات', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('كل زبون — حساب واحد — رسائل ومكالمات', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(color: placeInk),
                  decoration: InputDecoration(
                    hintText: 'بحث بالاسم أو الهاتف',
                    prefixIcon: const Icon(Icons.search, color: placeInk2),
                    suffixIcon: Session.can('users.read')
                        ? IconButton(onPressed: _searchByPhone, icon: const Icon(Icons.person_add_alt_1_outlined, color: placeBrass))
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ],
            ),
          ),
        ),
        FilterChipsRow(
          options: const ['all', 'unread', 'urgent'],
          selected: _filter,
          labelBuilder: (v) => switch (v) {
            'all' => 'الكل',
            'unread' => 'غير مقروء',
            'urgent' => 'عاجل',
            _ => v,
          },
          onSelected: (v) => setState(() => _filter = v),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading
                ? ListView.builder(
                    itemCount: 8,
                    itemBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Card(
                        child: SizedBox(height: 72, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                      ),
                    ),
                  )
                : _error != null
                    ? ListView(
                        children: [
                          EmptyState(title: 'تعذّر تحميل المحادثات', subtitle: _error),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                          ),
                        ],
                      )
                : _visible.isEmpty
                    ? ListView(children: const [EmptyState(title: 'لا محادثات بعد', subtitle: 'ابحث عن زبون أو انتظر رسالة جديدة')])
                    : ListView.builder(
                        itemCount: _visible.length,
                        itemBuilder: (context, index) {
                          final row = _visible[index] as Map;
                          final user = Map<String, dynamic>.from(row['user'] as Map);
                          final last = row['lastMessage'] as Map?;
                          final preview = last?['body']?.toString() ?? '';
                          final urgent = (row['conversations'] as List?)?.any((c) => (c as Map)['priority'] == 'URGENT') ?? false;
                          return ChatListTile(
                            name: user['name']?.toString() ?? user['phone']?.toString() ?? 'زبون',
                            phone: user['phone']?.toString(),
                            subtitle: row['propertyName']?.toString(),
                            preview: preview,
                            time: formatChatListTime(row['lastAt']?.toString()),
                            unread: (row['unread'] as num?)?.toInt() ?? 0,
                            urgent: urgent,
                            onTap: () => _openContact(user),
                          );
                        },
                      ),
          ),
        ),
        if (Session.can('users.read'))
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: FilledButton.icon(
                onPressed: _searchByPhone,
                style: FilledButton.styleFrom(backgroundColor: placeInk, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                icon: const Icon(Icons.person_search_outlined),
                label: const Text('بحث عن زبون'),
              ),
            ),
          ),
      ],
    );
  }
}
