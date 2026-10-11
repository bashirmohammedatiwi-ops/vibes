import 'package:flutter/material.dart';

import '../../../core/api.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/chat_ui.dart';
import '../../../widgets/form_kit.dart';
import 'people_common.dart';

/// الحساب المختار للربط (مستخدم — يتحوّل إلى مزود موثّق بعد الربط).
class LinkAccount {
  const LinkAccount({required this.userId, required this.name, this.phone, this.subtitle});
  final String userId;
  final String name;
  final String? phone;
  final String? subtitle;
}

/// ربط مكان بحساب مزود — `providers.link` (+ `properties.read` للبحث عن الأماكن).
class LinkPlaceScreen extends StatefulWidget {
  const LinkPlaceScreen({super.key, this.initialAccount});
  final LinkAccount? initialAccount;

  @override
  State<LinkPlaceScreen> createState() => _LinkPlaceScreenState();
}

class _LinkPlaceScreenState extends State<LinkPlaceScreen> {
  late LinkAccount? _account = widget.initialAccount;
  Map<String, dynamic>? _property;
  bool _saving = false;

  Future<void> _pickAccount() async {
    final picked = await showModalBottomSheet<LinkAccount>(
      context: context,
      isScrollControlled: true,
      backgroundColor: placePaper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => const _AccountPicker(),
    );
    if (picked != null) setState(() => _account = picked);
  }

  Future<void> _pickProperty() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: placePaper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => const _PropertyPicker(),
    );
    if (picked != null) setState(() => _property = picked);
  }

  Future<void> _submit() async {
    final a = _account;
    final p = _property;
    if (a == null || p == null) return;
    final current = asMap(p['provider']);
    final currentName = nonEmpty(current['businessName'], asMap(current['user'])['name']?.toString() ?? 'مزود آخر');
    final ok = await confirmDialog(
      context,
      title: 'تأكيد الربط',
      message: [
        'سيُربط «${nonEmpty(p['name'], 'المكان')}» بحساب «${a.name}»، ويُوثَّق الحساب كمزود وتصله رسالة بذلك.',
        if (current.isNotEmpty) '\n\nتنبيه: المكان مرتبط حالياً بـ «$currentName» وسيُنقل منه.',
      ].join(),
      confirmLabel: 'ربط',
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    final done = await runAction(context, () async {
      await Api.map('/api/admin/providers/link', method: 'POST', body: {'userId': a.userId, 'propertyId': '${p['id']}'});
    }, success: 'تم ربط المكان بالمزود');
    if (!mounted) return;
    setState(() => _saving = false);
    if (done) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final a = _account;
    final p = _property;
    final current = asMap(p?['provider']);
    return Scaffold(
      appBar: AppBar(title: const Text('ربط مكان بمزود')),
      body: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              'اختر حساب صاحب المكان ثم المكان. بعد الربط يصبح الحساب مزوداً موثّقاً وتظهر حجوزات المكان في بوابته.',
              style: TextStyle(fontFamily: 'Cairo', color: placeInk2, height: 1.6),
            ),
          ),
          FormSection(
            title: '١. الحساب',
            icon: Icons.person_outline_rounded,
            children: [
              if (a == null)
                _PickButton(label: 'اختر الحساب', icon: Icons.person_search_outlined, onTap: _pickAccount)
              else
                _Selected(
                  leading: ContactAvatar(name: a.name, phone: a.phone, size: 44),
                  title: a.name,
                  subtitle: [a.phone ?? '', a.subtitle ?? ''].where((s) => s.isNotEmpty).join(' · '),
                  onChange: _pickAccount,
                ),
            ],
          ),
          FormSection(
            title: '٢. المكان',
            icon: Icons.home_work_outlined,
            children: [
              if (p == null)
                _PickButton(label: 'اختر المكان', icon: Icons.travel_explore_rounded, onTap: _pickProperty)
              else ...[
                _Selected(
                  leading: SizedBox(width: 48, height: 48, child: NetImage(url: _cover(p), radius: 12, icon: placeTypeIcon(p['type']?.toString()))),
                  title: nonEmpty(p['name'], 'مكان'),
                  subtitle: '${placeTypeLabel(p['type']?.toString())} · ${nonEmpty(asMap(p['city'])['nameAr'], '')}',
                  onChange: _pickProperty,
                ),
                if (current.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: placeShiftMorning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: placeShiftMorning, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'مرتبط حالياً بـ ${nonEmpty(current['businessName'], asMap(current['user'])['name']?.toString() ?? 'مزود')} — سيُنقل للحساب المختار.',
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w700, color: placeShiftMorning),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        label: 'ربط المكان',
        busy: _saving,
        onPressed: a != null && p != null ? _submit : null,
      ),
    );
  }
}

String? _cover(Map<String, dynamic> p) {
  final media = asMapList(p['media']);
  if (media.isEmpty) return null;
  final primary = media.firstWhere((m) => m['isPrimary'] == true, orElse: () => media.first);
  return absUrl(primary['thumbnailUrl'] ?? primary['url']);
}

