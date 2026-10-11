import 'package:flutter/material.dart';

import '../../../core/api.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/kit.dart';
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
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(StaffRadius.xl))),
      builder: (_) => const _AccountPicker(),
    );
    if (picked != null) setState(() => _account = picked);
  }

  Future<void> _pickProperty() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: placePaper,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(StaffRadius.xl))),
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
      bottomNavigationBar: BottomActionBar(
        label: 'ربط المكان',
        busy: _saving,
        onPressed: a != null && p != null ? _submit : null,
      ),
      body: StaffPage(
        title: 'ربط مكان بمزود',
        subtitle: 'اختر الحساب ثم المكان',
        slivers: [
          const SliverToBoxAdapter(
            child: NoticeBanner(
              text: 'بعد الربط يصبح الحساب مزوداً موثّقاً وتظهر حجوزات المكان في بوابته.',
              color: placeInfo,
              icon: Icons.info_outline_rounded,
            ),
          ),
          SliverToBoxAdapter(
            child: DetailCard(
              title: '١. الحساب',
              subtitle: 'صاحب المكان',
              icon: Icons.person_rounded,
              color: placeInfo,
              trailing: a == null ? null : const Icon(Icons.check_circle_rounded, color: placeSuccess),
              children: [
                const SizedBox(height: 4),
                if (a == null)
                  _PickButton(label: 'اختر الحساب', icon: Icons.person_search_rounded, onTap: _pickAccount)
                else
                  _Selected(
                    leading: Avatar(a.name, size: 44),
                    title: a.name,
                    subtitle: a.subtitle ?? '',
                    phone: a.phone,
                    onChange: _pickAccount,
                  ),
                const SizedBox(height: 6),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: DetailCard(
              title: '٢. المكان',
              subtitle: 'المكان المراد ربطه',
              icon: Icons.home_work_rounded,
              color: placeBrass,
              trailing: p == null ? null : const Icon(Icons.check_circle_rounded, color: placeSuccess),
              children: [
                const SizedBox(height: 4),
                if (p == null)
                  _PickButton(label: 'اختر المكان', icon: Icons.travel_explore_rounded, onTap: _pickProperty)
                else ...[
                  _Selected(
                    leading: SizedBox(width: 48, height: 48, child: NetImage(url: _cover(p), radius: 12, icon: placeTypeIcon(p['type']?.toString()))),
                    title: nonEmpty(p['name'], 'مكان'),
                    subtitle: [placeTypeLabel(p['type']?.toString()), nonEmpty(asMap(p['city'])['nameAr'], '')].where((s) => s.isNotEmpty).join(' · '),
                    onChange: _pickProperty,
                  ),
                  if (current.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: placeWarning.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(StaffRadius.md)),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: placeWarning, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'مرتبط حالياً بـ ${nonEmpty(current['businessName'], asMap(current['user'])['name']?.toString() ?? 'مزود')} — سيُنقل للحساب المختار.',
                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w700, color: placeWarning),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 6),
              ],
            ),
          ),
        ],
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
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _Selected extends StatelessWidget {
  const _Selected({required this.leading, required this.title, required this.subtitle, required this.onChange, this.phone});
  final Widget leading;
  final String title;
  final String subtitle;
  final String? phone;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      leading: leading,
      title: title,
      subtitle: subtitle.isEmpty ? null : subtitle,
      subtitleWidget: (phone ?? '').isEmpty ? null : PhoneText(phone),
      trailing: TextButton(onPressed: onChange, child: const Text('تغيير')),
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
          const Text('اختر الحساب', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: placeInk)),
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
                    child: EmptyView(
                      icon: Icons.lock_outline_rounded,
                      title: 'لا صلاحية',
                      subtitle: 'تحتاج صلاحية عرض المزودين أو الحسابات لاختيار الحساب',
                    ),
                  )
                : PagedList(
                    key: ValueKey('$_source|$_q'),
                    fetch: _fetch,
                    emptyIcon: Icons.person_search_rounded,
                    emptyTitle: 'لا نتائج',
                    emptySubtitle: 'ابحث بالاسم أو رقم الهاتف',
                    itemBuilder: (context, row, _) {
                      final a = _toAccount(row);
                      return ListCard(
                        onTap: () => Navigator.of(context).pop(a),
                        child: ListRow(
                          leading: Avatar(a.name, size: 42),
                          title: a.name,
                          subtitleWidget: (a.phone ?? '').isEmpty ? null : PhoneText(a.phone),
                          trailing: a.subtitle == null ? null : StatusChip(a.subtitle!, color: placeInk2, dense: true),
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
          const Text('اختر المكان', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: placeInk)),
          SearchBox(hint: 'اسم المكان أو العنوان', onChanged: (v) => setState(() => _q = v)),
          const SizedBox(height: 6),
          Expanded(
            child: !allowed
                ? const Center(
                    child: EmptyView(
                      icon: Icons.lock_outline_rounded,
                      title: 'لا صلاحية',
                      subtitle: 'تحتاج صلاحية «عرض الأماكن» للبحث عن الأماكن',
                    ),
                  )
                : PagedList(
                    key: ValueKey(_q),
                    fetch: (page) => fetchPage('/api/admin/properties', {'q': _q, 'status': 'all'}, page: page),
                    emptyIcon: Icons.travel_explore_rounded,
                    emptyTitle: 'لا أماكن مطابقة',
                    itemBuilder: (context, p, _) {
                      final provider = asMap(p['provider']);
                      final status = p['status']?.toString();
                      return ListCard(
                        onTap: () => Navigator.of(context).pop(p),
                        child: ListRow(
                          leading: SizedBox(width: 52, height: 52, child: NetImage(url: _cover(p), radius: 12, icon: placeTypeIcon(p['type']?.toString()))),
                          title: nonEmpty(p['name'], 'مكان'),
                          subtitleWidget: Text(
                            provider.isEmpty
                                ? 'بدون مزود'
                                : 'المزود: ${nonEmpty(provider['businessName'], asMap(provider['user'])['name']?.toString() ?? '')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: provider.isEmpty ? placeInk2 : placeWarning,
                            ),
                          ),
                          chips: [StatusChip(placeStatusLabel(status), color: placeStatusColor(status), dense: true)],
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
