import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/form_kit.dart';
import '../widgets/kit.dart';
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

/// أقسام النتائج بترتيب العرض.
enum _Kind {
  bookings('bookings', 'الحجوزات', placeBrass),
  users('users', 'الحسابات', placeInfo),
  properties('properties', 'الأماكن', placeShiftEvening),
  payments('payments', 'المدفوعات', placeSuccess),
  providers('providers', 'المزودون', placeWarning);

  const _Kind(this.key, this.label, this.color);
  final String key;
  final String label;
  final Color color;
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _field = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  Map<String, dynamic> _results = {};
  bool _loading = false;
  String _lastQuery = '';
  String? _error;
  _Kind? _filter;

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {}); // لإظهار/إخفاء زر المسح
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String raw, {bool force = false}) async {
    final q = raw.trim();
    if (q == _lastQuery && !force) return;
    _lastQuery = q;
    if (q.length < 2) {
      setState(() {
        _results = {};
        _error = null;
        _loading = false;
        _filter = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await Api.map('/api/admin/search?q=${Uri.encodeQueryComponent(q)}');
      if (!mounted || q != _lastQuery) return;
      setState(() {
        _results = data;
        _error = null;
        if (_filter != null && _section(_filter!.key).isEmpty) _filter = null;
      });
    } catch (e) {
      if (mounted && q == _lastQuery) {
        setState(() => _error = e is ApiException ? e.message : 'تعذّر الاتصال — تحقّق من الشبكة');
      }
    } finally {
      if (mounted && q == _lastQuery) setState(() => _loading = false);
    }
  }

  void _clear() {
    _field.clear();
    _search('');
    _focus.requestFocus();
  }

  List<Map<String, dynamic>> _section(String key) => (_results[key] as List? ?? const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  void _open(Widget page) {
    _focus.unfocus();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  String _date(dynamic v) {
    final d = DateTime.tryParse(v?.toString() ?? '');
    if (d == null) return '';
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final sections = {for (final k in _Kind.values) k: _section(k.key)};
    final total = sections.values.fold<int>(0, (s, l) => s + l.length);
    final idle = _lastQuery.length < 2;
    final hasResults = !idle && _error == null && total > 0;

    final body = <Widget>[];
    if (idle) {
      body.add(const SliverToBoxAdapter(child: _Hint()));
    } else if (_error != null) {
      body.add(SliverToBoxAdapter(
        child: EmptyView(
          icon: Icons.cloud_off_rounded,
          title: 'تعذّر البحث',
          subtitle: _error,
          actionLabel: 'إعادة المحاولة',
          onAction: () => _search(_field.text, force: true),
        ),
      ));
    } else if (_loading && total == 0) {
      body.add(const SliverToBoxAdapter(child: SizedBox(height: 12)));
      body.add(const SkeletonSliver(count: 6, height: 64));
    } else if (total == 0) {
      body.add(const SliverToBoxAdapter(
        child: EmptyView(
          icon: Icons.search_off_rounded,
          title: 'لا نتائج',
          subtitle: 'جرّب جزءاً من الرقم أو الاسم، أو تأكّد من الإملاء',
        ),
      ));
    } else {
      body.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(StaffSpace.page, 8, StaffSpace.page, 0),
          child: Text(
            '$total نتيجة لـ «$_lastQuery»',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w700, color: placeInk2),
          ),
        ),
      ));
      for (final k in _Kind.values) {
        final items = sections[k]!;
        if (items.isEmpty || (_filter != null && _filter != k)) continue;
        body.add(SliverToBoxAdapter(child: SectionHeader(k.label, count: items.length)));
        body.add(SliverToBoxAdapter(
          child: Pad(bottom: 0, child: TileGroup(children: [for (final m in items) _row(k, m)])),
        ));
      }
    }

    return Scaffold(
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverAppBar(
            pinned: true,
            toolbarHeight: 68,
            titleSpacing: 0,
            title: Padding(
              padding: EdgeInsetsDirectional.only(
                start: Navigator.of(context).canPop() ? 0 : StaffSpace.page,
                end: StaffSpace.page,
              ),
              child: _SearchField(
                controller: _field,
                focus: _focus,
                loading: _loading,
                onChanged: _onChanged,
                onSubmitted: (v) {
                  _debounce?.cancel();
                  _search(v);
                },
                onClear: _clear,
              ),
            ),
            bottom: hasResults
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(50),
                    child: _KindChips(
                      counts: {for (final e in sections.entries) e.key: e.value.length},
                      total: total,
                      selected: _filter,
                      onSelected: (k) => setState(() => _filter = k),
                    ),
                  )
                : null,
          ),
          ...body,
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }

  Widget _row(_Kind kind, Map<String, dynamic> m) {
    switch (kind) {
      case _Kind.bookings:
        final status = m['status']?.toString();
        return _ResultRow(
          leading: IconBox(icon: Icons.event_note_rounded, color: kind.color),
          title: (m['property'] as Map?)?['name']?.toString() ?? 'حجز',
          subtitle: [
            (m['user'] as Map?)?['name'] ?? (m['user'] as Map?)?['phone'] ?? '',
            _date(m['startDate']),
          ].where((e) => '$e'.isNotEmpty).join(' · '),
          trailing: StatusChip(bookingStatusLabel(status), color: _bookingColor(status), dense: true),
          onTap: () => _open(BookingManageScreen(bookingId: m['id'].toString())),
        );
      case _Kind.users:
        final name = m['name']?.toString().isNotEmpty == true ? m['name'].toString() : 'بدون اسم';
        final role = m['role']?.toString();
        return _ResultRow(
          leading: Avatar(name, size: 40, color: _roleColor(role)),
          title: name,
          subtitleWidget: _PhoneLine(phone: m['phone']?.toString()),
          trailing: StatusChip(_role(role), color: _roleColor(role), dense: true),
          onTap: () => _open(AdminCustomerDetailScreen(userId: m['id'].toString())),
        );
      case _Kind.properties:
        final status = m['status']?.toString();
        return _ResultRow(
          leading: IconBox(icon: placeTypeIcon(m['type']?.toString()), color: kind.color),
          title: m['name']?.toString() ?? '',
          subtitle: placeTypeLabel(m['type']?.toString()),
          trailing: StatusChip(placeStatusLabel(status), color: placeStatusColor(status), dense: true),
          onTap: () => _open(PropertyDetailScreen(propertyId: m['id'].toString())),
        );
      case _Kind.payments:
        final status = m['status']?.toString();
        final booking = m['booking'] as Map?;
        return _ResultRow(
          leading: IconBox(icon: Icons.receipt_long_rounded, color: kind.color),
          title: formatIqd(m['amount']),
          subtitle: [
            (booking?['property'] as Map?)?['name'] ?? '',
            (booking?['user'] as Map?)?['phone'] ?? '',
          ].where((e) => '$e'.isNotEmpty).join(' · '),
          trailing: StatusChip(paymentStatusAr(status), color: paymentStatusColor(status), dense: true),
          onTap: () => _open(AdminPaymentDetailScreen(paymentId: m['id'].toString())),
        );
      case _Kind.providers:
        final verified = m['verified'] == true;
        final name = m['businessName']?.toString() ?? '';
        return _ResultRow(
          leading: Avatar(name, size: 40, color: placeBrass),
          title: name,
          subtitleWidget: _PhoneLine(phone: (m['user'] as Map?)?['phone']?.toString()),
          trailing: verified
              ? const StatusChip('موثّق', color: placeSuccess, dense: true)
              : const Icon(Icons.chevron_left_rounded, color: placeInk3),
          onTap: () => _open(AdminProviderDetailScreen(providerId: m['id'].toString())),
        );
    }
  }

  String _role(String? role) => switch (role) {
        'PROVIDER' => 'مزود',
        'STAFF' => 'موظف',
        'ADMIN' => 'مدير',
        _ => 'زبون',
      };

  Color _roleColor(String? role) => switch (role) {
        'PROVIDER' => placeBrass,
        'STAFF' => placeShiftEvening,
        'ADMIN' => placeInk,
        _ => placeInfo,
      };

  Color _bookingColor(String? s) => switch (s) {
        'CONFIRMED' => placeSuccess,
        'COMPLETED' => placeInfo,
        'PENDING' => placeWarning,
        'AWAITING_PAYMENT' => placeBrass,
        'DISPUTED' => placeDanger,
        _ => placeInk2,
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

/// حقل البحث في الرأس: بطاقة بيضاء بحدود رفيعة.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focus,
    required this.loading,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool loading;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(StaffRadius.md),
        border: Border.all(color: placeLine),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          SizedBox(
            width: 22,
            height: 22,
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(2),
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: placeGold),
                  )
                : const Icon(Icons.search_rounded, color: placeInk2, size: 22),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              autofocus: true,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 14.5, fontWeight: FontWeight.w700, color: placeInk),
              decoration: const InputDecoration(
                hintText: 'هاتف، اسم زبون، مكان، رقم حوالة…',
                hintStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, color: placeInk3),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              tooltip: 'مسح',
              icon: const Icon(Icons.close_rounded, size: 20, color: placeInk2),
              onPressed: onClear,
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// شرائح تصفية النتائج حسب القسم مع العدد.
class _KindChips extends StatelessWidget {
  const _KindChips({required this.counts, required this.total, required this.selected, required this.onSelected});

