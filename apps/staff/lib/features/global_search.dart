import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/form_kit.dart';
import '../widgets/ui.dart';
import 'admin/bookings/booking_manage.dart';
import 'admin/people/customers_screen.dart';
import 'admin/people/payment_detail.dart';
import 'admin/people/providers_screen.dart';
import 'ops/property_detail.dart';

/// بحث شامل — حجوزات وزبائن وأماكن ومدفوعات ومزودون من حقل واحد.
/// الخادم يعيد فقط الأقسام التي تسمح بها صلاحيات الموظف.
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _field = TextEditingController();
  Timer? _debounce;
  Map<String, dynamic> _results = {};
  bool _loading = false;
  String _lastQuery = '';
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String raw) async {
    final q = raw.trim();
    if (q == _lastQuery) return;
    _lastQuery = q;
    if (q.length < 2) {
      setState(() {
        _results = {};
        _error = null;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await Api.map(
        '/api/admin/search?q=${Uri.encodeQueryComponent(q)}',
      );
      if (!mounted || q != _lastQuery) return;
      setState(() {
        _results = data;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _section(String key) =>
      (_results[key] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  String _date(dynamic v) {
    final d = DateTime.tryParse(v?.toString() ?? '');
    if (d == null) return '';
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bookings = _section('bookings');
    final users = _section('users');
    final properties = _section('properties');
    final payments = _section('payments');
    final providers = _section('providers');
    final empty =
        bookings.isEmpty &&
        users.isEmpty &&
        properties.isEmpty &&
        payments.isEmpty &&
        providers.isEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _field,
          autofocus: true,
          onChanged: _onChanged,
          onSubmitted: _search,
          textInputAction: TextInputAction.search,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: 'هاتف، اسم زبون، مكان، رقم حوالة…',
            border: InputBorder.none,
            suffixIcon: _field.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _field.clear();
                      _search('');
                    },
                  ),
          ),
        ),
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: _lastQuery.length < 2
          ? const _Hint()
          : _error != null
          ? EmptyState(title: 'تعذّر البحث', subtitle: _error)
          : empty && !_loading
          ? const EmptyState(
              title: 'لا نتائج',
              subtitle: 'جرّب جزءاً من الرقم أو الاسم',
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (bookings.isNotEmpty) ...[
                  const _Head('الحجوزات', Icons.event_available_rounded),
                  for (final b in bookings)
                    _ResultTile(
                      icon: Icons.event_note_rounded,
                      title:
                          (b['property'] as Map?)?['name']?.toString() ?? 'حجز',
                      subtitle: [
                        (b['user'] as Map?)?['name'] ??
                            (b['user'] as Map?)?['phone'] ??
                            '',
                        _date(b['startDate']),
                      ].where((e) => '$e'.isNotEmpty).join(' · '),
                      trailing: StatusPill(
                        label: bookingStatusLabel(b['status']?.toString()),
                        color: placeInk,
                      ),
                      onTap: () => _open(
                        BookingManageScreen(bookingId: b['id'].toString()),
                      ),
                    ),
                ],
                if (users.isNotEmpty) ...[
                  const _Head('الحسابات', Icons.people_alt_rounded),
                  for (final u in users)
                    _ResultTile(
                      icon: Icons.person_rounded,
                      title: u['name']?.toString().isNotEmpty == true
                          ? u['name'].toString()
                          : 'بدون اسم',
                      subtitle:
                          '${u['phone'] ?? ''} · ${_role(u['role']?.toString())}',
                      onTap: () => _open(
                        AdminCustomerDetailScreen(userId: u['id'].toString()),
                      ),
                    ),
                ],
                if (properties.isNotEmpty) ...[
                  const _Head('الأماكن', Icons.home_work_rounded),
                  for (final p in properties)
                    _ResultTile(
                      icon: placeTypeIcon(p['type']?.toString()),
                      title: p['name']?.toString() ?? '',
                      subtitle: placeTypeLabel(p['type']?.toString()),
                      trailing: StatusPill(
                        label: placeStatusLabel(p['status']?.toString()),
                        color: placeStatusColor(p['status']?.toString()),
                      ),
                      onTap: () => _open(
                        PropertyDetailScreen(propertyId: p['id'].toString()),
                      ),
                    ),
                ],
                if (payments.isNotEmpty) ...[
                  const _Head('المدفوعات', Icons.payments_rounded),
                  for (final p in payments)
                    _ResultTile(
                      icon: Icons.receipt_rounded,
                      title: '${p['amount'] ?? ''} د.ع',
                      subtitle: [
                        ((p['booking'] as Map?)?['property']
                                as Map?)?['name'] ??
                            '',
                        ((p['booking'] as Map?)?['user'] as Map?)?['phone'] ??
                            '',
                      ].where((e) => '$e'.isNotEmpty).join(' · '),
                      trailing: StatusPill(
                        label: p['status']?.toString() ?? '',
                        color: placeBrass,
                      ),
                      onTap: () => _open(
                        AdminPaymentDetailScreen(paymentId: p['id'].toString()),
                      ),
                    ),
                ],
                if (providers.isNotEmpty) ...[
                  const _Head('المزودون', Icons.storefront_rounded),
                  for (final p in providers)
                    _ResultTile(
                      icon: Icons.store_rounded,
                      title: p['businessName']?.toString() ?? '',
                      subtitle: (p['user'] as Map?)?['phone']?.toString() ?? '',
                      trailing: p['verified'] == true
                          ? const Icon(
                              Icons.verified_rounded,
                              color: placeBrass,
                              size: 20,
                            )
                          : null,
                      onTap: () => _open(
                        AdminProviderDetailScreen(
                          providerId: p['id'].toString(),
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  String _role(String? role) => switch (role) {
    'PROVIDER' => 'مزود',
    'STAFF' => 'موظف',
    'ADMIN' => 'مدير',
    _ => 'زبون',
  };
}

String bookingStatusLabel(String? status) => switch (status) {
  'PENDING' => 'بانتظار التأكيد',
  'AWAITING_PAYMENT' => 'بانتظار الدفع',
  'CONFIRMED' => 'مؤكد',
  'COMPLETED' => 'مكتمل',
  'CANCELLED' => 'ملغى',
  'DISPUTED' => 'نزاع',
  _ => status ?? '',
};

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: const [
        SizedBox(height: 40),
        Icon(Icons.manage_search_rounded, size: 56, color: placeBrass),
        SizedBox(height: 14),
        Text(
          'ابحث في كل شيء من مكان واحد',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: placeInk,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'رقم هاتف الزبون، اسمه، اسم المكان، اسم المزود أو رقم الحوالة. تظهر لك فقط الأقسام المسموحة بصلاحياتك.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            height: 1.6,
            color: placeInk2,
          ),
        ),
      ],
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.title, this.icon);
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: placeBrass),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w900,
              color: placeInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            lightTap();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: placeLine),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: placePaper,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 20, color: placeInk),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w800,
                          color: placeInk,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: placeInk2,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
