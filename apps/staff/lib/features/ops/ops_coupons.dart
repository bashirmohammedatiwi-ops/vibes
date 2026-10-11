import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/form_kit.dart';
import '../../widgets/ui.dart';

class OpsCouponsScreen extends StatefulWidget {
  const OpsCouponsScreen({super.key});

  @override
  State<OpsCouponsScreen> createState() => _OpsCouponsScreenState();
}

class _OpsCouponsScreenState extends State<OpsCouponsScreen> {
  List<dynamic> _rows = [];
  bool _loading = true;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _rows = await Api.list('/api/staff/coupons');
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

  Future<void> _setActive(String id, bool isActive) async {
    try {
      await Api.send('/api/staff/coupons/$id/active', method: 'POST', body: {'isActive': isActive});
      await _load();
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  String _discountLabel(Map row) {
    final type = row['discountType']?.toString() ?? '';
    final value = row['discountValue'];
    if (type == 'PERCENT') return '$value%';
    return '${value ?? ''} د.ع';
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = Session.can('coupons.write');
    return Scaffold(
      appBar: AppBar(title: const Text('الكوبونات')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator(color: placeGold)),
                ],
              )
            : _rows.isEmpty
            ? ListView(children: const [EmptyState(title: 'لا كوبونات')])
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                itemCount: _rows.length,
                itemBuilder: (context, i) {
                  final row = _rows[i] as Map;
                  final id = row['id']?.toString() ?? '';
                  final active = row['isActive'] == true;
                  final used = row['usedCount'] ?? 0;
                  final max = row['maxUses'];
                  return Card(
                    margin: const EdgeInsets.fromLTRB(StaffSpace.page, 0, StaffSpace.page, StaffSpace.gap),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(StaffRadius.lg),
                      side: const BorderSide(color: placeLine),
                    ),
                    elevation: 0,
                    color: Colors.white,
                    child: ListTile(
                      title: Text(
                        row['code']?.toString() ?? '',
                        style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      subtitle: Text(
                        '${_discountLabel(row)} · استخدام $used${max != null ? '/$max' : ''}'
                        '${(row['description']?.toString() ?? '').isNotEmpty ? '\n${row['description']}' : ''}',
                        style: const TextStyle(color: placeInk2),
                      ),
                      isThreeLine: (row['description']?.toString() ?? '').isNotEmpty,
                      trailing: canWrite
                          ? Switch(value: active, onChanged: (v) => _setActive(id, v))
                          : Text(
                              active ? 'نشط' : 'متوقف',
                              style: TextStyle(fontWeight: FontWeight.w800, color: active ? placeBrass : placeInk2),
                            ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
