import 'package:flutter/material.dart';

import '../../../core/api.dart';
import '../../../core/format.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/chat_ui.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/ui.dart';
import '../../ops/property_detail.dart';
import 'customers_screen.dart';
import 'link_place_screen.dart';
import 'people_common.dart';
import 'place_claims_screen.dart';

String providerDisplayName(Map<String, dynamic> p) {
  final biz = p['businessName']?.toString().trim() ?? '';
  if (biz.isNotEmpty) return biz;
  return nonEmpty(asMap(p['user'])['name'], 'مزود');
}

/// قائمة المزودين مع فلاتر التوثيق — `providers.read`.
class AdminProvidersScreen extends StatefulWidget {
  const AdminProvidersScreen({super.key, this.initialKyc = 'pending'});
  final String initialKyc;

  @override
  State<AdminProvidersScreen> createState() => _AdminProvidersScreenState();
}

class _AdminProvidersScreenState extends State<AdminProvidersScreen> {
  final _list = PagedListController();
  String _q = '';
  late String _kyc = widget.initialKyc;
  int? _total;

  Future<PageResult> _fetch(int page) =>
      fetchPage('/api/admin/providers', {'q': _q, 'kyc': _kyc == 'all' ? null : _kyc}, page: page);

  Future<void> _open(Map<String, dynamic> p) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AdminProviderDetailScreen(providerId: '${p['id']}')),
    );
    if (changed == true) _list.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المزودون'),
        actions: [
          IconButton(
            tooltip: 'طلبات ربط الأماكن',
            icon: const Icon(Icons.how_to_reg_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlaceClaimsScreen())),
          ),
          if (Session.can('providers.link'))
            IconButton(
              tooltip: 'ربط مكان بمزود',
              icon: const Icon(Icons.add_link_rounded),
              onPressed: () async {
                final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const LinkPlaceScreen()));
                if (ok == true) _list.reload();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          SearchBox(hint: 'الاسم التجاري، المالك أو الهاتف', onChanged: (v) => setState(() => _q = v)),
          FilterBar(groups: [
            FilterGroup(
              options: const ['pending', 'verified', 'rejected', 'all'],
              selected: _kyc,
              labelOf: (v) => switch (v) {
                'pending' => 'بانتظار التوثيق',
                'verified' => 'موثّقون',
                'rejected' => 'مرفوضون',
                _ => 'الكل',
              },
              onSelected: (v) => setState(() => _kyc = v),
            ),
          ]),
          if (_total != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 2),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('$_total مزود', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: placeInk2)),
              ),
            ),
          Expanded(
            child: PagedList(
              key: ValueKey('$_q|$_kyc'),
              controller: _list,
              fetch: _fetch,
              onLoaded: (r) => setState(() => _total = r.total),
              emptyTitle: _kyc == 'pending' ? 'لا طلبات توثيق معلّقة' : 'لا مزودين',
              emptySubtitle: _q.isEmpty ? null : 'جرّب بحثاً آخر',
              itemBuilder: (context, p, _) => _ProviderCard(provider: p, onTap: () => _open(p)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({required this.provider, required this.onTap});
  final Map<String, dynamic> provider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final user = asMap(p['user']);
    final verified = p['verified'] == true;
    final kyc = p['kycStatus']?.toString();
    final name = providerDisplayName(p);
    final owner = user['name']?.toString() ?? '';
    return ListCard(
      onTap: onTap,
      child: Row(
        children: [
          ContactAvatar(name: name, phone: user['phone']?.toString(), size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w900, color: placeInk)),
                    ),
                    if (verified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, size: 16, color: placeSuccess),
                    ],
                  ],
                ),
                if (owner.isNotEmpty && owner != name)
                  Text(owner, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2, fontWeight: FontWeight.w600)),
                PhoneText(user['phone']?.toString()),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    StatusPill(label: kycLabel(kyc, verified: verified), color: kycColor(kyc, verified: verified)),
                    StatusPill(
                      label: '${asInt(asMap(p['_count'])['properties'])} مكان',
                      color: placeInk2,
                      icon: Icons.home_work_outlined,
                    ),
                    StatusPill(label: relativeAr(p['createdAt']), color: placeInk2, icon: Icons.schedule_rounded),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_left_rounded, color: placeInk2),
        ],
      ),
    );
  }
}

