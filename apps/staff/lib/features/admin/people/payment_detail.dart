import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api.dart';
import '../../../core/format.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
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
    await _send('/api/admin/payments/${widget.paymentId}/review', 'PATCH', {'status': 'FAILED', 'adminNote': note}, 'تم رفض الدفعة');
  }

  Future<void> _changeStatus() async {
    final current = _p?['status']?.toString();
    final res = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const SheetHandle(),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('من المعرض'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('التقاط صورة'),
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل الدفعة'),
          actions: [
            if (_p != null && _canVerify && _p?['status'] != 'REFUNDED')
              IconButton(tooltip: 'تغيير الحالة', icon: const Icon(Icons.swap_horiz_rounded), onPressed: _changeStatus),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: placeBrass))
            : _error != null && _p == null
                ? Center(child: ErrorRetry(message: _error!, onRetry: _load))
                : RefreshIndicator(color: placeBrass, onRefresh: _load, child: _body()),
        bottomNavigationBar: _p == null ? null : _actions(),
      ),
    );
  }

  Widget? _actions() {
    final status = _p?['status']?.toString();
    if (status == 'PENDING' && _canVerify) {
      return BottomActionBar(label: 'اعتماد الدفعة', onPressed: _approve, secondaryLabel: 'رفض', onSecondary: _reject);
    }
    if (status == 'PAID' && _canRefund) {
      return Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: placeLine))),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: placeDanger, side: const BorderSide(color: placeDanger)),
          onPressed: _refund,
          icon: const Icon(Icons.currency_exchange_rounded, size: 19),
          label: const Text('استرداد المبلغ'),
        ),
      );
    }
    return null;
  }

  Widget _body() {
    final p = _p!;
    final status = p['status']?.toString();
    final booking = asMap(p['booking']);
    final user = asMap(booking['user']);
    final property = asMap(booking['property']);
    final proof = absUrl(p['proofUrl']);
    final reviewer = asMap(p['reviewedBy']);
    final color = paymentStatusColor(status);
    final phone = user['phone']?.toString() ?? booking['guestPhone']?.toString();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [color.withValues(alpha: 0.12), Colors.white],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusPill(label: paymentStatusAr(status), color: color),
                  const SizedBox(width: 6),
                  StatusPill(label: methodLabel(p['method']?.toString()), color: placeInk2, icon: methodIcon(p['method']?.toString())),
                ],
              ),
              const SizedBox(height: 12),
              Text(_amount, style: const TextStyle(fontFamily: 'Cairo', fontSize: 30, fontWeight: FontWeight.w900, color: placeInk)),
              Text('أُنشئت ${fmtDateTime(p['createdAt'])}',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        FormSection(
          title: 'إثبات الدفع',
          icon: Icons.receipt_long_outlined,
          subtitle: proof == null ? 'لم يُرفع إثبات بعد' : 'اضغط على الصورة للتكبير',
          children: [
            if (proof != null)
              GestureDetector(
                onTap: () => _openProof(proof),
                child: Hero(
                  tag: proof,
                  child: SizedBox(height: 240, child: NetImage(url: proof, radius: 14, fit: BoxFit.cover, icon: Icons.receipt_long_outlined)),
                ),
              ),
            if (_uploadProgress != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(value: _uploadProgress, color: placeBrass, backgroundColor: placeLine, minHeight: 6, borderRadius: BorderRadius.circular(4)),
                  const SizedBox(height: 4),
                  Text('جارٍ الرفع ${((_uploadProgress ?? 0) * 100).round()}٪',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2)),
                ],
              )
            else if (_canVerify && status != 'REFUNDED')
              OutlinedButton.icon(
                onPressed: _uploadProof,
                icon: const Icon(Icons.upload_file_rounded, size: 19),
                label: Text(proof == null ? 'رفع إثبات نيابة عن الزبون' : 'استبدال الإثبات'),
              ),
          ],
        ),
        FormSection(
          title: 'الحجز',
          icon: Icons.event_note_outlined,
          children: [
            InfoRow(label: 'المكان', value: nonEmpty(property['name'])),
            InfoRow(label: 'الزبون', value: nonEmpty(user['name'] ?? booking['guestName'])),
            if (phone != null && phone.isNotEmpty)
              InfoRow(label: 'الهاتف', value: phone, ltr: true, trailing: PhoneButtons(phone: phone, compact: true)),
            InfoRow(label: 'التاريخ', value: '${fmtDay(booking['startDate'])}${booking['endDate'] != null ? ' ← ${fmtDay(booking['endDate'])}' : ''}'),
            InfoRow(
              label: 'حالة الحجز',
              value: bookingStatusLabel(booking['status']?.toString()),
              valueColor: bookingStatusColor(booking['status']?.toString()),
            ),
            InfoRow(label: 'إجمالي الحجز', value: formatIqd(booking['totalPrice'])),
            if (Session.can('bookings.read') && booking['id'] != null)
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => OpsBookingDetailScreen(bookingId: '${booking['id']}')),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('فتح الحجز'),
              ),
          ],
        ),
        FormSection(
          title: 'المراجعة',
          icon: Icons.fact_check_outlined,
          children: [
            InfoRow(label: 'رقم العملية', value: nonEmpty(p['transactionRef']), ltr: (p['transactionRef']?.toString() ?? '').isNotEmpty),
            InfoRow(label: 'ملاحظة الإدارة', value: nonEmpty(p['adminNote'])),
            InfoRow(label: 'راجعها', value: nonEmpty(reviewer['name'] ?? reviewer['phone'])),
            InfoRow(label: 'وقت المراجعة', value: p['reviewedAt'] == null ? '—' : fmtDateTime(p['reviewedAt'])),
          ],
        ),
        if (status == 'REFUNDED')
          const NoticeBanner(
            text: 'تم استرداد هذه الدفعة ولا يمكن تعديل حالتها.',
            color: placeInk2,
            icon: Icons.lock_outline_rounded,
          ),
      ],
    );
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
              child: Image.network(
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
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const Text('تغيير حالة الدفعة', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: placeInk)),
            const SizedBox(height: 12),
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
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const Text('استرداد المبلغ', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: placeInk)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: placeDanger.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(14)),
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
              style: FilledButton.styleFrom(backgroundColor: placeDanger),
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
