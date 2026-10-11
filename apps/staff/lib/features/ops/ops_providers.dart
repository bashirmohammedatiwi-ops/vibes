import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';

class OpsProvidersScreen extends StatefulWidget {
  const OpsProvidersScreen({super.key});

  @override
  State<OpsProvidersScreen> createState() => _OpsProvidersScreenState();
}

class _OpsProvidersScreenState extends State<OpsProvidersScreen> {
  List<dynamic> _rows = [];
  String _q = '';
  bool _loading = true;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final path = _q.trim().isEmpty
          ? '/api/staff/providers'
          : '/api/staff/providers?q=${Uri.encodeQueryComponent(_q.trim())}';
      _rows = await Api.list(path);
    } catch (_) {
      _rows = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _verify(String id, bool verified) async {
    String? reason;
    if (!verified) {
      reason = await promptText(context, title: 'سبب الرفض');
      if (reason == null) return;
    }
    try {
      await Api.send(
        '/api/staff/providers/$id/verify',
        method: 'POST',
        body: {'verified': verified, if (reason != null) 'reason': reason},
      );
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المزودون')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: const InputDecoration(hintText: 'بحث بالاسم أو الهاتف', prefixIcon: Icon(Icons.search)),
              onSubmitted: (v) {
                _q = v;
                _load();
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? ListView(children: const [SizedBox(height: 120), Center(child: CircularProgressIndicator())])
                  : _rows.isEmpty
                      ? ListView(children: const [EmptyState(title: 'لا مزودين')])
                      : ListView.builder(
                          itemCount: _rows.length,
                          itemBuilder: (context, i) {
                            final row = _rows[i] as Map;
                            final id = row['id']?.toString() ?? '';
                            final verified = row['verified'] == true;
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              child: ListTile(
                                title: Text(
                                  () {
                                    final biz = row['businessName']?.toString() ?? '';
                                    if (biz.isNotEmpty) return biz;
                                    return row['user']?['name']?.toString() ?? 'مزود';
                                  }(),
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                                subtitle: Text(
                                  '${row['user']?['phone'] ?? ''} · ${row['_count']?['properties'] ?? 0} مكان · ${row['kycStatus'] ?? ''}',
                                  style: const TextStyle(color: placeInk2),
                                ),
                                trailing: Session.can('providers.link')
                                    ? verified
                                        ? const Icon(Icons.verified, color: Color(0xFF15803D))
                                        : FilledButton(
                                            onPressed: () => _verify(id, true),
                                            child: const Text('تحقق'),
                                          )
                                    : null,
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
