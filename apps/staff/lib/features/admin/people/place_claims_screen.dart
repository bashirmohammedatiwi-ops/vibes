import 'package:flutter/material.dart';

import '../../../core/api.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/chat_ui.dart';
import '../../../widgets/form_kit.dart';
import '../../chat_room.dart';
import 'people_common.dart';

String claimStatusLabel(String? s) => switch (s) {
      'PENDING' => 'بانتظار المراجعة',
      'APPROVED' => 'تم الربط',
      'REJECTED' => 'مرفوض',
      _ => s ?? '—',
    };

/// طابور طلبات ربط الأماكن (مستخدم يدّعي ملكية مكان) — `providers.read` للعرض، `providers.link` للقرار.
class PlaceClaimsScreen extends StatefulWidget {
  const PlaceClaimsScreen({super.key});

  @override
  State<PlaceClaimsScreen> createState() => _PlaceClaimsScreenState();
}

class _PlaceClaimsScreenState extends State<PlaceClaimsScreen> {
  final _list = PagedListController();
  String _status = 'PENDING';

  Future<PageResult> _fetch(int page) async {
    final rows = await Api.list(buildPath('/api/admin/providers/claims', {'status': _status}));
    final items = asMapList(rows);
    return PageResult(items: items, total: items.length, totalPages: 1, raw: const {});
  }

  Future<void> _approve(Map<String, dynamic> claim) async {
    final user = asMap(claim['user']);
    final property = asMap(claim['property']);
    final current = asMap(property['provider']);
    final currentName = nonEmpty(current['businessName'], asMap(current['user'])['phone']?.toString() ?? '');
    final ok = await confirmDialog(
      context,
      title: 'اعتماد الربط؟',
      message: [
        'سيُربط «${nonEmpty(property['name'], 'المكان')}» بحساب «${nonEmpty(user['name'], user['phone']?.toString() ?? '')}»، ويُوثَّق الحساب كمزود.',
        if (current.isNotEmpty) '\nتنبيه: المكان مرتبط حالياً بـ «$currentName» وسيُنقل منه.',
      ].join(),
      confirmLabel: 'اعتماد',
    );
    if (!ok || !mounted) return;
    final done = await runAction(context, () async {
      await withBusy(context, () => Api.send('/api/admin/providers/claims/${claim['id']}/approve', method: 'PATCH'));
    }, success: 'تم ربط المكان');
    if (done) _list.reload();
  }

  Future<void> _reject(Map<String, dynamic> claim) async {
    final ok = await confirmDialog(
      context,
      title: 'رفض الطلب؟',
      message: 'ستصل رسالة لصاحب الطلب بأن المكان لم يُربط بحسابه، ويمكنه إعادة الطلب لاحقاً.',
      confirmLabel: 'رفض',
      danger: true,
    );
    if (!ok || !mounted) return;
    final done = await runAction(context, () async {
      await withBusy(context, () => Api.send('/api/admin/providers/claims/${claim['id']}/reject', method: 'PATCH'));
    }, success: 'تم رفض الطلب');
    if (done) _list.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلبات ربط الأماكن')),
      body: Column(
        children: [
          FilterBar(groups: [
            FilterGroup(
              options: const ['PENDING', 'APPROVED', 'REJECTED'],
              selected: _status,
              labelOf: claimStatusLabel,
              onSelected: (v) => setState(() => _status = v),
            ),
          ]),
          Expanded(
            child: PagedList(
              key: ValueKey(_status),
              controller: _list,
              fetch: _fetch,
              emptyTitle: _status == 'PENDING' ? 'لا طلبات ربط معلّقة' : 'لا طلبات',
              emptySubtitle: _status == 'PENDING' ? 'ستظهر هنا طلبات أصحاب الأماكن لربطها بحساباتهم' : null,
              itemBuilder: (context, c, _) => _ClaimCard(
                claim: c,
                onApprove: () => _approve(c),
                onReject: () => _reject(c),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({required this.claim, required this.onApprove, required this.onReject});
  final Map<String, dynamic> claim;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final user = asMap(claim['user']);
    final property = asMap(claim['property']);
    final current = asMap(property['provider']);
    final status = claim['status']?.toString();
    final name = nonEmpty(user['name'], 'بدون اسم');
    final phone = user['phone']?.toString();
    final pending = status == 'PENDING';
    return ListCard(
      highlight: pending ? placeBrass.withValues(alpha: 0.35) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ContactAvatar(name: name, phone: phone, size: 42),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: placeInk)),
                    PhoneText(phone),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusPill(label: claimStatusLabel(status), color: requestStatusColor(status)),
                  const SizedBox(height: 4),
                  Text(relativeAr(claim['createdAt']), style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: placeInk2)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: placePaper, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.home_work_outlined, color: placeBrass, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('يطلب ربط: ${nonEmpty(property['name'], 'مكان')}',
                          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: placeInk)),
                      Text(
                        current.isEmpty
                            ? 'المكان غير مرتبط بأي مزود حالياً'
                            : 'مرتبط حالياً بـ ${nonEmpty(current['businessName'], asMap(current['user'])['phone']?.toString() ?? 'مزود')}',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: current.isEmpty ? placeInk2 : placeShiftMorning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              PhoneButtons(phone: phone, compact: true),
              if (Session.can('inbox.read') && user['id'] != null)
                IconButton(
                  tooltip: 'محادثة',
                  icon: const Icon(Icons.forum_outlined, color: placeShiftEvening),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ChatRoomScreen(contactUserId: '${user['id']}', contactName: name, contactPhone: phone),
                  )),
                ),
              const Spacer(),
              if (pending && Session.can('providers.link')) ...[
                OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                  onPressed: onReject,
                  child: const Text('رفض'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: placeSuccess, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
                  onPressed: onApprove,
                  child: const Text('اعتماد'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
