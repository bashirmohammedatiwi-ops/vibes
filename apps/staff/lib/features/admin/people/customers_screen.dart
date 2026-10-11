import 'package:flutter/material.dart';

import '../../../core/api.dart';
import '../../../core/format.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/chat_ui.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/ui.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('الزبائن والحسابات')),
      body: Column(
        children: [
          SearchBox(hint: 'الاسم أو رقم الهاتف', onChanged: (v) => setState(() => _q = v)),
          FilterBar(groups: [
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
          if (_total != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 2),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('$_total حساب', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: placeInk2)),
              ),
            ),
          Expanded(
            child: PagedList(
              key: ValueKey('$_q|$_role|$_active'),
              controller: _list,
              fetch: _fetch,
              onLoaded: (r) => setState(() => _total = r.total),
              emptyTitle: _q.isEmpty ? 'لا حسابات' : 'لا نتائج',
              emptySubtitle: _q.isEmpty ? 'غيّر الفلتر لعرض حسابات أخرى' : 'جرّب اسماً أو رقماً آخر',
              itemBuilder: (context, u, _) => _UserCard(user: u, onTap: () => _open(u)),
            ),
          ),
        ],
      ),
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
      child: Row(
        children: [
          Opacity(opacity: active ? 1 : 0.5, child: ContactAvatar(name: name, phone: phone, size: 46)),
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
                    if (provider['verified'] == true) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, size: 16, color: placeSuccess),
                    ],
                  ],
                ),
                PhoneText(phone),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    StatusPill(label: roleLabel(role), color: roleColor(role)),
                    if (!active) const StatusPill(label: 'موقوف', color: placeDanger, icon: Icons.block_rounded),
                    StatusPill(label: '${asInt(count['bookings'])} حجز', color: placeInk2, icon: Icons.event_note_outlined),
                  ],
                ),
              ],
            ),
          ),
          PhoneButtons(phone: phone, compact: true),
        ],
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ملف الحساب'),
          actions: [
            if (_editable && _user != null)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (v) => v == 'name' ? _editName() : _toggleActive(),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'name', child: Text('تعديل الاسم')),
                  PopupMenuItem(
                    value: 'active',
                    child: Text(_user?['isActive'] == false ? 'إعادة التفعيل' : 'إيقاف الحساب'),
                  ),
                ],
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: placeBrass))
            : _error != null && _user == null
                ? Center(child: ErrorRetry(message: _error!, onRetry: _load))
                : RefreshIndicator(color: placeBrass, onRefresh: _load, child: _body()),
      ),
    );
  }

  Widget _body() {
    final u = _user!;
    final name = nonEmpty(u['name'], 'بدون اسم');
    final phone = u['phone']?.toString();
    final role = u['role']?.toString();
    final active = u['isActive'] != false;
    final count = asMap(u['_count']);
    final provider = asMap(u['provider']);
    final bookings = asMapList(u['bookings']);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (!active)
          const NoticeBanner(
            title: 'الحساب موقوف',
            text: 'لا يستطيع صاحب الحساب تسجيل الدخول أو إنشاء حجوزات جديدة.',
            color: placeDanger,
            icon: Icons.block_rounded,
          ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: placeLine)),
          child: Column(
            children: [
              ContactAvatar(name: name, phone: phone, size: 72),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 21, fontWeight: FontWeight.w900, color: placeInk)),
                  ),
                  if (_editable)
                    IconButton(
                      onPressed: _editName,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined, size: 18, color: placeInk2),
                    ),
                ],
              ),
              PhoneText(phone, style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700, color: placeInk2)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  StatusPill(label: roleLabel(role), color: roleColor(role)),
                  StatusPill(
                    label: active ? 'نشط' : 'موقوف',
                    color: active ? placeSuccess : placeDanger,
                    icon: active ? Icons.check_circle_outline : Icons.block_rounded,
                  ),
                  StatusPill(label: 'منذ ${fmtDate(u['createdAt'])}', color: placeInk2),
                ],
              ),
              const SizedBox(height: 16),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Row(
            children: [
              StatTile(label: 'الحجوزات', value: '${asInt(count['bookings'])}'),
              const SizedBox(width: 10),
              StatTile(label: 'التقييمات', value: '${asInt(count['reviews'])}', accent: placeBrass),
            ],
          ),
        ),
        if (provider.isNotEmpty)
          FormSection(
            title: 'حساب مزود',
            icon: Icons.storefront_outlined,
            children: [
              InfoRow(label: 'الاسم التجاري', value: nonEmpty(provider['businessName'])),
              InfoRow(
                label: 'التوثيق',
                value: kycLabel(provider['kycStatus']?.toString(), verified: provider['verified'] == true),
                valueColor: kycColor(provider['kycStatus']?.toString(), verified: provider['verified'] == true),
              ),
              if (Session.can('providers.read'))
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => AdminProviderDetailScreen(providerId: '${provider['id']}')),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('ملف المزود'),
                ),
            ],
          ),
        SectionLabel('آخر الحجوزات', trailing: Text('${bookings.length}', style: const TextStyle(color: placeInk2))),
        if (bookings.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text('لا حجوزات لهذا الحساب بعد', style: TextStyle(fontFamily: 'Cairo', color: placeInk2)),
          )
        else
          for (final b in bookings) BookingMiniCard(booking: b),
        if (_editable) ...[
          SectionLabel('إدارة الحساب'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _editName,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('تعديل الاسم'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: active ? placeDanger : placeSuccess),
                    onPressed: _toggleActive,
                    icon: Icon(active ? Icons.block_rounded : Icons.check_circle_outline, size: 18),
                    label: Text(active ? 'إيقاف الحساب' : 'إعادة التفعيل'),
                  ),
                ),
              ],
            ),
          ),
        ] else if (Session.can('users.write') && (role == 'ADMIN' || role == 'STAFF'))
          const NoticeBanner(
            text: 'حسابات الإدارة والموظفين يعدّلها المدير فقط من لوحة التحكم.',
            color: placeInk2,
            icon: Icons.lock_outline_rounded,
          ),
      ],
    );
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
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: bookingStatusColor(status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.event_note_outlined, color: bookingStatusColor(status), size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nonEmpty(asMap(b['property'])['name'], 'حجز'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: placeInk),
                ),
                Text(
                  [
                    if (showCustomer) nonEmpty(user['name'] ?? b['guestName'], ''),
                    fmtDay(b['startDate']),
                    formatIqd(b['totalPrice']),
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusPill(label: bookingStatusLabel(status), color: bookingStatusColor(status)),
              if (payment['status'] != null) ...[
                const SizedBox(height: 4),
                StatusPill(
                  label: paymentStatusAr(payment['status']?.toString()),
                  color: paymentStatusColor(payment['status']?.toString()),
                ),
              ],
            ],
          ),
          if (canOpen) const Icon(Icons.chevron_left_rounded, color: placeInk2),
        ],
      ),
    );
  }
}