class _PickButton extends StatelessWidget {
  const _PickButton({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _Selected extends StatelessWidget {
  const _Selected({required this.leading, required this.title, required this.subtitle, required this.onChange});
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: placeInk)),
              if (subtitle.isNotEmpty)
                Text(subtitle, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        TextButton(onPressed: onChange, child: const Text('تغيير')),
      ],
    );
  }
}

/// منتقي الحساب: من المزودين أو من كل الحسابات.
class _AccountPicker extends StatefulWidget {
  const _AccountPicker();

  @override
  State<_AccountPicker> createState() => _AccountPickerState();
}

class _AccountPickerState extends State<_AccountPicker> {
  late String _source = Session.can('providers.read') ? 'providers' : 'users';
  String _q = '';

  Future<PageResult> _fetch(int page) => _source == 'providers'
      ? fetchPage('/api/admin/providers', {'q': _q}, page: page)
      : fetchPage('/api/admin/users', {'q': _q, 'isActive': 'true'}, page: page);

  LinkAccount _toAccount(Map<String, dynamic> row) {
    if (_source == 'providers') {
      final user = asMap(row['user']);
      final biz = row['businessName']?.toString().trim() ?? '';
      return LinkAccount(
        userId: '${user['id']}',
        name: biz.isNotEmpty ? biz : nonEmpty(user['name'], 'مزود'),
        phone: user['phone']?.toString(),
        subtitle: kycLabel(row['kycStatus']?.toString(), verified: row['verified'] == true),
      );
    }
    return LinkAccount(
      userId: '${row['id']}',
      name: nonEmpty(row['name'], 'بدون اسم'),
      phone: row['phone']?.toString(),
      subtitle: roleLabel(row['role']?.toString()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sources = [
      if (Session.can('providers.read')) 'providers',
      if (Session.can('users.read')) 'users',
    ];
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          const SizedBox(height: 12),
          const SheetHandle(),
          const Text('اختر الحساب', style: TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w900, color: placeInk)),
          if (sources.length > 1)
            FilterBar(groups: [
              FilterGroup(
                options: sources,
                selected: _source,
                labelOf: (v) => v == 'providers' ? 'المزودون' : 'كل الحسابات',
                onSelected: (v) => setState(() => _source = v),
              ),
            ]),
          SearchBox(hint: 'الاسم أو الهاتف', onChanged: (v) => setState(() => _q = v)),
          const SizedBox(height: 6),
          Expanded(
            child: sources.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('تحتاج صلاحية عرض المزودين أو الحسابات لاختيار الحساب',
                          textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', color: placeInk2)),
                    ),
                  )
                : PagedList(
                    key: ValueKey('$_source|$_q'),
                    fetch: _fetch,
                    emptyTitle: 'لا نتائج',
                    emptySubtitle: 'ابحث بالاسم أو رقم الهاتف',
                    itemBuilder: (context, row, _) {
                      final a = _toAccount(row);
                      return ListCard(
                        onTap: () => Navigator.of(context).pop(a),
                        child: Row(
                          children: [
                            ContactAvatar(name: a.name, phone: a.phone, size: 40),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.name, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: placeInk)),
                                  PhoneText(a.phone),
                                ],
                              ),
                            ),
                            if (a.subtitle != null) StatusPill(label: a.subtitle!, color: placeInk2),
                          ],
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

/// منتقي المكان بالبحث.
class _PropertyPicker extends StatefulWidget {
  const _PropertyPicker();

  @override
  State<_PropertyPicker> createState() => _PropertyPickerState();
}

class _PropertyPickerState extends State<_PropertyPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final allowed = Session.can('properties.read');
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          const SizedBox(height: 12),
          const SheetHandle(),
          const Text('اختر المكان', style: TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w900, color: placeInk)),
          SearchBox(hint: 'اسم المكان أو العنوان', onChanged: (v) => setState(() => _q = v)),
          const SizedBox(height: 6),
          Expanded(
            child: !allowed
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('تحتاج صلاحية «عرض الأماكن» للبحث عن الأماكن',
                          textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', color: placeInk2)),
                    ),
                  )
                : PagedList(
                    key: ValueKey(_q),
                    fetch: (page) => fetchPage('/api/admin/properties', {'q': _q, 'status': 'all'}, page: page),
                    emptyTitle: 'لا أماكن مطابقة',
                    itemBuilder: (context, p, _) {
                      final provider = asMap(p['provider']);
                      final status = p['status']?.toString();
                      return ListCard(
                        onTap: () => Navigator.of(context).pop(p),
                        child: Row(
                          children: [
                            SizedBox(width: 52, height: 52, child: NetImage(url: _cover(p), radius: 12, icon: placeTypeIcon(p['type']?.toString()))),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(nonEmpty(p['name'], 'مكان'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: placeInk)),
                                  Text(
                                    provider.isEmpty
                                        ? 'بدون مزود'
                                        : 'المزود: ${nonEmpty(provider['businessName'], asMap(provider['user'])['name']?.toString() ?? '')}',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: provider.isEmpty ? placeInk2 : placeShiftMorning,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatusPill(label: placeStatusLabel(status), color: placeStatusColor(status)),
                          ],
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