  final Map<_Kind, int> counts;
  final int total;
  final _Kind? selected;
  final ValueChanged<_Kind?> onSelected;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _chip('الكل', total, selected == null, () => onSelected(null)),
      for (final k in _Kind.values)
        if ((counts[k] ?? 0) > 0) _chip(k.label, counts[k]!, selected == k, () => onSelected(k)),
    ];
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(StaffSpace.page, 2, StaffSpace.page, 10),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _chip(String label, int count, bool on, VoidCallback tap) {
    return Material(
      color: on ? placeInk : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          HapticFeedback.selectionClick();
          tap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: on ? placeInk : placeLine),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w800, color: on ? Colors.white : placeInk)),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(fontFamily: 'Montserrat', fontSize: 12, fontWeight: FontWeight.w800, color: on ? placeGold : placeInk3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// الحالة الأولى: شرح ما يمكن البحث عنه.
class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EmptyView(
          icon: Icons.manage_search_rounded,
          title: 'ابحث في كل شيء من مكان واحد',
          subtitle: 'اكتب حرفين على الأقل. تظهر لك فقط الأقسام المسموحة بصلاحياتك.',
        ),
        SectionHeader('ماذا يمكنك أن تبحث عنه؟'),
        Pad(
          child: TileGroup(
            children: [
              TaskTile(icon: Icons.phone_rounded, color: placeInfo, title: 'رقم هاتف', subtitle: 'زبون، مزود أو صاحب حجز', trailing: SizedBox.shrink()),
              TaskTile(icon: Icons.person_rounded, color: placeShiftEvening, title: 'اسم زبون أو مزود', subtitle: 'جزء من الاسم يكفي', trailing: SizedBox.shrink()),
              TaskTile(icon: Icons.home_work_rounded, color: placeBrass, title: 'اسم مكان', subtitle: 'شاليه، استراحة، قاعة…', trailing: SizedBox.shrink()),
              TaskTile(icon: Icons.receipt_long_rounded, color: placeSuccess, title: 'رقم حوالة', subtitle: 'مرجع الدفع أو العملية', trailing: SizedBox.shrink()),
            ],
          ),
        ),
      ],
    );
  }
}

/// صف نتيجة: عنصر بادئ، عنوان، وصف، وشارة.
class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.leading,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 14.5, fontWeight: FontWeight.w800, color: placeInk),
                    ),
                    if (subtitleWidget != null)
                      subtitleWidget!
                    else if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600, color: placeInk2),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// رقم هاتف باتجاه LTR داخل سطر الوصف.
class _PhoneLine extends StatelessWidget {
  const _PhoneLine({required this.phone});

  final String? phone;

  @override
  Widget build(BuildContext context) {
    final p = phone?.trim() ?? '';
    if (p.isEmpty) return const SizedBox.shrink();
    return Text(
      p,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12, fontWeight: FontWeight.w600, color: placeInk2),
    );
  }
}
