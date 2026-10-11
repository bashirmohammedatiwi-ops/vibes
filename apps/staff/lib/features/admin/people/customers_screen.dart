import 'package:flutter/material.dart';

import '../../../core/api.dart';
import '../../../core/format.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/kit.dart';
import '../../chat_room.dart';
import '../../ops/ops_booking_detail.dart';
import 'people_common.dart';
import 'providers_screen.dart';

/// قائمة الحسابات (زبائن ومزودون) — `users.read`.
class AdminCustomersScreen extends StatefulWidget {
  const AdminCustomersScreen({super.key});

  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  final _list = PagedListController();
  String _q = '';
  String _role = 'CUSTOMER';
  String _active = 'all';
  int? _total;

  Future<PageResult> _fetch(int page) => fetchPage(
        '/api/admin/users',
        {
          'q': _q,
          'role': _role == 'all' ? null : _role,
          'isActive': switch (_active) { 'active' => 'true', 'blocked' => 'false', _ => null },
        },
        page: page,
      );

  Future<void> _open(Map<String, dynamic> user) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AdminCustomerDetailScreen(userId: '${user['id']}')),
    );
    if (changed == true) _list.reload();
  }

  @override
  Widget build(BuildContext context) {
    return PagedStaffPage(
      title: 'الزبائن والحسابات',
      subtitle: _total == null ? null : '$_total حساب',
      resetKey: '$_q|$_role|$_active',
      controller: _list,
      fetch: _fetch,
      onLoaded: (r) => setState(() => _total = r.total),
      search: SearchBox(
        hint: 'الاسم أو رقم الهاتف',
        padding: SearchBox.barPadding,
        onChanged: (v) => setState(() => _q = v),
      ),
      filters: FilterBar(groups: [
        FilterGroup(
          options: const ['CUSTOMER', 'PROVIDER', 'all'],
          selected: _role,
          labelOf: (v) => switch (v) { 'CUSTOMER' => 'زبائن', 'PROVIDER' => 'مزودون', _ => 'الكل' },
          onSelected: (v) => setState(() => _role = v),
        ),
        FilterGroup(
          options: const ['all', 'active', 'blocked'],
          selected: _active,
          labelOf: (v) => switch (v) { 'active' => 'نشط', 'blocked' => 'موقوف', _ => 'كل الحالات' },
          onSelected: (v) => setState(() => _active = v),
        ),
      ]),
      emptyIcon: _q.isEmpty ? Icons.people_outline_rounded : Icons.search_off_rounded,
      emptyTitle: _q.isEmpty ? 'لا حسابات' : 'لا نتائج',
      emptySubtitle: _q.isEmpty ? 'غيّر الفلتر لعرض حسابات أخرى' : 'جرّب اسماً أو رقماً آخر',
      itemBuilder: (context, u, _) => _UserCard(user: u, onTap: () => _open(u)),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.onTap});
  final Map<String, dynamic> user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = nonEmpty(user['name'], 'بدون اسم');
    final phone = user['phone']?.toString();
    final role = user['role']?.toString();
    final active = user['isActive'] != false;
    final count = asMap(user['_count']);
    final provider = asMap(user['provider']);
    return ListCard(
      onTap: onTap,
      child: ListRow(
        leading: Opacity(opacity: active ? 1 : 0.5, child: Avatar(name, size: 46, color: roleColor(role))),
        title: name,
        titleBadge: provider['verified'] == true ? const Icon(Icons.verified_rounded, size: 16, color: placeSuccess) : null,
        subtitleWidget: (phone ?? '').isEmpty ? null : PhoneText(phone),
        chips: [
          StatusChip(roleLabel(role), color: roleColor(role), dense: true),
          if (!active) const StatusChip('موقوف', color: placeDanger, dense: true),
          StatusChip('${asInt(count['bookings'])} حجز', color: placeInk2, dense: true),
        ],
        trailing: PhoneButtons(phone: phone, compact: true),
      ),
    );
  }
}

/// ملف حساب: بيانات، إحصاءات، آخر الحجوزات، تعديل الاسم، إيقاف/تفعيل.
class AdminCustomerDetailScreen extends StatefulWidget {
  const AdminCustomerDetailScreen({super.key, required this.userId});
  final String userId;

  @override
  State<AdminCustomerDetailScreen> createState() => _AdminCustomerDetailScreenState();
}

