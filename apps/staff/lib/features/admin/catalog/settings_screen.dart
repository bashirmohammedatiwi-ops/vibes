import 'package:flutter/material.dart';

import '../../../core/api.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/kit.dart';
import 'catalog_common.dart';

/// إعدادات المنصة — قراءة لأي موظف، وتعديل بصلاحية settings.write.
/// يُرسل PATCH بالحقول المتغيّرة فقط وفق AdminSettingsDto.
class PlatformSettingsScreen extends StatefulWidget {
  const PlatformSettingsScreen({super.key});

  @override
  State<PlatformSettingsScreen> createState() => _PlatformSettingsScreenState();
}

const _textKeys = [
  'supportPhone',
  'paymentInstructions',
  'commissionPercent',
  'cancellationPolicy',
  'minBookingNoticeDays',
  'maintenanceMessage',
];

const _timeKeys = [
  'morningShiftStart',
  'morningShiftEnd',
  'eveningShiftStart',
  'eveningShiftEnd',
  'fullShiftStart',
  'fullShiftEnd',
];

const _boolKeys = [
  'manualProofEnabled',
  'zainCashEnabled',
  'qiCardEnabled',
  'notifyWhatsappEnabled',
  'maintenanceMode',
];

final _timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

class _PlatformSettingsScreenState extends State<PlatformSettingsScreen> {
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _text = {
    for (final k in _textKeys) k: TextEditingController(),
  };
  final Map<String, String> _times = {};
  final Map<String, bool> _flags = {};
  Map<String, dynamic> _original = {};
  Map<String, dynamic> _raw = {};

  bool _loading = true;
  String? _error;
  bool _saving = false;

  bool get _canWrite => Session.can('settings.write');

