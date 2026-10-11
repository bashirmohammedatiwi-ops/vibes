import 'package:flutter/material.dart';

import '../../../core/api.dart';
import '../../../core/format.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/kit.dart';
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
    return PagedStaffPage(
      title: 'المزودون',
      subtitle: _total == null ? null : '$_total مزود',
      actions: [
        IconButton(
          tooltip: 'طلبات ربط الأماكن',
          icon: const Icon(Icons.how_to_reg_rounded),
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
      resetKey: '$_q|$_kyc',
      controller: _list,
      fetch: _fetch,
      onLoaded: (r) => setState(() => _total = r.total),
      search: SearchBox(
        hint: 'الاسم التجاري، المالك أو الهاتف',
        padding: SearchBox.barPadding,
        onChanged: (v) => setState(() => _q = v),
      ),
      filters: FilterBar(groups: [
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
      emptyIcon: _kyc == 'pending' ? Icons.verified_user_outlined : Icons.storefront_outlined,
      emptyTitle: _kyc == 'pending' ? 'لا طلبات توثيق معلّقة' : 'لا مزودين',
      emptySubtitle: _q.isEmpty ? null : 'جرّب بحثاً آخر',
      itemBuilder: (context, p, _) => _ProviderCard(provider: p, onTap: () => _open(p)),
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
    final phone = user['phone']?.toString();
    return ListCard(
      onTap: onTap,
      child: ListRow(
        leading: Avatar(name, size: 46, color: placeBrass),
        title: name,
        titleBadge: verified ? const Icon(Icons.verified_rounded, size: 16, color: placeSuccess) : null,
        subtitle: owner.isNotEmpty && owner != name ? owner : null,
        subtitleWidget: (phone ?? '').isEmpty ? null : PhoneText(phone),
        chips: [
          StatusChip(kycLabel(kyc, verified: verified), color: kycColor(kyc, verified: verified), dense: true),
          StatusChip('${asInt(asMap(p['_count'])['properties'])} مكان', color: placeInk2, dense: true),
        ],
        trailing: MetaText(relativeAr(p['createdAt'])),
        chevron: true,
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
    final d = _data;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        bottomNavigationBar: d == null || !_canLink ? null : _actions(),
        body: StaffPage(
          title: 'ملف المزود',
          onRefresh: d == null ? null : _load,
          actions: [
            if (_canLink && d != null)
              IconButton(tooltip: 'ربط مكان', icon: const Icon(Icons.add_link_rounded), onPressed: _linkPlace),
          ],
          slivers: _loading
              ? const [SliverToBoxAdapter(child: SizedBox(height: 4)), SkeletonSliver(count: 4, height: 120)]
              : _error != null && d == null
                  ? [SliverToBoxAdapter(child: ErrorRetry(message: _error!, onRetry: _load))]
                  : _body(d!),
        ),
      ),
    );
  }

  Widget? _actions() {
    final p = asMap(_data?['provider']);
    final verified = p['verified'] == true;
    final kyc = p['kycStatus']?.toString();
    if (verified) {
      return ActionBarShell(
        child: BarButton(
          label: 'إلغاء التوثيق',
          icon: Icons.gpp_bad_outlined,
          color: placeDanger,
          outlined: true,
          onPressed: _revoke,
        ),
      );
    }
    return ActionBarShell(
      child: Row(
        children: [
          if (kyc != 'REJECTED') ...[
            Expanded(
              child: BarButton(label: 'رفض', icon: Icons.close_rounded, color: placeDanger, outlined: true, onPressed: _reject),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 2,
            child: BarButton(label: 'توثيق المزود', icon: Icons.verified_rounded, color: placeSuccess, onPressed: _verify),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(Map<String, dynamic> d) {
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

    return [
      const SliverToBoxAdapter(child: SizedBox(height: 4)),
      if (!verified && reason.isNotEmpty)
        SliverToBoxAdapter(
          child: NoticeBanner(
            title: kyc == 'REJECTED' ? 'تم رفض التوثيق' : 'ملاحظة التوثيق',
            text: reason,
            color: kyc == 'REJECTED' ? placeDanger : placeWarning,
            icon: Icons.report_gmailerrorred_rounded,
          ),
        ),
      // ── بطاقة الهوية ──
      SliverToBoxAdapter(
        child: Pad(
          child: StaffCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Avatar(name, size: 60, color: placeBrass),
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
                          if ((phone ?? '').isNotEmpty) PhoneText(phone),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    StatusChip(kycLabel(kyc, verified: verified), color: kycColor(kyc, verified: verified)),
                    if (user['isActive'] == false) const StatusChip('الحساب موقوف', color: placeDanger),
                    StatusChip('منذ ${fmtDate(p['createdAt'])}', color: placeInk2),
                    for (final t in placeTypes) StatusChip(placeTypeLabel(t), color: placeBrass),
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
        ),
      ),
      if (requestNote.trim().isNotEmpty)
        SliverToBoxAdapter(
          child: DetailCard(
            title: 'رسالة طلب الانضمام',
            icon: Icons.mark_email_unread_outlined,
            color: placeInfo,
            children: [Text(requestNote, style: const TextStyle(fontFamily: 'Cairo', color: placeInk, height: 1.6))],
          ),
        ),
      // ── مؤشرات ──
      SliverToBoxAdapter(
        child: Pad(
          child: Row(
            children: [
              Expanded(
                child: KpiTile(label: 'الإيراد المؤكد', value: formatIqd(stats['revenue']), icon: Icons.account_balance_wallet_rounded, color: placeSuccess),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: KpiTile(label: 'حجوزات مؤكدة', value: '${asInt(stats['confirmedBookings'])}', icon: Icons.event_available_rounded, color: placeInfo),
              ),
            ],
          ),
        ),
      ),
      if (byStatus.isNotEmpty)
        SliverToBoxAdapter(
          child: Pad(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in byStatus)
                  StatusChip(
                    '${bookingStatusLabel(s['status']?.toString())}: ${asInt(s['count'])}',
                    color: bookingStatusColor(s['status']?.toString()),
                  ),
              ],
            ),
          ),
        ),
      if (asInt(coverage['totalSlots']) > 0) SliverToBoxAdapter(child: _CoverageCard(coverage: coverage)),
      SliverToBoxAdapter(
        child: SectionLabel(
          'الأماكن',
          count: properties.length,
          trailing: _canLink && properties.isNotEmpty
              ? TextButton.icon(onPressed: _linkPlace, icon: const Icon(Icons.add_link_rounded, size: 18), label: const Text('ربط مكان'))
              : null,
        ),
      ),
      if (properties.isEmpty)
        SliverToBoxAdapter(
          child: Pad(
            child: StaffCard(
              child: Row(
                children: [
                  const IconBox(icon: Icons.home_work_outlined, color: placeInk3),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('لا أماكن مرتبطة بهذا المزود',
                        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: placeInk2)),
                  ),
                  if (_canLink)
                    TextButton.icon(onPressed: _linkPlace, icon: const Icon(Icons.add_link_rounded, size: 18), label: const Text('ربط مكان')),
                ],
              ),
            ),
          ),
        )
      else
        SliverList.list(children: [for (final prop in properties) _PlaceRow(property: prop)]),
      if (recent.isNotEmpty) ...[
        SliverToBoxAdapter(child: SectionLabel('آخر الحجوزات', count: recent.length)),
        SliverList.list(children: [for (final b in recent) BookingMiniCard(booking: b, showCustomer: true)]),
      ],
      if (activities.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SectionLabel('سجل الإجراءات')),
        SliverToBoxAdapter(
          child: Pad(
            child: TileGroup(
              children: [
                for (final a in activities)
                  TaskTile(
                    icon: Icons.history_rounded,
                    color: placeInk2,
                    title: _activityLabel(a['action']?.toString()),
                    subtitle: [nonEmpty(asMap(a['user'])['name'], ''), fmtDateTime(a['createdAt'])].where((s) => s.isNotEmpty).join(' · '),
                    trailing: const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ),
      ],
    ];
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
    return DetailCard(
      title: 'إشغال ${asInt(coverage['days'])} يوماً القادمة',
      subtitle: '${asInt(coverage['propertyCount'])} مكان · $total يوم-مكان',
      icon: Icons.insights_rounded,
      color: placeShiftEvening,
      children: [
        const SizedBox(height: 4),
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
        const SizedBox(height: 10),
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
        const SizedBox(height: 4),
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
      child: ListRow(
        leading: SizedBox(width: 60, height: 60, child: NetImage(url: cover, radius: StaffRadius.md, icon: placeTypeIcon(p['type']?.toString()))),
        title: nonEmpty(p['name'], 'مكان'),
        subtitle: [placeTypeLabel(p['type']?.toString()), nonEmpty(asMap(p['city'])['nameAr'], '')].where((s) => s.isNotEmpty).join(' · '),
        chips: [
          StatusChip(placeStatusLabel(status), color: placeStatusColor(status), dense: true),
          StatusChip('${asInt(count['bookings'])} حجز', color: placeInk2, dense: true),
        ],
        chevron: canOpen,
      ),
    );
  }
}