/// ملف المزود: الأماكن، الإحصاءات، التوثيق والرفض والإلغاء.
class AdminProviderDetailScreen extends StatefulWidget {
  const AdminProviderDetailScreen({super.key, required this.providerId});
  final String providerId;

  @override
  State<AdminProviderDetailScreen> createState() => _AdminProviderDetailScreenState();
}

class _AdminProviderDetailScreenState extends State<AdminProviderDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  bool _changed = false;

  bool get _canLink => Session.can('providers.link');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _data == null;
      _error = null;
    });
    try {
      final data = await Api.map('/api/admin/providers/${widget.providerId}');
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorText(e);
        _loading = false;
      });
    }
  }

  Future<void> _act(String action, {String? reason, required String success}) async {
    final ok = await runAction(context, () async {
      await withBusy(
        context,
        () => Api.map(
          '/api/admin/providers/${widget.providerId}/$action',
          method: 'PATCH',
          body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
        ),
      );
    }, success: success);
    if (ok) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _verify() async {
    final name = providerDisplayName(asMap(_data?['provider']));
    final ok = await confirmDialog(
      context,
      title: 'توثيق المزود؟',
      message: 'سيُوثَّق «$name» ويتحوّل حسابه إلى مزود، وتظهر له بوابة المزود.',
      confirmLabel: 'توثيق',
    );
    if (ok && mounted) await _act('verify', success: 'تم توثيق المزود');
  }

  Future<void> _reject() async {
    final reason = await showInputSheet(
      context,
      title: 'رفض طلب التوثيق',
      subtitle: 'سيظهر السبب للمزود — اكتبه بوضوح.',
      label: 'سبب الرفض',
      confirmLabel: 'رفض الطلب',
      required: true,
      maxLines: 3,
      danger: true,
    );
    if (reason == null || !mounted) return;
    await _act('reject', reason: reason, success: 'تم رفض الطلب');
  }

  Future<void> _revoke() async {
    final reason = await showInputSheet(
      context,
      title: 'إلغاء توثيق المزود',
      subtitle: 'سيعود المزود إلى حالة «بانتظار التوثيق». السبب اختياري.',
      label: 'السبب (اختياري)',
      confirmLabel: 'متابعة',
      maxLines: 3,
      danger: true,
    );
    if (reason == null || !mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'تأكيد إلغاء التوثيق',
      message: 'هل أنت متأكد من إلغاء توثيق هذا المزود؟',
      confirmLabel: 'إلغاء التوثيق',
      danger: true,
    );
    if (ok && mounted) await _act('revoke', reason: reason, success: 'تم إلغاء التوثيق');
  }

  Future<void> _linkPlace() async {
    final p = asMap(_data?['provider']);
    final user = asMap(p['user']);
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LinkPlaceScreen(
          initialAccount: LinkAccount(
            userId: '${user['id']}',
            name: providerDisplayName(p),
            phone: user['phone']?.toString(),
            subtitle: kycLabel(p['kycStatus']?.toString(), verified: p['verified'] == true),
          ),
        ),
      ),
    );
    if (ok == true) {
      _changed = true;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ملف المزود'),
          actions: [
            if (_canLink && _data != null)
              IconButton(tooltip: 'ربط مكان', icon: const Icon(Icons.add_link_rounded), onPressed: _linkPlace),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: placeBrass))
            : _error != null && _data == null
                ? Center(child: ErrorRetry(message: _error!, onRetry: _load))
                : RefreshIndicator(color: placeBrass, onRefresh: _load, child: _body()),
        bottomNavigationBar: _data == null || !_canLink ? null : _actions(),
      ),
    );
  }

  Widget? _actions() {
    final p = asMap(_data?['provider']);
    final verified = p['verified'] == true;
    final kyc = p['kycStatus']?.toString();
    if (verified) {
      return Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: placeLine))),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: placeDanger, side: const BorderSide(color: placeDanger)),
          onPressed: _revoke,
          icon: const Icon(Icons.gpp_bad_outlined, size: 19),
          label: const Text('إلغاء التوثيق'),
        ),
      );
    }
    return BottomActionBar(
      label: 'توثيق المزود',
      onPressed: _verify,
      secondaryLabel: kyc == 'REJECTED' ? null : 'رفض',
      onSecondary: _reject,
    );
  }

  Widget _body() {
    final d = _data!;
    final p = asMap(d['provider']);
    final user = asMap(p['user']);
    final stats = asMap(d['stats']);
    final coverage = asMap(d['coverage']);
    final properties = asMapList(d['properties']);
    final recent = asMapList(d['recentBookings']);
    final activities = asMapList(d['recentActivities']);
    final verified = p['verified'] == true;
    final kyc = p['kycStatus']?.toString();
    final name = providerDisplayName(p);
    final phone = user['phone']?.toString();
    final reason = p['rejectionReason']?.toString() ?? '';
    final requestNote = p['requestNote']?.toString() ?? '';
    final placeTypes = (p['placeTypes']?.toString() ?? '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final byStatus = asMapList(stats['bookingsByStatus']);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (!verified && reason.isNotEmpty)
          NoticeBanner(
            title: kyc == 'REJECTED' ? 'تم رفض التوثيق' : 'ملاحظة التوثيق',
            text: reason,
            color: kyc == 'REJECTED' ? placeDanger : placeShiftMorning,
            icon: Icons.report_gmailerrorred_rounded,
          ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: placeLine)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ContactAvatar(name: name, phone: phone, size: 58),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(name,
                                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 19, fontWeight: FontWeight.w900, color: placeInk)),
                            ),
                            if (verified) ...[
                              const SizedBox(width: 5),
                              const Icon(Icons.verified_rounded, size: 19, color: placeSuccess),
                            ],
                          ],
                        ),
                        if ((user['name']?.toString() ?? '').isNotEmpty && user['name'] != name)
                          Text('المالك: ${user['name']}',
                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: placeInk2, fontWeight: FontWeight.w700)),
                        PhoneText(phone),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  StatusPill(label: kycLabel(kyc, verified: verified), color: kycColor(kyc, verified: verified)),
                  if (user['isActive'] == false) const StatusPill(label: 'الحساب موقوف', color: placeDanger, icon: Icons.block_rounded),
                  StatusPill(label: 'منذ ${fmtDate(p['createdAt'])}', color: placeInk2),
                  for (final t in placeTypes) StatusPill(label: placeTypeLabel(t), color: placeBrass, icon: placeTypeIcon(t)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (phone != null && phone.isNotEmpty) ...[
                    ActionChipButton(icon: Icons.call_rounded, label: 'اتصال', color: placeSuccess, onTap: () => callPhone(context, phone)),
                    const SizedBox(width: 8),
                    ActionChipButton(
                      icon: Icons.chat_rounded,
                      label: 'واتساب',
                      color: const Color(0xFF16A34A),
                      onTap: () => openWhatsApp(context, phone),
                    ),
                  ],
                  if (Session.can('users.read') && user['id'] != null) ...[
                    const SizedBox(width: 8),
                    ActionChipButton(
                      icon: Icons.person_outline_rounded,
                      label: 'الحساب',
                      color: placeShiftEvening,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => AdminCustomerDetailScreen(userId: '${user['id']}')),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (requestNote.trim().isNotEmpty)
          FormSection(
            title: 'رسالة طلب الانضمام',
            icon: Icons.mark_email_unread_outlined,
            children: [Text(requestNote, style: const TextStyle(fontFamily: 'Cairo', color: placeInk, height: 1.6))],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Row(
            children: [
              StatTile(label: 'الإيراد المؤكد', value: formatIqd(stats['revenue']), accent: placeSuccess),
              const SizedBox(width: 10),
              StatTile(label: 'حجوزات مؤكدة', value: '${asInt(stats['confirmedBookings'])}'),
            ],
          ),
        ),
        if (byStatus.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in byStatus)
                  StatusPill(
                    label: '${bookingStatusLabel(s['status']?.toString())}: ${asInt(s['count'])}',
                    color: bookingStatusColor(s['status']?.toString()),
                  ),
              ],
            ),
          ),
        if (asInt(coverage['totalSlots']) > 0) _CoverageCard(coverage: coverage),
        SectionLabel('الأماكن', trailing: Text('${properties.length}', style: const TextStyle(color: placeInk2))),
        if (properties.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text('لا أماكن مرتبطة بهذا المزود', style: TextStyle(fontFamily: 'Cairo', color: placeInk2)),
                ),
                if (_canLink) TextButton.icon(onPressed: _linkPlace, icon: const Icon(Icons.add_link_rounded, size: 18), label: const Text('ربط مكان')),
              ],
            ),
          )
        else
          for (final prop in properties) _PlaceRow(property: prop),
        if (recent.isNotEmpty) ...[
          const SectionLabel('آخر الحجوزات'),
          for (final b in recent) BookingMiniCard(booking: b, showCustomer: true),
        ],
        if (activities.isNotEmpty) ...[
          const SectionLabel('سجل الإجراءات'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: placeLine)),
            child: Column(
              children: [
                for (var i = 0; i < activities.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: placeLine),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.history_rounded, color: placeInk2, size: 20),
                    title: Text(_activityLabel(activities[i]['action']?.toString()),
                        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
                    subtitle: Text(
                      '${nonEmpty(asMap(activities[i]['user'])['name'], '')} · ${fmtDateTime(activities[i]['createdAt'])}',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _activityLabel(String? a) => switch (a) {
        'provider.verify' => 'توثيق المزود',
        'provider.reject' => 'رفض التوثيق',
        'provider.revoke' => 'إلغاء التوثيق',
        'placeClaim.link' || 'placeClaim.approve' => 'ربط مكان',
        _ => a ?? '—',
      };
}

class _CoverageCard extends StatelessWidget {
  const _CoverageCard({required this.coverage});
  final Map<String, dynamic> coverage;

  @override
  Widget build(BuildContext context) {
    final total = asInt(coverage['totalSlots']);
    final platform = asInt(coverage['platformDays']);
    final external = asInt(coverage['externalDays']);
    final closed = asInt(coverage['closedDays']);
    final open = asInt(coverage['openDays']);
    double f(int v) => total == 0 ? 0 : v / total;
    return FormSection(
      title: 'إشغال ${asInt(coverage['days'])} يوماً القادمة',
      subtitle: '${asInt(coverage['propertyCount'])} مكان · $total يوم-مكان',
      icon: Icons.insights_outlined,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                if (platform > 0) Expanded(flex: (f(platform) * 1000).round(), child: Container(color: placeSuccess)),
                if (external > 0) Expanded(flex: (f(external) * 1000).round(), child: Container(color: placeShiftEvening)),
                if (closed > 0) Expanded(flex: (f(closed) * 1000).round(), child: Container(color: placeInk2)),
                if (open > 0) Expanded(flex: (f(open) * 1000).round(), child: Container(color: placeLine)),
              ],
            ),
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _legend('حجوزات المنصة', platform, placeSuccess),
            _legend('حجوزات خارجية', external, placeShiftEvening),
            _legend('مغلق', closed, placeInk2),
            _legend('متاح', open, placeLine),
          ],
        ),
      ],
    );
  }

  Widget _legend(String label, int v, Color c) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 5),
          Text('$label $v', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.w700, color: placeInk2)),
        ],
      );
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.property});
  final Map<String, dynamic> property;

  @override
  Widget build(BuildContext context) {
    final p = property;
    final media = asMapList(p['media']);
    final cover = media.isEmpty ? null : absUrl(media.first['thumbnailUrl'] ?? media.first['url']);
    final count = asMap(p['_count']);
    final status = p['status']?.toString();
    final canOpen = Session.can('properties.read');
    return ListCard(
      onTap: canOpen
          ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PropertyDetailScreen(propertyId: '${p['id']}')))
          : null,
      child: Row(
        children: [
          SizedBox(width: 64, height: 64, child: NetImage(url: cover, radius: 12, icon: placeTypeIcon(p['type']?.toString()))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nonEmpty(p['name'], 'مكان'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: placeInk)),
                Text(
                  '${placeTypeLabel(p['type']?.toString())} · ${nonEmpty(asMap(p['city'])['nameAr'], '')}',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    StatusPill(label: placeStatusLabel(status), color: placeStatusColor(status)),
                    StatusPill(label: '${asInt(count['bookings'])} حجز', color: placeInk2),
                  ],
                ),
              ],
            ),
          ),
          if (canOpen) const Icon(Icons.chevron_left_rounded, color: placeInk2),
        ],
      ),
    );
  }
}
