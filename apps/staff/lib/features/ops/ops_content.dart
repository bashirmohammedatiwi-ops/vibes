import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../widgets/form_kit.dart';
import '../../widgets/ui.dart';

class OpsContentScreen extends StatefulWidget {
  const OpsContentScreen({super.key});

  @override
  State<OpsContentScreen> createState() => _OpsContentScreenState();
}

class _OpsContentScreenState extends State<OpsContentScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<dynamic> _banners = [];
  List<dynamic> _reviews = [];
  List<dynamic> _spotlights = [];
  bool _hiddenOnly = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
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
      final results = await Future.wait([
        Api.list('/api/staff/banners'),
        Api.list('/api/staff/reviews${_hiddenOnly ? '?hidden=1' : ''}'),
        Api.list('/api/staff/spotlights'),
      ]);
      _banners = results[0];
      _reviews = results[1];
      _spotlights = results[2];
    } catch (_) {
      _banners = [];
      _reviews = [];
      _spotlights = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _setBannerActive(String id, bool isActive) async {
    try {
      await Api.send('/api/staff/banners/$id/active', method: 'POST', body: {'isActive': isActive});
      await _load();
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _setSpotlightActive(String id, bool isActive) async {
    try {
      await Api.send('/api/staff/spotlights/$id/active', method: 'POST', body: {'isActive': isActive});
      await _load();
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _setReviewVisible(String id, bool isVisible) async {
    String? note;
    if (!isVisible) {
      note = await promptText(context, title: 'ملاحظة إدارية (اختياري)');
      if (note == null) return;
    }
    try {
      await Api.send(
        '/api/staff/reviews/$id/visibility',
        method: 'POST',
        body: {'isVisible': isVisible, if (note != null && note.isNotEmpty) 'adminNote': note},
      );
      await _load();
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المحتوى'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'البانرات'),
            Tab(text: 'التقييمات'),
            Tab(text: 'المميزة'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: placeGold))
          : TabBarView(
              controller: _tabs,
              children: [
                RefreshIndicator(
                  onRefresh: _load,
                  child: _banners.isEmpty
                      ? ListView(children: const [EmptyState(title: 'لا بانرات')])
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 24),
                          itemCount: _banners.length,
                          itemBuilder: (context, i) {
                            final row = _banners[i] as Map;
                            final id = row['id']?.toString() ?? '';
                            final active = row['isActive'] == true;
                            return Card(
                              margin: const EdgeInsets.fromLTRB(StaffSpace.page, 0, StaffSpace.page, StaffSpace.gap),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(StaffRadius.lg),
                                side: const BorderSide(color: placeLine),
                              ),
                              elevation: 0,
                              color: Colors.white,
                              child: ListTile(
                                title: Text(row['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w900)),
                                subtitle: Text(
                                  row['subtitle']?.toString().isNotEmpty == true ? row['subtitle'].toString() : (active ? 'نشط' : 'متوقف'),
                                  style: const TextStyle(color: placeInk2),
                                ),
                                trailing: Switch(value: active, onChanged: (v) => _setBannerActive(id, v)),
                              ),
                            );
                          },
                        ),
                ),
                Column(
                  children: [
                    SwitchListTile(
                      title: const Text('المخفية فقط', style: TextStyle(fontWeight: FontWeight.w800)),
                      value: _hiddenOnly,
                      onChanged: (v) {
                        setState(() => _hiddenOnly = v);
                        _load();
                      },
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: _reviews.isEmpty
                            ? ListView(children: const [EmptyState(title: 'لا تقييمات')])
                            : ListView.builder(
                                padding: const EdgeInsets.only(top: 8, bottom: 24),
                                itemCount: _reviews.length,
                                itemBuilder: (context, i) {
                                  final row = _reviews[i] as Map;
                                  final id = row['id']?.toString() ?? '';
                                  final visible = row['isVisible'] != false;
                                  final property = row['property'] as Map?;
                                  final user = row['user'] as Map?;
                                  return Card(
                                    margin: const EdgeInsets.fromLTRB(StaffSpace.page, 0, StaffSpace.page, StaffSpace.gap),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(StaffRadius.lg),
                                      side: const BorderSide(color: placeLine),
                                    ),
                                    elevation: 0,
                                    color: Colors.white,
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            property?['name']?.toString() ?? 'مكان',
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                          ),
                                          Text(
                                            '${user?['name'] ?? ''} · ★ ${row['rating'] ?? ''}',
                                            style: const TextStyle(color: placeInk2),
                                          ),
                                          if ((row['comment']?.toString() ?? '').isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(row['comment'].toString()),
                                          ],
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            children: [
                                              if (visible)
                                                OutlinedButton(onPressed: () => _setReviewVisible(id, false), child: const Text('إخفاء'))
                                              else
                                                FilledButton(onPressed: () => _setReviewVisible(id, true), child: const Text('إظهار')),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
                RefreshIndicator(
                  onRefresh: _load,
                  child: _spotlights.isEmpty
                      ? ListView(children: const [EmptyState(title: 'لا عناصر مميزة')])
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 24),
                          itemCount: _spotlights.length,
                          itemBuilder: (context, i) {
                            final row = _spotlights[i] as Map;
                            final id = row['id']?.toString() ?? '';
                            final active = row['isActive'] == true;
                            final property = row['property'] as Map?;
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
                                  (row['title']?.toString().isNotEmpty == true)
                                      ? row['title'].toString()
                                      : (property?['name']?.toString() ?? 'مميز'),
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                                subtitle: Text(
                                  property?['name']?.toString() ?? (active ? 'نشط' : 'متوقف'),
                                  style: const TextStyle(color: placeInk2),
                                ),
                                trailing: Switch(value: active, onChanged: (v) => _setSpotlightActive(id, v)),
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
