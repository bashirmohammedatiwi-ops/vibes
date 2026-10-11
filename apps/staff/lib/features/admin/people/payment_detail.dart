import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api.dart';
import '../../../core/format.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../core/net_image.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/kit.dart';
import '../../ops/ops_booking_detail.dart';
import 'people_common.dart';

/// تفاصيل دفعة: الإثبات (تكبير)، الاعتماد/الرفض، تغيير الحالة، الاسترداد، رفع إثبات.
class AdminPaymentDetailScreen extends StatefulWidget {
  const AdminPaymentDetailScreen({super.key, required this.paymentId});
  final String paymentId;

  @override
  State<AdminPaymentDetailScreen> createState() => _AdminPaymentDetailScreenState();
}

class _AdminPaymentDetailScreenState extends State<AdminPaymentDetailScreen> {
  Map<String, dynamic>? _p;
  bool _loading = true;
  String? _error;
  bool _changed = false;
  double? _uploadProgress;

  bool get _canVerify => Session.can('payments.verify');
  bool get _canRefund => Session.can('payments.refund');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _p == null;
      _error = null;
    });
    try {
      final data = await Api.map('/api/admin/payments/${widget.paymentId}');
      if (!mounted) return;
      setState(() {
        _p = data;
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

  Future<void> _send(String path, String method, Map<String, dynamic> body, String success) async {
    final ok = await runAction(context, () async {
      await withBusy(context, () => Api.map(path, method: method, body: body));
    }, success: success);
    if (ok) {
      _changed = true;
      await _load();
    }
  }

  String get _amount => formatIqd(_p?['amount']);

  Future<void> _approve() async {
    final ref = await showInputSheet(
      context,
      title: 'اعتماد الدفعة',
      subtitle: 'المبلغ $_amount — سيتأكد الحجز تلقائياً ويُبلَّغ الزبون.',
      label: 'رقم العملية / المرجع (اختياري)',
      initial: _p?['transactionRef']?.toString() ?? '',
      confirmLabel: 'متابعة',
    );
    if (ref == null || !mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'تأكيد الاعتماد',
      message: 'اعتماد دفعة بقيمة $_amount كمدفوعة؟',
      confirmLabel: 'اعتماد',
    );
    if (!ok || !mounted) return;
    await _send(
      '/api/admin/payments/${widget.paymentId}/review',
      'PATCH',
      {'status': 'PAID', if (ref.isNotEmpty) 'transactionRef': ref},
      'تم اعتماد الدفعة',
    );
  }

  Future<void> _reject() async {
    final note = await showInputSheet(
      context,
      title: 'رفض الدفعة',
      subtitle: 'اذكر السبب (مثلاً: الإثبات غير واضح أو المبلغ ناقص).',
      label: 'سبب الرفض',
      confirmLabel: 'رفض الدفعة',
      required: true,
      maxLines: 3,
      danger: true,
    );
    if (note == null || !mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'تأكيد الرفض',
      message: 'رفض دفعة بقيمة $_amount؟ ستُعلَّم «فشل» ويُحفظ السبب معها.',
      confirmLabel: 'رفض الدفعة',
      danger: true,
    );
    if (!ok || !mounted) return;
    await _send('/api/admin/payments/${widget.paymentId}/review', 'PATCH', {'status': 'FAILED', 'adminNote': note}, 'تم رفض الدفعة');
  }

  Future<void> _changeStatus() async {
    final current = _p?['status']?.toString();
    final res = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(StaffRadius.xl))),
      builder: (_) => _StatusSheet(current: current, transactionRef: _p?['transactionRef']?.toString() ?? ''),
    );
    if (res == null || !mounted) return;
    final status = res['status']!;
    final ok = await confirmDialog(
      context,
      title: 'تغيير حالة الدفعة؟',
      message: 'من «${paymentStatusAr(current)}» إلى «${paymentStatusAr(status)}» — $_amount.'
          '${status == 'PAID' ? '\nسيتأكد الحجز المرتبط تلقائياً.' : ''}',
      confirmLabel: 'تغيير',
      danger: status == 'FAILED',
    );
    if (!ok || !mounted) return;
    await _send(
      '/api/admin/payments/${widget.paymentId}/status',
      'PATCH',
      {
        'status': status,
        if ((res['note'] ?? '').isNotEmpty) 'adminNote': res['note'],
        if ((res['ref'] ?? '').isNotEmpty) 'transactionRef': res['ref'],
      },
      'تم تغيير الحالة',
    );
  }

  Future<void> _refund() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(StaffRadius.xl))),
      builder: (_) => _RefundSheet(amount: _amount),
    );
    if (reason == null || !mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'تأكيد الاسترداد',
      message: 'سيتم تعليم الدفعة «مستردة» بقيمة $_amount وإلغاء الحجز وتحرير موعده. لا يمكن التراجع عن هذا الإجراء.',
      confirmLabel: 'استرداد',
      danger: true,
    );
    if (!ok || !mounted) return;
    await _send('/api/admin/payments/${widget.paymentId}/refund', 'POST', {'adminNote': reason}, 'تم الاسترداد وإلغاء الحجز');
  }

  Future<void> _uploadProof() async {
    final bookingId = asMap(_p?['booking'])['id']?.toString() ?? _p?['bookingId']?.toString();
    if (bookingId == null) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(StaffRadius.xl))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const SheetHandle(),
            TaskTile(
              icon: Icons.photo_library_rounded,
              color: placeShiftEvening,
              title: 'من المعرض',
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            TaskTile(
              icon: Icons.photo_camera_rounded,
              color: placeInfo,
              title: 'التقاط صورة',
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await ImagePicker().pickImage(source: source, imageQuality: 88, maxWidth: 2400);
    if (file == null || !mounted) return;
    setState(() => _uploadProgress = 0);
    try {
      await Api.uploadFile(
        '/api/admin/bookings/$bookingId/payment/proof',
        file.path,
        onProgress: (v) {
          if (mounted) setState(() => _uploadProgress = v);
        },
      );
      if (!mounted) return;
      showToast(context, 'تم رفع الإثبات — الدفعة بانتظار التحقق');
      _changed = true;
      await _load();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    }
    if (mounted) setState(() => _uploadProgress = null);
  }

  void _openProof(String url) {
    Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => ProofViewer(url: url)));
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        bottomNavigationBar: p == null ? null : _actions(),
        body: StaffPage(
          title: 'تفاصيل الدفعة',
          onRefresh: p == null ? null : _load,
          actions: [
            if (p != null && _canVerify && p['status'] != 'REFUNDED')
              IconButton(tooltip: 'تغيير الحالة', icon: const Icon(Icons.swap_horiz_rounded), onPressed: _changeStatus),
          ],
          slivers: _loading
              ? const [SliverToBoxAdapter(child: SizedBox(height: 4)), SkeletonSliver(count: 4, height: 130)]
              : _error != null && p == null
                  ? [SliverToBoxAdapter(child: ErrorRetry(message: _error!, onRetry: _load))]
                  : _body(p!),
        ),
      ),
    );
  }

  Widget? _actions() {
    final status = _p?['status']?.toString();
    if (status == 'PENDING' && _canVerify) {
      return ActionBarShell(
        child: Row(
          children: [
            Expanded(
              child: BarButton(label: 'رفض', icon: Icons.close_rounded, color: placeDanger, outlined: true, onPressed: _reject),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: BarButton(label: 'اعتماد الدفعة', icon: Icons.check_circle_rounded, color: placeSuccess, onPressed: _approve),
            ),
          ],
        ),
      );
    }
    if (status == 'PAID' && _canRefund) {
      return ActionBarShell(
        child: BarButton(
          label: 'استرداد المبلغ',
          icon: Icons.currency_exchange_rounded,
          color: placeDanger,
          outlined: true,
          onPressed: _refund,
        ),
      );
    }
    return null;
  }

  List<Widget> _body(Map<String, dynamic> p) {
    final status = p['status']?.toString();
    final booking = asMap(p['booking']);
    final user = asMap(booking['user']);
    final property = asMap(booking['property']);
    final proof = absUrl(p['proofUrl']);
    final reviewer = asMap(p['reviewedBy']);
    final color = paymentStatusColor(status);
    final phone = user['phone']?.toString() ?? booking['guestPhone']?.toString();
    final ref = p['transactionRef']?.toString() ?? '';

    return [
      const SliverToBoxAdapter(child: SizedBox(height: 4)),
      // ── المبلغ والحالة ──
      SliverToBoxAdapter(
        child: Pad(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [color.withValues(alpha: 0.12), Colors.white],
              ),
              borderRadius: BorderRadius.circular(StaffRadius.lg),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          StatusChip(paymentStatusAr(status), color: color),
                          StatusChip(methodLabel(p['method']?.toString()), color: placeInk2),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(_amount, style: const TextStyle(fontFamily: 'Cairo', fontSize: 30, fontWeight: FontWeight.w900, color: placeInk, height: 1.2)),
                      Text('أُنشئت ${fmtDateTime(p['createdAt'])}',
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                IconBox(icon: methodIcon(p['method']?.toString()), color: color, size: 52),
              ],
            ),
          ),
        ),
      ),
      if (status == 'REFUNDED')
        const SliverToBoxAdapter(
          child: NoticeBanner(
            text: 'تم استرداد هذه الدفعة ولا يمكن تعديل حالتها.',
            color: placeInk2,
            icon: Icons.lock_outline_rounded,
          ),
        ),
      // ── الإثبات ──
      SliverToBoxAdapter(
        child: DetailCard(
          title: 'إثبات الدفع',
          icon: Icons.receipt_long_rounded,
          color: placeShiftEvening,
          subtitle: proof == null ? 'لم يُرفع إثبات بعد' : 'اضغط على الصورة للتكبير',
          children: [
            if (proof != null) ...[
              GestureDetector(
                onTap: () => _openProof(proof),
                child: Hero(
                  tag: proof,
                  child: SizedBox(height: 240, child: NetImage(url: proof, radius: StaffRadius.md, fit: BoxFit.cover, icon: Icons.receipt_long_outlined)),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (_uploadProgress != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LinearProgressIndicator(value: _uploadProgress, color: placeGold, backgroundColor: placeLine, minHeight: 6, borderRadius: BorderRadius.circular(4)),
                    const SizedBox(height: 4),
                    Text('جارٍ الرفع ${((_uploadProgress ?? 0) * 100).round()}٪',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2)),
                  ],
                ),
              )
            else if (_canVerify && status != 'REFUNDED')
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: OutlinedButton.icon(
                  onPressed: _uploadProof,
                  icon: const Icon(Icons.upload_file_rounded, size: 19),
                  label: Text(proof == null ? 'رفع إثبات نيابة عن الزبون' : 'استبدال الإثبات'),
                ),
              ),
          ],
        ),
      ),
      // ── الحجز ──
      SliverToBoxAdapter(
        child: DetailCard(
          title: 'الحجز',
          icon: Icons.event_note_rounded,
          color: placeInfo,
          children: [
            DetailRow(label: 'المكان', value: nonEmpty(property['name'])),
            DetailRow(label: 'الزبون', value: nonEmpty(user['name'] ?? booking['guestName'])),
            if (phone != null && phone.isNotEmpty)
              DetailRow(label: 'الهاتف', value: phone, ltr: true, trailing: PhoneButtons(phone: phone, compact: true)),
            DetailRow(label: 'التاريخ', value: '${fmtDay(booking['startDate'])}${booking['endDate'] != null ? ' ← ${fmtDay(booking['endDate'])}' : ''}'),
            DetailRow(
              label: 'حالة الحجز',
              value: bookingStatusLabel(booking['status']?.toString()),
              valueColor: bookingStatusColor(booking['status']?.toString()),
            ),
            DetailRow(label: 'إجمالي الحجز', value: formatIqd(booking['totalPrice'])),
            if (Session.can('bookings.read') && booking['id'] != null) ...[
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => OpsBookingDetailScreen(bookingId: '${booking['id']}')),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('فتح الحجز'),
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
      // ── المراجعة ──
      SliverToBoxAdapter(
        child: DetailCard(
          title: 'المراجعة',
          icon: Icons.fact_check_rounded,
          color: placeSuccess,
          children: [
            DetailRow(label: 'رقم العملية', value: nonEmpty(ref), ltr: ref.isNotEmpty),
            DetailRow(label: 'ملاحظة الإدارة', value: nonEmpty(p['adminNote'])),
            DetailRow(label: 'راجعها', value: nonEmpty(reviewer['name'] ?? reviewer['phone'])),
            DetailRow(label: 'وقت المراجعة', value: p['reviewedAt'] == null ? '—' : fmtDateTime(p['reviewedAt'])),
          ],
        ),
      ),
    ];
  }
}

