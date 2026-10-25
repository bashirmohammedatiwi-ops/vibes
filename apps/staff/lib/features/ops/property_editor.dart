import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/form_kit.dart';
import '../../widgets/kit.dart';
import 'property_media.dart';

/// نموذج إضافة/تعديل مكان — كل خصائص المكان في شاشة واحدة مرتبة بأقسام.
/// عند الإنشاء ينتقل مباشرة إلى مدير الوسائط لإضافة الصور والفيديو والريلز و360°.
class PropertyEditorScreen extends StatefulWidget {
  const PropertyEditorScreen({super.key, this.property});

  /// null = إضافة مكان جديد، وإلا تفاصيل المكان من /api/staff/properties/:id/full
  final Map<String, dynamic>? property;

  @override
  State<PropertyEditorScreen> createState() => _PropertyEditorScreenState();
}

class _PropertyEditorScreenState extends State<PropertyEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _sectionKeys = List.generate(8, (_) => GlobalKey());
  int _section = 0;

  final _name = TextEditingController();
  final _nameEn = TextEditingController();
  final _description = TextEditingController();
  final _descriptionEn = TextEditingController();
  final _address = TextEditingController();
  final _mapLink = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _capacity = TextEditingController();
  final _price = TextEditingController();
  final _weekend = TextEditingController();
  final _priceMorning = TextEditingController();
  final _priceEvening = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _rules = TextEditingController();
  final _notes = TextEditingController();
  final _metaTitle = TextEditingController();
  final _metaDescription = TextEditingController();
  final _tagInput = TextEditingController();

  String _type = 'FARM';
  String? _provinceId;
  String? _cityId;
  String? _bookingMode;
  String? _morningStart;
  String? _morningEnd;
  String? _eveningStart;
  String? _eveningEnd;
  String? _providerId;
  String _status = 'DRAFT';
  bool _featured = false;
  bool _isNew = false;
  bool _isWinter = false;
  bool _hasIndoorPool = false;
  final Set<String> _amenityIds = {};
  final List<String> _tags = [];

  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _amenities = [];
  List<Map<String, dynamic>> _providers = [];

  bool _loadingMeta = true;
  String? _metaError;
  bool _saving = false;
  bool _dirty = false;

  bool get _isEdit => widget.property != null;
  String? get _id => widget.property?['id']?.toString();
  bool get _canModerate => Session.can('properties.moderate');

  @override
  void initState() {
    super.initState();
    _fillFromProperty();
    _loadMeta();
    _scroll.addListener(_syncSection);
  }

  /// يحدّث الشريحة النشطة في شريط الأقسام أثناء التمرير.
  void _syncSection() {
    final limit = MediaQuery.paddingOf(context).top + kToolbarHeight + 52 + 60;
    var current = 0;
    for (var i = 0; i < _sectionKeys.length; i++) {
      final box = _sectionKeys[i].currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      if (box.localToGlobal(Offset.zero).dy <= limit) current = i;
    }
    if (current != _section) setState(() => _section = current);
  }

  @override
  void dispose() {
    for (final c in [
      _name, _nameEn, _description, _descriptionEn, _address, _mapLink, _lat, _lng, //
      _capacity, _price, _weekend, _priceMorning, _priceEvening, _phone, _whatsapp,
      _rules, _notes, _metaTitle, _metaDescription, _tagInput,
    ]) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  String _numText(dynamic v) {
    if (v == null) return '';
    final n = double.tryParse('$v');
    if (n == null) return '$v';
    return n == n.roundToDouble() ? n.round().toString() : n.toString();
  }

  void _fillFromProperty() {
    final p = widget.property;
    if (p == null) return;
    _type = p['type']?.toString() ?? 'FARM';
    _name.text = p['name']?.toString() ?? '';
    _nameEn.text = p['nameEn']?.toString() ?? '';
    _description.text = p['description']?.toString() ?? '';
    _descriptionEn.text = p['descriptionEn']?.toString() ?? '';
    _address.text = p['address']?.toString() ?? '';
    _lat.text = _numText(p['latitude']);
    _lng.text = _numText(p['longitude']);
    _capacity.text = _numText(p['capacity']);
    _price.text = _numText(p['pricePerDay']);
    _weekend.text = _numText(p['weekendPrice']);
    _priceMorning.text = _numText(p['priceMorningShift']);
    _priceEvening.text = _numText(p['priceEveningShift']);
    _phone.text = p['phone']?.toString() ?? '';
    _whatsapp.text = p['whatsapp']?.toString() ?? '';
    _rules.text = p['rules']?.toString() ?? '';
    _notes.text = p['internalNotes']?.toString() ?? '';
    _metaTitle.text = p['metaTitle']?.toString() ?? '';
    _metaDescription.text = p['metaDescription']?.toString() ?? '';
    _cityId = p['cityId']?.toString();
    final city = p['city'];
    if (city is Map) _provinceId = city['provinceId']?.toString();
    _bookingMode = p['bookingMode']?.toString();
    _morningStart = _nullIfEmpty(p['morningStart']);
    _morningEnd = _nullIfEmpty(p['morningEnd']);
    _eveningStart = _nullIfEmpty(p['eveningStart']);
    _eveningEnd = _nullIfEmpty(p['eveningEnd']);
    _providerId = p['providerId']?.toString();
    _status = p['status']?.toString() ?? 'DRAFT';
    _featured = p['featured'] == true;
    _isNew = p['isNew'] == true;
    _isWinter = p['isWinter'] == true;
    _hasIndoorPool = p['hasIndoorPool'] == true;
    final links = p['amenityLinks'];
    if (links is List) {
      for (final link in links) {
        if (link is Map && link['amenityId'] != null) _amenityIds.add('${link['amenityId']}');
      }
    }
    final tags = p['tags'];
    if (tags is List) _tags.addAll(tags.map((e) => '$e'));
  }

  String? _nullIfEmpty(dynamic v) {
    final s = v?.toString() ?? '';
    return s.isEmpty ? null : s;
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loadingMeta = true;
      _metaError = null;
    });
    try {
      final data = await Api.map('/api/staff/properties/form-meta');
      List<Map<String, dynamic>> listOf(dynamic v) => (v as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _provinces = listOf(data['provinces']);
      _amenities = listOf(data['amenities']);
      _providers = listOf(data['providers']);
      // استنتاج المحافظة من المدينة إن لم تأتِ مع التفاصيل
      if (_cityId != null && _provinceId == null) {
        for (final prov in _provinces) {
          final cities = (prov['cities'] as List? ?? []);
          if (cities.any((c) => c is Map && '${c['id']}' == _cityId)) {
            _provinceId = '${prov['id']}';
            break;
          }
        }
      }
      if (mounted) setState(() => _loadingMeta = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingMeta = false;
          _metaError = '$e';
        });
      }
    }
  }

  void _touch() {
    if (!_dirty) setState(() => _dirty = true);
  }

  List<Map<String, dynamic>> get _cities {
    for (final prov in _provinces) {
      if ('${prov['id']}' == _provinceId) {
        return (prov['cities'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }
    return const [];
  }

  // ───────── الموقع ─────────

  /// يستخرج (lat,lng) من رابط خرائط جوجل أو من نص "lat, lng".
  ({double lat, double lng})? _parseCoords(String raw) {
    final text = raw.trim();
    final patterns = [
      RegExp(r'@(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)'),
      RegExp(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)'),
      RegExp(r'[?&](?:q|ll|query|destination)=(-?\d+(?:\.\d+)?)(?:,|%2C)\s*(-?\d+(?:\.\d+)?)'),
      RegExp(r'^\s*(-?\d+(?:\.\d+)?)\s*[,،;\s]\s*(-?\d+(?:\.\d+)?)\s*$'),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(text);
      if (m != null) {
        final lat = double.tryParse(m.group(1)!);
        final lng = double.tryParse(m.group(2)!);
        if (lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180) {
          return (lat: lat, lng: lng);
        }
      }
    }
    return null;
  }

  void _applyMapLink() {
    final coords = _parseCoords(_mapLink.text);
    if (coords == null) {
      showToast(
        context,
        'تعذّر استخراج الإحداثيات. افتح الرابط في الخرائط ثم انسخ الرابط الكامل أو الإحداثيات (مثال 33.3128, 44.3615)',
        error: true,
      );
      return;
    }
    setState(() {
      _lat.text = coords.lat.toStringAsFixed(7);
      _lng.text = coords.lng.toStringAsFixed(7);
      _dirty = true;
    });
    showToast(context, 'تم تحديد الموقع');
  }

  Future<void> _pasteMapLink() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      if (mounted) showToast(context, 'الحافظة فارغة', error: true);
      return;
    }
    _mapLink.text = text;
    _applyMapLink();
  }

  Future<void> _openInMaps() async {
    final lat = parseNumber(_lat.text);
    final lng = parseNumber(_lng.text);
    if (lat == null || lng == null) {
      showToast(context, 'أدخل الإحداثيات أولاً', error: true);
      return;
    }
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ───────── الأوقات ─────────

  Future<void> _pickTime(String? current, ValueChanged<String?> onPicked) async {
    TimeOfDay initial = const TimeOfDay(hour: 9, minute: 0);
    if (current != null && current.contains(':')) {
      final parts = current.split(':');
      initial = TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts[1]) ?? 0);
    }
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    setState(() {
      onPicked('$hh:$mm');
      _dirty = true;
    });
  }

  // ───────── الحفظ ─────────

  Map<String, dynamic> _buildBody() {
    String? opt(TextEditingController c) {
      final t = c.text.trim();
      return t.isEmpty ? null : t;
    }

    return {
      'type': _type,
      'name': _name.text.trim(),
      'nameEn': _nameEn.text.trim(),
      'description': _description.text.trim(),
      'descriptionEn': _descriptionEn.text.trim(),
      'cityId': _cityId,
      'address': opt(_address),
      'latitude': parseNumber(_lat.text),
      'longitude': parseNumber(_lng.text),
      'capacity': (parseNumber(_capacity.text) ?? 0).round(),
      'bookingMode': _bookingMode,
      'morningStart': _morningStart,
      'morningEnd': _morningEnd,
      'eveningStart': _eveningStart,
      'eveningEnd': _eveningEnd,
      'pricePerDay': parseNumber(_price.text) ?? 0,
      'weekendPrice': parseNumber(_weekend.text),
      'priceMorningShift': parseNumber(_priceMorning.text),
      'priceEveningShift': parseNumber(_priceEvening.text),
      'phone': opt(_phone),
      'whatsapp': opt(_whatsapp),
      'featured': _featured,
      'isNew': _isNew,
      // خصائص المزارع فقط
      'isWinter': _type == 'FARM' && _isWinter,
      'hasIndoorPool': _type == 'FARM' && _hasIndoorPool,
      // لا نرسل الحالة إن لم تتغيّر: الموظف بلا صلاحية الاعتماد لا يستطيع إعادة إرسال «معتمد».
      if (!_isEdit || _status != widget.property?['status']?.toString()) 'status': _status,
      'amenityIds': _amenityIds.toList(),
      'tags': _tags,
      'rules': _rules.text.trim(),
      'internalNotes': _notes.text.trim(),
      if (_metaTitle.text.trim().isNotEmpty) 'metaTitle': _metaTitle.text.trim(),
      if (_metaDescription.text.trim().isNotEmpty) 'metaDescription': _metaDescription.text.trim(),
      'providerId': _providerId,
    };
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      showToast(context, 'أكمل الحقول المطلوبة بالأحمر', error: true);
      return;
    }
    if (_cityId == null) {
      showToast(context, 'اختر المحافظة والمدينة', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final body = _buildBody();
      if (_isEdit) {
        await Api.map('/api/staff/properties/$_id', method: 'PATCH', body: body);
        if (!mounted) return;
        showToast(context, 'تم حفظ التعديلات');
        setState(() => _dirty = false);
        Navigator.of(context).pop(true);
      } else {
        final created = await Api.map('/api/staff/properties', method: 'POST', body: body);
        if (!mounted) return;
        setState(() => _dirty = false);
        showToast(context, 'تمت إضافة المكان — أضف الصور والفيديو الآن');
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                PropertyMediaScreen(propertyId: '${created['id']}', propertyName: created['name']?.toString() ?? _name.text.trim()),
          ),
        );
      }
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ───────── البناء ─────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirmDialog(
          context,
          title: 'تجاهل التغييرات؟',
          message: 'لديك تعديلات غير محفوظة. هل تريد الخروج دون حفظ؟',
          confirmLabel: 'خروج',
          danger: true,
        );
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isEdit ? 'تعديل المكان' : 'مكان جديد'),
              if (_isEdit && _name.text.trim().isNotEmpty)
                Text(
                  _name.text.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600, color: placeInk2),
                ),
            ],
          ),
          actions: [
            if (_dirty)
              const Padding(
                padding: EdgeInsetsDirectional.only(end: 16),
                child: Center(child: StatusChip('غير محفوظ', color: placeWarning, dense: true)),
              ),
          ],
          bottom: (_loadingMeta || _metaError != null)
              ? null
              : PreferredSize(preferredSize: const Size.fromHeight(52), child: _sectionBar()),
        ),
        body: _loadingMeta
            ? ListView(
                padding: const EdgeInsets.all(StaffSpace.page),
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  SkeletonBox(height: 260),
                  SizedBox(height: StaffSpace.gap),
                  SkeletonBox(height: 320),
                ],
              )
            : _metaError != null
            ? Center(
                child: EmptyView(
                  icon: Icons.cloud_off_rounded,
                  title: 'تعذّر تحميل بيانات النموذج',
                  subtitle: _metaError,
                  actionLabel: 'إعادة المحاولة',
                  onAction: _loadMeta,
                ),
              )
            : Form(
                key: _formKey,
                onChanged: _touch,
                child: SingleChildScrollView(
                  controller: _scroll,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(top: StaffSpace.gap, bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, section) in [
                        _basicsSection(),
                        _locationSection(),
                        _pricingSection(),
                        _contactSection(),
                        _amenitiesSection(),
                        _detailsSection(),
                        _publishSection(),
                        _advancedSection(),
                      ].indexed)
                        KeyedSubtree(key: _sectionKeys[i], child: section),
                    ],
                  ),
                ),
              ),
        bottomNavigationBar: (_loadingMeta || _metaError != null)
            ? null
            : BottomActionBar(label: _isEdit ? 'حفظ التعديلات' : 'حفظ ومتابعة للصور', busy: _saving, onPressed: _save),
      ),
    );
  }

  static const _sectionNames = ['الأساسيات', 'الموقع', 'الأسعار', 'التواصل', 'المزايا', 'الوسوم', 'النشر', 'متقدّم'];

  void _jumpTo(int i) {
    setState(() => _section = i);
    final ctx = _sectionKeys[i].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic, alignment: 0.02);
    }
  }

  Widget _sectionBar() {
    return Container(
      height: 52,
      alignment: AlignmentDirectional.centerStart,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: StaffSpace.page, vertical: 8),
        itemCount: _sectionNames.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final on = _section == i;
          final r = BorderRadius.circular(999);
          return Material(
            color: on ? placeInk : Colors.white,
            borderRadius: r,
            child: InkWell(
              borderRadius: r,
              onTap: () => _jumpTo(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: r,
                  border: Border.all(color: on ? placeInk : placeLine),
                ),
                child: Text(
                  _sectionNames[i],
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w800, color: on ? Colors.white : placeInk2),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _basicsSection() {
    return FormSection(
      title: 'المعلومات الأساسية',
      subtitle: 'ما يراه الزبون أولاً',
      icon: Icons.storefront_rounded,
      children: [
        const _FieldLabel('نوع المكان'),
        ChoicePills<String>(
          options: const ['FARM', 'HALL', 'DECORATION'],
          value: _type,
          labelOf: placeTypeLabel,
          iconOf: placeTypeIcon,
          onChanged: (v) => setState(() {
            _type = v;
            // المزايا خاصة بالنوع — ننظّف ما لا ينطبق على النوع الجديد
            _amenityIds.removeWhere((id) {
              final a = _amenities.where((x) => '${x['id']}' == id);
              if (a.isEmpty) return false;
              return !_amenityApplies(a.first);
            });
            _dirty = true;
          }),
        ),
        StaffField(
          controller: _name,
          label: 'اسم المكان *',
          hint: 'مثال: مزرعة الريحان',
          validator: (v) => requiredValidator(v, 'اسم المكان مطلوب'),
        ),
        StaffField(controller: _description, label: 'الوصف', hint: 'صف المكان بأسلوب جذاب للزبائن', maxLines: 5),
        StaffField(
          controller: _capacity,
          label: 'السعة (عدد الأشخاص)',
          helper: 'أقصى عدد ضيوف يستوعبه المكان',
          keyboard: TextInputType.number,
          digitsOnly: true,
        ),
      ],
    );
  }

  Widget _locationSection() {
    final cities = _cities;
    return FormSection(
      title: 'الموقع',
      subtitle: 'المحافظة والمدينة والإحداثيات',
      icon: Icons.place_rounded,
      children: [
        DropdownButtonFormField<String>(
          value: _provinceId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'المحافظة *'),
          items: [for (final p in _provinces) DropdownMenuItem(value: '${p['id']}', child: Text('${p['nameAr']}'))],
          validator: (v) => v == null ? 'اختر المحافظة' : null,
          onChanged: (v) => setState(() {
            _provinceId = v;
            _cityId = null;
            _dirty = true;
          }),
        ),
        DropdownButtonFormField<String>(
          value: cities.any((c) => '${c['id']}' == _cityId) ? _cityId : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'المدينة / المنطقة *'),
          items: [for (final c in cities) DropdownMenuItem(value: '${c['id']}', child: Text('${c['nameAr']}'))],
          validator: (v) => v == null ? 'اختر المدينة' : null,
          onChanged: (v) => setState(() {
            _cityId = v;
            _dirty = true;
          }),
        ),
        StaffField(controller: _address, label: 'العنوان التفصيلي', hint: 'أقرب نقطة دالة، الشارع …'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: placePaper,
            borderRadius: BorderRadius.circular(StaffRadius.md),
            border: Border.all(color: placeLineSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_fix_high_rounded, size: 16, color: placeBrass),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'الصق رابط الموقع من خرائط جوجل ليُستخرج خط الطول والعرض تلقائياً',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: placeInk2, height: 1.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _mapLink,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(hintText: 'https://www.google.com/maps/…  أو  33.31, 44.36'),
                      onSubmitted: (_) => _applyMapLink(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: placeInk, foregroundColor: Colors.white, minimumSize: const Size(48, 48)),
                    tooltip: 'لصق من الحافظة',
                    onPressed: _pasteMapLink,
                    icon: const Icon(Icons.content_paste_go_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _applyMapLink,
                      icon: const Icon(Icons.my_location_outlined, size: 18),
                      label: const Text('استخراج'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openInMaps,
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('فتح بالخرائط'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: StaffField(
                controller: _lat,
                label: 'خط العرض *',
                ltr: true,
                keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true),
                validator: (v) {
                  final n = parseNumber(v);
                  if (n == null) return 'مطلوب';
                  if (n.abs() > 90) return 'غير صالح';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StaffField(
                controller: _lng,
                label: 'خط الطول *',
                ltr: true,
                keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true),
                validator: (v) {
                  final n = parseNumber(v);
                  if (n == null) return 'مطلوب';
                  if (n.abs() > 180) return 'غير صالح';
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _pricingSection() {
    final shifted = _bookingMode == 'SHIFTS' || _bookingMode == 'HYBRID';
    String modeLabel(String? m) => switch (m) {
      'FULL_DAY' => 'يوم كامل',
      'SHIFTS' => 'شفتان',
      'HYBRID' => 'هجين',
      _ => 'تلقائي',
    };
    return FormSection(
      title: 'الحجز والأسعار',
      subtitle: 'الأسعار بالدينار العراقي',
      icon: Icons.payments_rounded,
      children: [
        const _FieldLabel('وضع الحجز'),
        ChoicePills<String?>(
          options: const [null, 'FULL_DAY', 'SHIFTS', 'HYBRID'],
          value: _bookingMode,
          labelOf: modeLabel,
          onChanged: (v) => setState(() {
            _bookingMode = v;
            _dirty = true;
          }),
        ),
        Text(switch (_bookingMode) {
          'FULL_DAY' => 'يُحجز المكان ليوم كامل فقط.',
          'SHIFTS' => 'يُحجز المكان بشفت صباحي أو مسائي (حتى شفتان يومياً).',
          'HYBRID' => 'يمكن حجز اليوم كاملاً أو بالشفت.',
          _ => 'يُحدَّد الوضع تلقائياً حسب نوع المكان.',
        }, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk3, height: 1.4)),
        StaffField(
          controller: _price,
          label: 'السعر لليوم الكامل *',
          suffix: const _Unit('د.ع'),
          keyboard: TextInputType.number,
          validator: (v) {
            final n = parseNumber(v);
            if (n == null) return 'السعر مطلوب';
            if (n < 0) return 'غير صالح';
            return null;
          },
        ),
        StaffField(
          controller: _weekend,
          label: 'سعر نهاية الأسبوع (اختياري)',
          helper: 'اتركه فارغاً لاستخدام السعر اليومي',
          suffix: const _Unit('د.ع'),
          keyboard: TextInputType.number,
        ),
        if (shifted) ...[
          Row(
            children: [
              Expanded(
                child: StaffField(controller: _priceMorning, label: 'سعر الصباحي', keyboard: TextInputType.number),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StaffField(controller: _priceEvening, label: 'سعر المسائي', keyboard: TextInputType.number),
              ),
            ],
          ),
          const Divider(height: 8, color: placeLineSoft),
          const _FieldLabel('أوقات الشفتات'),
          Row(
            children: [
              Expanded(
                child: _TimeBox(
                  label: 'بداية الصباحي',
                  value: _morningStart,
                  onTap: () => _pickTime(_morningStart, (v) => _morningStart = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeBox(label: 'نهاية الصباحي', value: _morningEnd, onTap: () => _pickTime(_morningEnd, (v) => _morningEnd = v)),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _TimeBox(
                  label: 'بداية المسائي',
                  value: _eveningStart,
                  onTap: () => _pickTime(_eveningStart, (v) => _eveningStart = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeBox(label: 'نهاية المسائي', value: _eveningEnd, onTap: () => _pickTime(_eveningEnd, (v) => _eveningEnd = v)),
              ),
            ],
          ),
        ],
        if (_isEdit)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: placeGoldSoft, borderRadius: BorderRadius.circular(StaffRadius.md)),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: placeBrass),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'أسعار المواسم وأيام محددة تُدار من «الأسعار والتوفر» في صفحة المكان.',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600, color: placeInk),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _contactSection() {
    return FormSection(
      title: 'التواصل',
      subtitle: 'أرقام المكان والمزوّد المالك',
      icon: Icons.call_rounded,
      children: [
        StaffField(controller: _phone, label: 'رقم الهاتف', hint: '07xx xxx xxxx', ltr: true, keyboard: TextInputType.phone),
        StaffField(controller: _whatsapp, label: 'واتساب', hint: '07xx xxx xxxx', ltr: true, keyboard: TextInputType.phone),
        if (_providers.isNotEmpty)
          DropdownButtonFormField<String?>(
            value: _providers.any((p) => '${p['id']}' == _providerId) ? _providerId : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'المزوّد (المالك)'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('بدون مزوّد')),
              for (final p in _providers)
                DropdownMenuItem<String?>(
                  value: '${p['id']}',
                  child: Text(() {
                    final biz = p['businessName']?.toString() ?? '';
                    final user = p['user'];
                    final name = user is Map ? user['name']?.toString() ?? '' : '';
                    final phone = user is Map ? user['phone']?.toString() ?? '' : '';
                    final title = biz.isNotEmpty ? biz : (name.isNotEmpty ? name : 'مزوّد');
                    return phone.isEmpty ? title : '$title · $phone';
                  }(), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() {
              _providerId = v;
              _dirty = true;
            }),
          ),
      ],
    );
  }

  bool _amenityApplies(Map<String, dynamic> a) {
    final applies = a['appliesTo'];
    if (applies is! List || applies.isEmpty) return true;
    return applies.map((e) => '$e').contains(_type);
  }

  Widget _amenitiesSection() {
    final items = _amenities.where(_amenityApplies).toList();
    final byCategory = <String, List<Map<String, dynamic>>>{};
    for (final a in items) {
      byCategory.putIfAbsent(a['category']?.toString() ?? 'general', () => []).add(a);
    }
    return FormSection(
      title: 'المزايا والخدمات',
      subtitle: _amenityIds.isEmpty ? 'اختر ما يتوفر في المكان' : 'تم اختيار ${_amenityIds.length}',
      icon: Icons.checklist_rounded,
      children: [
        if (items.isEmpty)
          const Text(
            'لا مزايا معرّفة لهذا النوع بعد.',
            style: TextStyle(fontFamily: 'Cairo', color: placeInk3),
          )
        else
          for (final entry in byCategory.entries)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (byCategory.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      _categoryLabel(entry.key),
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w800, color: placeInk2),
                    ),
                  ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final a in entry.value)
                      FilterChip(
                        avatar: _amenityIds.contains('${a['id']}') ? const Icon(Icons.check_rounded, size: 16, color: placeGold) : null,
                        label: Text('${a['nameAr']}'),
                        selected: _amenityIds.contains('${a['id']}'),
                        showCheckmark: false,
                        selectedColor: placeInk,
                        backgroundColor: Colors.white,
                        side: BorderSide(color: _amenityIds.contains('${a['id']}') ? placeInk : placeLine),
                        labelStyle: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _amenityIds.contains('${a['id']}') ? Colors.white : placeInk,
                        ),
                        onSelected: (on) => setState(() {
                          final id = '${a['id']}';
                          on ? _amenityIds.add(id) : _amenityIds.remove(id);
                          _dirty = true;
                        }),
                      ),
                  ],
                ),
              ],
            ),
      ],
    );
  }

  String _categoryLabel(String key) => switch (key) {
    'general' => 'عام',
    _ => key,
  };

  Widget _detailsSection() {
    return FormSection(
      title: 'الوسوم والشروط',
      subtitle: 'تساعد الزبون في البحث وتوضّح القواعد',
      icon: Icons.sell_rounded,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagInput,
                decoration: const InputDecoration(labelText: 'وسم جديد', hintText: 'مثال: مسبح، عائلي'),
                onSubmitted: (_) => _addTag(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'إضافة الوسم',
              style: IconButton.styleFrom(backgroundColor: placeInk, minimumSize: const Size(48, 48)),
              onPressed: _addTag,
              icon: const Icon(Icons.add, color: Colors.white),
            ),
          ],
        ),
        if (_tags.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in _tags)
                InputChip(
                  label: Text(
                    t,
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
                  ),
                  backgroundColor: placePaper,
                  side: const BorderSide(color: placeLine),
                  onDeleted: () => setState(() {
                    _tags.remove(t);
                    _dirty = true;
                  }),
                ),
            ],
          ),
        StaffField(controller: _rules, label: 'الشروط والقواعد', hint: 'سياسة الإلغاء، التعليمات، ما هو ممنوع …', maxLines: 4),
      ],
    );
  }

  void _addTag() {
    final t = _tagInput.text.trim();
    if (t.isEmpty) return;
    if (!_tags.contains(t)) {
      setState(() {
        _tags.add(t);
        _dirty = true;
      });
    }
    _tagInput.clear();
  }

  Widget _publishSection() {
    final statuses = _canModerate ? const ['DRAFT', 'PENDING', 'APPROVED', 'SUSPENDED', 'REJECTED'] : const ['DRAFT', 'PENDING'];
    return FormSection(
      title: 'النشر والظهور',
      subtitle: 'الحالة وأماكن الظهور في التطبيق',
      icon: Icons.rocket_launch_rounded,
      children: [
        const _FieldLabel('الحالة'),
        if (statuses.contains(_status))
          ChoicePills<String>(
            options: statuses,
            value: _status,
            labelOf: placeStatusLabel,
            onChanged: (v) => setState(() {
              _status = v;
              _dirty = true;
            }),
          )
        else
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusPill(label: placeStatusLabel(_status), color: placeStatusColor(_status)),
          ),
        if (!_canModerate)
          Text(
            statuses.contains(_status)
                ? 'النشر للزبائن يتم بعد اعتماد المشرف — اختر «بانتظار الاعتماد» عند الجاهزية.'
                : 'تغيير حالة النشر بيد المشرف.',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk3, height: 1.4),
          ),
        const Divider(height: 4, color: placeLineSoft),
        ToggleRow(
          title: 'مكان مميز',
          subtitle: 'يظهر في قسم المميز بالصفحة الرئيسية',
          value: _featured,
          onChanged: (v) => setState(() {
            _featured = v;
            _dirty = true;
          }),
        ),
        ToggleRow(
          title: 'جديد',
          subtitle: 'يظهر ضمن «الجديد»',
          value: _isNew,
          onChanged: (v) => setState(() {
            _isNew = v;
            _dirty = true;
          }),
        ),
        if (_type == 'FARM') ...[
          ToggleRow(
            title: '❄️ مزرعة شتوية',
            subtitle: 'تظهر في قسم «مزارع شتوية» وفلتر البحث',
            value: _isWinter,
            onChanged: (v) => setState(() {
              _isWinter = v;
              _dirty = true;
            }),
          ),
          ToggleRow(
            title: '🏊 مسبح مغلق',
            subtitle: 'مسبح داخلي أو مسقوف — شارة على المزرعة وفلتر في البحث',
            value: _hasIndoorPool,
            onChanged: (v) => setState(() {
              _hasIndoorPool = v;
              _dirty = true;
            }),
          ),
        ],
      ],
    );
  }

  Widget _advancedSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(StaffSpace.page, 0, StaffSpace.page, StaffSpace.gap),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(StaffRadius.lg),
        border: Border.all(color: placeLine),
        boxShadow: staffCardShadow,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: placeGoldSoft, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.tune_rounded, size: 20, color: placeBrass),
          ),
          title: const Text(
            'متقدّم',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 15.5, color: placeInk),
          ),
          subtitle: const Text(
            'الإنجليزية، SEO، وملاحظات داخلية',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600, color: placeInk2),
          ),
          children: [
            StaffField(controller: _nameEn, label: 'الاسم بالإنجليزية', ltr: true),
            const SizedBox(height: 12),
            StaffField(controller: _descriptionEn, label: 'الوصف بالإنجليزية', ltr: true, maxLines: 3),
            const SizedBox(height: 12),
            StaffField(controller: _metaTitle, label: 'عنوان SEO'),
            const SizedBox(height: 12),
            StaffField(controller: _metaDescription, label: 'وصف SEO', maxLines: 2),
            const SizedBox(height: 12),
            StaffField(controller: _notes, label: 'ملاحظات داخلية', helper: 'للموظفين فقط — لا تظهر للزبائن', maxLines: 3),
          ],
        ),
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.label, required this.value, required this.onTap});

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.schedule_rounded, size: 19)),
        child: Text(
          value ?? 'اختر',
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
          style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w700, color: value == null ? placeInk2 : placeInk),
        ),
      ),
    );
  }
}

/// عنوان صغير فوق مجموعة اختيارات.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w800, color: placeInk),
    );
  }
}

/// وحدة العملة داخل حقل السعر.
class _Unit extends StatelessWidget {
  const _Unit(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 14),
      child: Align(
        widthFactor: 1,
        alignment: AlignmentDirectional.centerEnd,
        child: Text(
          text,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w800, color: placeInk3),
        ),
      ),
    );
  }
}
