import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/session.dart';
import '../../widgets/ui.dart';
import '../chat_room.dart';

class OpsCustomersScreen extends StatefulWidget {
  const OpsCustomersScreen({super.key});

  @override
  State<OpsCustomersScreen> createState() => _OpsCustomersScreenState();
}

class _OpsCustomersScreenState extends State<OpsCustomersScreen> {
  List<dynamic> _rows = [];
  bool _loading = false;
  String? _error;
  final _controller = TextEditingController();

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.length < 2) {
      setState(() => _error = 'اكتب حرفين على الأقل');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _rows = await Api.list('/api/staff/users?q=${Uri.encodeQueryComponent(q)}');
    } catch (e) {
      _error = e is ApiException ? e.message : '$e';
      _rows = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الزبائن')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: 'هاتف أو اسم', prefixIcon: Icon(Icons.search_rounded)),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _search, child: const Text('بحث')),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!, style: const TextStyle(color: placeWarning)),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: placeGold))
                : _rows.isEmpty
                ? const EmptyState(title: 'ابحث عن زبون', subtitle: 'بالهاتف أو الاسم')
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    itemCount: _rows.length,
                    itemBuilder: (context, i) {
                      final row = _rows[i] as Map;
                      return Card(
                        margin: const EdgeInsets.fromLTRB(StaffSpace.page, 0, StaffSpace.page, StaffSpace.gap),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(StaffRadius.lg),
                          side: const BorderSide(color: placeLine),
                        ),
                        elevation: 0,
                        color: Colors.white,
                        child: ListTile(
                          title: Text(row['name']?.toString() ?? 'زبون', style: const TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: Text('${row['phone'] ?? ''} · ${row['_count']?['bookings'] ?? 0} حجوزات'),
                          trailing: Session.can('inbox.read')
                              ? IconButton(
                                  icon: const Icon(Icons.chat_bubble_outline),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ChatRoomScreen(
                                          contactUserId: row['id'].toString(),
                                          contactName: row['name']?.toString() ?? 'زبون',
                                          contactPhone: row['phone']?.toString(),
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