/// عارض الإثبات بملء الشاشة مع تكبير وتحريك.
class ProofViewer extends StatefulWidget {
  const ProofViewer({super.key, required this.url});
  final String url;

  @override
  State<ProofViewer> createState() => _ProofViewerState();
}

class _ProofViewerState extends State<ProofViewer> {
  final _controller = TransformationController();
  TapDownDetails? _lastTap;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleZoom(TapDownDetails d) {
    if (_controller.value.getMaxScaleOnAxis() > 1.01) {
      _controller.value = Matrix4.identity();
    } else {
      final p = d.localPosition;
      _controller.value = Matrix4.identity()
        ..translateByDouble(-p.dx * 1.5, -p.dy * 1.5, 0, 1)
        ..scaleByDouble(2.5, 2.5, 1, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('إثبات الدفع', style: TextStyle(color: Colors.white)),
      ),
      body: GestureDetector(
        onDoubleTapDown: (d) => _lastTap = d,
        onDoubleTap: () {
          final d = _lastTap;
          if (d != null) _toggleZoom(d);
        },
        child: InteractiveViewer(
          transformationController: _controller,
          minScale: 1,
          maxScale: 6,
          child: Center(
            child: Hero(
              tag: widget.url,
              child: staffNetworkImage(
                widget.url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : const Center(child: CircularProgressIndicator(color: Colors.white)),
                errorBuilder: (_, _, _) => const Text('تعذّر تحميل الصورة', style: TextStyle(color: Colors.white70)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusSheet extends StatefulWidget {
  const _StatusSheet({required this.current, required this.transactionRef});
  final String? current;
  final String transactionRef;

  @override
  State<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<_StatusSheet> {
  String? _status;
  final _note = TextEditingController();
  late final _ref = TextEditingController(text: widget.transactionRef);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _note.dispose();
    _ref.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // REFUNDED متاح فقط عبر «استرداد» (صلاحية payments.refund) لأنه يلغي الحجز.
    final options = ['PENDING', 'PAID', 'FAILED'].where((s) => s != widget.current).toList();
    return SheetBody(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetTitle('تغيير حالة الدفعة', subtitle: 'اختر الحالة الجديدة'),
            ChoicePills<String>(
              options: options,
              value: _status,
              labelOf: paymentStatusAr,
              onChanged: (v) => setState(() => _status = v),
            ),
            const SizedBox(height: 14),
            if (_status == 'PAID') ...[
              StaffField(controller: _ref, label: 'رقم العملية / المرجع (اختياري)', ltr: true),
              const SizedBox(height: 12),
            ],
            StaffField(
              controller: _note,
              label: _status == 'FAILED' ? 'سبب الرفض *' : 'ملاحظة (اختياري)',
              maxLines: 3,
              validator: (v) => _status == 'FAILED' && (v == null || v.trim().isEmpty) ? 'السبب مطلوب عند الرفض' : null,
            ),
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: _status == null
                  ? null
                  : () {
                      if (!_formKey.currentState!.validate()) return;
                      Navigator.pop(context, {'status': _status!, 'note': _note.text.trim(), 'ref': _status == 'PAID' ? _ref.text.trim() : ''});
                    },
              child: const Text('متابعة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefundSheet extends StatefulWidget {
  const _RefundSheet({required this.amount});
  final String amount;

  @override
  State<_RefundSheet> createState() => _RefundSheetState();
}

class _RefundSheetState extends State<_RefundSheet> {
  final _reason = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SheetBody(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetTitle('استرداد المبلغ'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: placeDanger.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(StaffRadius.md),
                border: Border.all(color: placeDanger.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.currency_exchange_rounded, color: placeDanger),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('مبلغ الاسترداد (كامل الدفعة)',
                        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: placeInk2)),
                  ),
                  Text(widget.amount, style: const TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w900, color: placeDanger)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'الاسترداد يشمل كامل مبلغ الدفعة ويُلغي الحجز المرتبط ويحرّر موعده.',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2, height: 1.5),
            ),
            const SizedBox(height: 12),
            StaffField(
              controller: _reason,
              label: 'سبب الاسترداد *',
              maxLines: 3,
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'السبب مطلوب';
                if (t.length < 3) return 'اكتب 3 أحرف على الأقل';
                return null;
              },
            ),
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: placeDanger, minimumSize: const Size.fromHeight(50)),
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                Navigator.pop(context, _reason.text.trim());
              },
              child: const Text('متابعة'),
            ),
          ],
        ),
      ),
    );
  }
}