class _AdminCustomerDetailScreenState extends State<AdminCustomerDetailScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _user == null;
      _error = null;
    });
    try {
      final data = await Api.map('/api/admin/users/${widget.userId}');
      if (!mounted) return;
      setState(() {
        _user = data;
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

  bool get _editable {
    final role = _user?['role']?.toString();
    return Session.can('users.write') && (role == 'CUSTOMER' || role == 'PROVIDER');
  }

  Future<void> _patch(Map<String, dynamic> body, String success) async {
    final ok = await runAction(context, () async {
      await withBusy(context, () => Api.map('/api/admin/users/${widget.userId}', method: 'PATCH', body: body));
    }, success: success);
    if (ok) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _editName() async {
    final name = await showInputSheet(
      context,
      title: 'تعديل الاسم',
      label: 'الاسم',
      initial: _user?['name']?.toString() ?? '',
      required: true,
      minLength: 2,
    );
    if (name == null || name == _user?['name']) return;
    await _patch({'name': name}, 'تم حفظ الاسم');
  }

  Future<void> _toggleActive() async {
    final active = _user?['isActive'] != false;
    final name = nonEmpty(_user?['name'], 'هذا الحساب');
    final ok = await confirmDialog(
      context,
      title: active ? 'إيقاف الحساب؟' : 'إعادة تفعيل الحساب؟',
      message: active
          ? 'سيتم إيقاف «$name» وتسجيل خروجه من كل الأجهزة، ولن يتمكن من الدخول أو الحجز حتى تعيد تفعيله.'
          : 'سيتمكن «$name» من تسجيل الدخول والحجز مجدداً.',
      confirmLabel: active ? 'إيقاف' : 'تفعيل',
      danger: active,
    );
    if (!ok || !mounted) return;
    await _patch({'isActive': !active}, active ? 'تم إيقاف الحساب' : 'تم تفعيل الحساب');
  }

  void _openChat() {
    final u = _user!;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatRoomScreen(
        contactUserId: '${u['id']}',
        contactName: nonEmpty(u['name'], u['phone']?.toString() ?? 'زبون'),
        contactPhone: u['phone']?.toString(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        bottomNavigationBar: u != null && _editable ? _actionBar(u['isActive'] != false) : null,
        body: StaffPage(
          title: 'ملف الحساب',
          onRefresh: u == null ? null : _load,
          slivers: _loading
              ? const [SliverToBoxAdapter(child: SizedBox(height: 4)), SkeletonSliver(count: 4, height: 120)]
              : _error != null && u == null
                  ? [SliverToBoxAdapter(child: ErrorRetry(message: _error!, onRetry: _load))]
                  : _body(u!),
        ),
      ),
    );
  }

  Widget _actionBar(bool active) {
    return ActionBarShell(
      child: Row(
        children: [
          Expanded(
            child: BarButton(label: 'تعديل الاسم', icon: Icons.edit_outlined, outlined: true, onPressed: _editName),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: BarButton(
              label: active ? 'إيقاف الحساب' : 'إعادة التفعيل',
              icon: active ? Icons.block_rounded : Icons.check_circle_outline,
              color: active ? placeDanger : placeSuccess,
              onPressed: _toggleActive,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(Map<String, dynamic> u) {
    final name = nonEmpty(u['name'], 'بدون اسم');
    final phone = u['phone']?.toString();
    final role = u['role']?.toString();
    final active = u['isActive'] != false;
    final count = asMap(u['_count']);
    final provider = asMap(u['provider']);
    final bookings = asMapList(u['bookings']);

    return [
      const SliverToBoxAdapter(child: SizedBox(height: 4)),
      if (!active)
        const SliverToBoxAdapter(
          child: NoticeBanner(
            title: 'الحساب موقوف',
            text: 'لا يستطيع صاحب الحساب تسجيل الدخول أو إنشاء حجوزات جديدة.',
            color: placeDanger,
            icon: Icons.block_rounded,
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
                    Avatar(name, size: 60, color: roleColor(role)),
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
                              if (_editable)
                                IconButton(
                                  tooltip: 'تعديل الاسم',
                                  onPressed: _editName,
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: placeInk2),
                                ),
                            ],
                          ),
                          if ((phone ?? '').isNotEmpty)
                            PhoneText(phone, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 14, fontWeight: FontWeight.w600, color: placeInk2)),
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
                    StatusChip(roleLabel(role), color: roleColor(role)),
                    StatusChip(active ? 'نشط' : 'موقوف', color: active ? placeSuccess : placeDanger),
                    StatusChip('منذ ${fmtDate(u['createdAt'])}', color: placeInk2),
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
                    if (Session.can('inbox.read')) ...[
                      const SizedBox(width: 8),
                      ActionChipButton(icon: Icons.forum_outlined, label: 'محادثة', color: placeShiftEvening, onTap: _openChat),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      // ── مؤشرات ──
      SliverToBoxAdapter(
        child: Pad(
          child: Row(
            children: [
              Expanded(child: KpiTile(label: 'الحجوزات', value: '${asInt(count['bookings'])}', icon: Icons.event_note_rounded, color: placeInfo)),
              const SizedBox(width: 10),
              Expanded(child: KpiTile(label: 'التقييمات', value: '${asInt(count['reviews'])}', icon: Icons.star_rounded, color: placeBrass)),
            ],
          ),
        ),
      ),
      if (provider.isNotEmpty)
        SliverToBoxAdapter(
          child: DetailCard(
            title: 'حساب مزود',
            icon: Icons.storefront_rounded,
            color: placeSuccess,
            children: [
              DetailRow(label: 'الاسم التجاري', value: nonEmpty(provider['businessName'])),
              DetailRow(
                label: 'التوثيق',
                value: kycLabel(provider['kycStatus']?.toString(), verified: provider['verified'] == true),
                valueColor: kycColor(provider['kycStatus']?.toString(), verified: provider['verified'] == true),
              ),
              if (Session.can('providers.read')) ...[
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => AdminProviderDetailScreen(providerId: '${provider['id']}')),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('ملف المزود'),
                ),
              ],
            ],
          ),
        ),
      SliverToBoxAdapter(child: SectionLabel('آخر الحجوزات', count: bookings.length)),
      if (bookings.isEmpty)
        const SliverToBoxAdapter(
          child: Pad(
            child: StaffCard(
              child: Row(
                children: [
                  IconBox(icon: Icons.event_busy_rounded, color: placeInk3),
                  SizedBox(width: 12),
                  Expanded(child: Text('لا حجوزات لهذا الحساب بعد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: placeInk2))),
                ],
              ),
            ),
          ),
        )
      else
        SliverList.list(children: [for (final b in bookings) BookingMiniCard(booking: b)]),
      if (!_editable && Session.can('users.write') && (role == 'ADMIN' || role == 'STAFF'))
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 6),
            child: NoticeBanner(
              text: 'حسابات الإدارة والموظفين يعدّلها المدير فقط من لوحة التحكم.',
              color: placeInk2,
              icon: Icons.lock_outline_rounded,
            ),
          ),
        ),
    ];
  }
}

/// بطاقة حجز مختصرة تفتح تفاصيل الحجز.
class BookingMiniCard extends StatelessWidget {
  const BookingMiniCard({super.key, required this.booking, this.showCustomer = false});
  final Map<String, dynamic> booking;
  final bool showCustomer;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final status = b['status']?.toString();
    final user = asMap(b['user']);
    final payment = asMap(b['payment']);
    final canOpen = Session.can('bookings.read') && b['id'] != null;
    return ListCard(
      onTap: canOpen
          ? () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => OpsBookingDetailScreen(bookingId: '${b['id']}')),
              )
          : null,
      child: ListRow(
        leading: IconBox(icon: Icons.event_note_rounded, color: bookingStatusColor(status), size: 42),
        title: nonEmpty(asMap(b['property'])['name'], 'حجز'),
        subtitle: [
          if (showCustomer) nonEmpty(user['name'] ?? b['guestName'], ''),
          fmtDay(b['startDate']),
          formatIqd(b['totalPrice']),
        ].where((s) => s.isNotEmpty).join(' · '),
        chips: [
          StatusChip(bookingStatusLabel(status), color: bookingStatusColor(status), dense: true),
          if (payment['status'] != null)
            StatusChip(
              paymentStatusAr(payment['status']?.toString()),
              color: paymentStatusColor(payment['status']?.toString()),
              dense: true,
            ),
        ],
        chevron: canOpen,
      ),
    );
  }
}