  @override
  void initState() {
    super.initState();
    for (final c in _text.values) {
      c.addListener(_onChange);
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      if (_raw.isEmpty) _loading = true;
    });
    try {
      final data = await Api.map('/api/admin/settings');
      if (!mounted) return;
      _apply(data);
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorText(e);
      });
    }
  }

  void _apply(Map<String, dynamic> data) {
    _raw = data;
    final gw = data['paymentGateways'] is Map ? Map<String, dynamic>.from(data['paymentGateways'] as Map) : {};
    final original = <String, dynamic>{
      for (final k in _textKeys) k: '${data[k] ?? ''}',
      for (final k in _timeKeys) k: '${data[k] ?? ''}',
      'manualProofEnabled': gw['manualProof'] == true,
      'zainCashEnabled': gw['zainCash'] == true,
      'qiCardEnabled': gw['qiCard'] == true,
      'notifyWhatsappEnabled': data['notifyWhatsappEnabled'] == true,
      'maintenanceMode': data['maintenanceMode'] == true,
    };
    _original = original;
    for (final k in _textKeys) {
      _text[k]!.text = original[k] as String;
    }
    for (final k in _timeKeys) {
      _times[k] = original[k] as String;
    }
    for (final k in _boolKeys) {
      _flags[k] = original[k] as bool;
    }
  }

  Map<String, dynamic> get _current => {
        for (final k in _textKeys) k: _text[k]!.text.trim(),
        for (final k in _timeKeys) k: _times[k] ?? '',
        for (final k in _boolKeys) k: _flags[k] ?? false,
      };

  Map<String, dynamic> get _changes {
    final cur = _current;
    final diff = <String, dynamic>{};
    cur.forEach((k, v) {
      final o = _original[k];
      if (o is String ? o.trim() != v : o != v) diff[k] = v;
    });
    return diff;
  }

  bool get _dirty => _canWrite && _changes.isNotEmpty;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      showToast(context, 'راجع الحقول المظللة', error: true);
      return;
    }
    final changes = _changes;
    if (changes.isEmpty) {
      showToast(context, 'لا توجد تغييرات');
      return;
    }
    for (final pair in [
      ['morningShiftStart', 'morningShiftEnd'],
      ['eveningShiftStart', 'eveningShiftEnd'],
      ['fullShiftStart', 'fullShiftEnd'],
    ]) {
      if ((_times[pair[0]] ?? '').isNotEmpty && _times[pair[0]] == _times[pair[1]]) {
        showToast(context, 'بداية الشفت ونهايته متطابقتان', error: true);
        return;
      }
    }
    if (changes['maintenanceMode'] == true) {
      final ok = await confirmDialog(
        context,
        title: 'تفعيل وضع الصيانة',
        message: 'سيتوقف الحجز للعملاء في التطبيق حتى تعطيله. متابعة؟',
        confirmLabel: 'تفعيل',
        danger: true,
      );
      if (!ok) return;
    }
    setState(() => _saving = true);
    try {
      final data = await Api.map('/api/admin/settings', method: 'PATCH', body: changes);
      if (!mounted) return;
      setState(() => _apply(data));
      showToast(context, 'تم حفظ الإعدادات (${changes.length})');
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime(String key) async {
    if (!_canWrite) return;
    final parts = (_times[key] ?? '').split(':');
    final initial = parts.length == 2
        ? TimeOfDay(hour: int.tryParse(parts[0]) ?? 8, minute: int.tryParse(parts[1]) ?? 0)
        : const TimeOfDay(hour: 8, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox(),
      ),
    );
    if (picked == null) return;
    setState(() {
      _times[key] = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    });
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty || _saving) return true;
    return confirmDialog(
      context,
      title: 'تجاهل التعديلات؟',
      message: 'لديك تغييرات غير محفوظة في الإعدادات.',
      confirmLabel: 'تجاهل',
      danger: true,
    );
  }

  Widget _readOnly(Widget child) => _canWrite
      ? child
      : AbsorbPointer(child: Opacity(opacity: 0.75, child: child));

  @override
  Widget build(BuildContext context) {
    final dirty = _dirty;
    final ready = !_loading && _raw.isNotEmpty;
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmLeave()) nav.pop();
      },
      child: Scaffold(
        bottomNavigationBar: _canWrite && ready
            ? BottomActionBar(
                label: dirty ? 'حفظ التغييرات (${_changes.length})' : 'لا تغييرات',
                busy: _saving,
                onPressed: dirty ? _save : null,
                secondaryLabel: dirty ? 'تراجع' : null,
                onSecondary: () => setState(() => _apply(_raw)),
              )
            : null,
        body: Form(
          key: _form,
          child: StaffPage(
            title: 'إعدادات المنصة',
            subtitle: _canWrite ? 'الدعم، الدفع، الشفتات، الصيانة' : 'عرض فقط',
            onRefresh: () async {
              if (_dirty) {
                showToast(context, 'احفظ التغييرات أو تراجع عنها أولاً');
                return;
              }
              await _load();
            },
            slivers: [
              if (_loading)
                const SliverToBoxAdapter(child: CatalogLoadingView(count: 5, height: 150))
              else if (_error != null && _raw.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: CatalogErrorView(message: _error!, onRetry: _load))
              else
                SliverToBoxAdapter(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  /// ملخص الحالة أعلى الصفحة: الصيانة، طرق الدفع، واتساب.
  Widget _statusStrip() {
    final gateways = ['manualProofEnabled', 'zainCashEnabled', 'qiCardEnabled'].where((k) => _flags[k] == true).length;
    final maintenance = _flags['maintenanceMode'] == true;
    final whatsapp = _flags['notifyWhatsappEnabled'] == true;
    Widget cell(IconData icon, String label, String value, Color color) => Expanded(
          child: Column(
            children: [
              IconBox(icon: icon, color: color, size: 34),
              const SizedBox(height: 6),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w900, color: color)),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: catalogMetaStyle),
            ],
          ),
        );
    return Pad(
      top: 4,
      child: StaffCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Row(
          children: [
            cell(Icons.construction_rounded, 'وضع الصيانة', maintenance ? 'مفعّل' : 'متوقف',
                maintenance ? placeDanger : placeSuccess),
            cell(Icons.payments_outlined, 'طرق الدفع', '$gateways من 3', gateways == 0 ? placeDanger : placeInk),
            cell(Icons.chat_outlined, 'واتساب', whatsapp ? 'مفعّل' : 'متوقف', whatsapp ? placeSuccess : placeInk3),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final configured = _raw['paymentGatewaysConfigured'] is Map
        ? Map<String, dynamic>.from(_raw['paymentGatewaysConfigured'] as Map)
        : <String, dynamic>{};
    final whatsappReady = _raw['whatsappConfigured'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_canWrite) const ReadOnlyBanner(text: 'عرض فقط — تعديل الإعدادات يتطلب صلاحية settings.write'),
        if (_flags['maintenanceMode'] == true)
          const CatalogAlertBanner(text: 'وضع الصيانة مفعّل — الحجز متوقف للعملاء', icon: Icons.construction_rounded),
        _statusStrip(),
        const SectionHeader('التواصل والسياسات'),
        _readOnly(FormSection(
          title: 'التواصل والدفع اليدوي',
          icon: Icons.support_agent_rounded,
          subtitle: 'يظهر للعملاء عند الدفع والتواصل',
          children: [
            StaffField(
              controller: _text['supportPhone']!,
              label: 'هاتف الدعم',
              hint: '9647700000000',
              ltr: true,
              keyboard: TextInputType.phone,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'هاتف الدعم مطلوب';
                if (!RegExp(r'^\+?[0-9 ]{7,16}$').hasMatch(t)) return 'رقم غير صالح';
                return null;
              },
            ),
            StaffField(
              controller: _text['paymentInstructions']!,
              label: 'تعليمات التحويل اليدوي',
              hint: 'زين كاش: 0780xxxxxxx\nاسم الحساب: …',
              maxLines: 5,
            ),
          ],
        )),
        _readOnly(FormSection(
          title: 'سياسات الحجز',
          icon: Icons.policy_outlined,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: StaffField(
                    controller: _text['commissionPercent']!,
                    label: 'عمولة المنصة %',
                    keyboard: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final n = parseNumber(v);
                      if (n == null) return 'مطلوب';
                      if (n < 0 || n > 100) return 'بين 0 و 100';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StaffField(
                    controller: _text['minBookingNoticeDays']!,
                    label: 'أقل مهلة (أيام)',
                    keyboard: TextInputType.number,
                    digitsOnly: true,
                    validator: (v) {
                      final n = parseNumber(v);
                      if (n == null) return 'مطلوب';
                      if (n < 0 || n > 365) return 'بين 0 و 365';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            StaffField(
              controller: _text['cancellationPolicy']!,
              label: 'سياسة الإلغاء',
              hint: 'نص يظهر للعملاء…',
              maxLines: 5,
            ),
          ],
        )),
        const SectionHeader('التشغيل'),
        _readOnly(FormSection(
          title: 'أوقات الشفتات',
          icon: Icons.schedule_rounded,
          subtitle: 'تُستخدم لحجوزات المزارع بنظام الشفتات',
          children: [
            _shiftRow('الشفت الصباحي', 'morningShiftStart', 'morningShiftEnd', placeShiftMorning),
            _shiftRow('الشفت المسائي', 'eveningShiftStart', 'eveningShiftEnd', placeShiftEvening),
            _shiftRow('اليوم الكامل', 'fullShiftStart', 'fullShiftEnd', placeShiftFull),
          ],
        )),
        _readOnly(FormSection(
          title: 'طرق الدفع المتاحة',
          icon: Icons.payments_outlined,
          children: [
            _flag('manualProofEnabled', 'تحويل يدوي + إثبات', 'العميل يحوّل ويرفع صورة الإثبات ليراجعها الفريق'),
            _flag(
              'zainCashEnabled',
              'زين كاش (بوابة إلكترونية)',
              configured['zainCash'] == true ? 'البوابة مضبوطة — يمكن تشغيلها' : 'غير مضبوطة على الخادم بعد',
              warn: configured['zainCash'] != true,
            ),
            _flag(
              'qiCardEnabled',
              'Qi Card (بوابة إلكترونية)',
              configured['qiCard'] == true ? 'البوابة مضبوطة — يمكن تشغيلها' : 'غير مضبوطة على الخادم بعد',
              warn: configured['qiCard'] != true,
            ),
          ],
        )),
        _readOnly(FormSection(
          title: 'الإشعارات',
          icon: Icons.notifications_active_outlined,
          children: [
            _flag(
              'notifyWhatsappEnabled',
              'إشعار واتساب لملاك الأماكن',
              whatsappReady ? 'يُرسل للمالك عند حجز جديد أو تغيّر حالة' : 'يتطلب تهيئة WhatsApp API على الخادم',
              warn: !whatsappReady,
              lockOn: !whatsappReady,
            ),
          ],
        )),
        _readOnly(FormSection(
          title: 'وضع الصيانة',
          icon: Icons.construction_rounded,
          children: [
            _flag('maintenanceMode', 'إيقاف الحجز مؤقتاً', 'يظهر للعملاء أن الحجز متوقف مؤقتاً'),
            if (_flags['maintenanceMode'] == true || _text['maintenanceMessage']!.text.isNotEmpty)
              StaffField(
                controller: _text['maintenanceMessage']!,
                label: 'الرسالة المعروضة للعملاء',
                hint: 'نعمل على تحديث النظام — سيعود الحجز قريباً',
                maxLines: 3,
              ),
          ],
        )),
        const SectionHeader('النظام', subtitle: 'للقراءة فقط'),
        FormSection(
          title: 'معلومات النظام',
          icon: Icons.info_outline_rounded,
          children: [
            CopyRow(label: 'اسم التطبيق', value: '${_raw['appName'] ?? ''}'),
            CopyRow(label: 'الموقع العام', value: '${_raw['publicWebUrl'] ?? ''}'),
            CopyRow(label: 'رابط API', value: '${_raw['apiUrl'] ?? ''}'),
            CopyRow(label: 'رابط الوسائط', value: '${_raw['mediaPublicUrl'] ?? ''}'),
            CopyRow(label: 'مزوّد OTP', value: '${_raw['otpProvider'] ?? ''}'),
            if (_raw['features'] is Map)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in (_raw['features'] as Map).entries)
                    StatusPill(
                      label: _featureLabel('${e.key}'),
                      color: e.value == true ? placeSuccess : placeInk2,
                      icon: e.value == true ? Icons.check_rounded : Icons.close_rounded,
                    ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  String _featureLabel(String k) => switch (k) {
        'smsOtp' => 'رموز OTP',
        'jobsQueue' => 'طابور المهام',
        'globalSearch' => 'البحث الشامل',
        'farmShifts' => 'شفتات المزارع',
        _ => k,
      };

  Widget _flag(String key, String title, String subtitle, {bool warn = false, bool lockOn = false}) {
    final value = _flags[key] ?? false;
    final row = ToggleRow(
      title: title,
      subtitle: subtitle,
      value: value,
      onChanged: (v) => setState(() => _flags[key] = v),
    );
    // لا يمكن التشغيل إن لم تُهيّأ الخدمة (يُسمح بالإيقاف فقط).
    if (lockOn && !value) {
      return Opacity(opacity: 0.6, child: AbsorbPointer(child: row));
    }
    if (!warn) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        if (value)
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              'تنبيه: مفعّلة لكن غير مضبوطة — قد تفشل للعملاء',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.w700, color: placeShiftMorning),
            ),
          ),
      ],
    );
  }

  Widget _shiftRow(String label, String startKey, String endKey, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 44, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 10),
        SizedBox(
          width: 86,
          child: Text(label, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, color: placeInk)),
        ),
        Expanded(child: _timeField(startKey, 'من')),
        const SizedBox(width: 8),
        Expanded(child: _timeField(endKey, 'إلى')),
      ],
    );
  }

  Widget _timeField(String key, String label) {
    final value = _times[key] ?? '';
    return FormField<String>(
      key: ValueKey('$key-$value'),
      initialValue: value,
      validator: (_) {
        final v = _times[key] ?? '';
        if (v.isEmpty) return 'مطلوب';
        if (!_timePattern.hasMatch(v)) return 'HH:mm';
        return null;
      },
      builder: (state) => InkWell(
        borderRadius: BorderRadius.circular(StaffRadius.md),
        onTap: () => _pickTime(key),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            errorText: state.errorText,
            suffixIcon: const Icon(Icons.access_time_rounded, size: 18),
          ),
          child: Text(
            value.isEmpty ? '—' : value,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w700, color: placeInk),
          ),
        ),
      ),
    );
  }
}
