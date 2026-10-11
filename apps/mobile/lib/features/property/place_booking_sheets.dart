import '../../core/theme/world_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/models/models.dart';
import 'place_experience_ui.dart';
import 'shift_calendar_ui.dart';

/// ═══════════════════════════════════════════════════════════
/// لوحات الحجز المركّزة — كل قرار في لوحة واحدة صغيرة
/// (نمط Airbnb: الملخص دائماً ظاهر، الاختيار يحدث في لوحة)
/// ═══════════════════════════════════════════════════════════

/// توفر كل شفت — كم يوماً متاحاً وأقربها.
class PlaceShiftAvailability {
  const PlaceShiftAvailability(this.availableDays, this.nextDate);

  final int availableDays;
  final DateTime? nextDate;

  bool get isAvailable => availableDays > 0;
}

/// حساب توفر الشفتات من أسعار الأيام القادمة.
Map<ShiftType, PlaceShiftAvailability> computeShiftAvailability(
  List<DayPricing> days,
) {
  final counts = {for (final s in ShiftType.values) s: 0};
  final next = <ShiftType, DateTime>{};
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  for (final day in days) {
    final d = DateTime(day.date.year, day.date.month, day.date.day);
    if (d.isBefore(today) || day.isBlocked) continue;
    for (final s in ShiftType.values) {
      if (day.isShiftOccupied(s)) continue;
      if (day.priceFor(s) > 0) {
        counts[s] = counts[s]! + 1;
        next.putIfAbsent(s, () => d);
      }
    }
  }

  return {
    for (final s in ShiftType.values)
      s: PlaceShiftAvailability(counts[s]!, next[s]),
  };
}

/// قاعدة موحّدة: مقبض + عنوان + وصف قصير + زر اعتماد.
class PlaceSheetFrame extends StatelessWidget {
  const PlaceSheetFrame({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: placeLine,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: placeInk,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: placeInk2,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Flexible(child: child),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}

/// زر الاعتماد الموحّد لكل اللوحات.
class PlaceSheetConfirm extends StatelessWidget {
  const PlaceSheetConfirm({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: context.world.accentDeep,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: onPressed,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

/// ═══════════════ لوحة الشفت — حسب التوفر الفعلي ═══════════════
Future<ShiftType?> showPlaceShiftSheet({
  required BuildContext context,
  required Property property,
  required ShiftType selected,
  required List<DayPricing> days,
}) {
  return showModalBottomSheet<ShiftType>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    isScrollControlled: true,
    builder: (ctx) {
      var current = selected;
      return StatefulBuilder(
        builder: (ctx, setSheet) {
          return PlaceSheetFrame(
            title: 'اختر فترة الإقامة',
            subtitle: 'التوفر محسوب من تقويم المكان — الفرق في السعر واضح',
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: _ShiftOptions(
                property: property,
                days: days,
                selected: current,
                onSelect: (s) => setSheet(() => current = s),
              ),
            ),
            footer: PlaceSheetConfirm(
              label: 'اعتماد الفترة',
              onPressed: () => Navigator.pop(ctx, current),
            ),
          );
        },
      );
    },
  );
}

class _ShiftOptions extends StatelessWidget {
  const _ShiftOptions({
    required this.property,
    required this.days,
    required this.selected,
    required this.onSelect,
  });

  final Property property;
  final List<DayPricing> days;
  final ShiftType selected;
  final ValueChanged<ShiftType> onSelect;

  @override
  Widget build(BuildContext context) {
    final labels = property.shiftLabels;
    final availability = computeShiftAvailability(days);

    final options = <(ShiftType, String, String?, IconData, Color, num)>[
      (
        ShiftType.morning,
        'الفترة الصباحية',
        labels.morning,
        Icons.wb_sunny_outlined,
        placeShiftMorning,
        property.priceMorningShift ?? 0,
      ),
      (
        ShiftType.evening,
        'الفترة المسائية',
        labels.evening,
        Icons.dark_mode_outlined,
        placeShiftEvening,
        property.priceEveningShift ?? 0,
      ),
      (
        ShiftType.full,
        'اليوم الكامل',
        null,
        Icons.calendar_today_rounded,
        placeShiftFull,
        property.pricePerDay,
      ),
    ];

    // «اليوم الكامل» يظهر فقط إن كان للمكان شفتات أصلاً.
    final visible = property.supportsShifts
        ? options
              .where((o) => o.$1 != ShiftType.full || property.supportsFullDay)
              .toList()
        : options.where((o) => o.$1 == ShiftType.full).toList();

    return Column(
      children: [
        for (final (type, title, time, icon, tint, price) in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ShiftTile(
              icon: icon,
              tint: tint,
              title: title,
              time: time,
              price: price,
              availability: availability[type]!,
              selected: selected == type,
              onTap: () {
                HapticFeedback.selectionClick();
                onSelect(type);
              },
            ),
          ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _ShiftTile extends StatelessWidget {
  const _ShiftTile({
    required this.icon,
    required this.tint,
    required this.title,
    required this.time,
    required this.price,
    required this.availability,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String? time;
  final num price;
  final PlaceShiftAvailability availability;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final available = availability.isAvailable;

    return Material(
      color: selected ? tint.withValues(alpha: 0.05) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: available
            ? () {
                HapticFeedback.selectionClick();
                onTap();
              }
            : null,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? tint : placeLine,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Opacity(
            opacity: available ? 1 : 0.55,
            child: Row(
              children: [
                // أيقونة الفترة بلونها
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: selected ? tint : tint.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 21,
                    color: selected ? Colors.white : tint,
                  ),
                ),
                const SizedBox(width: 12),
                // الاسم + الوقت + التوفر
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          color: placeInk,
                        ),
                      ),
                      if (time != null && time!.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          time!,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: placeInk2,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: available
                                  ? const Color(0xFF16A34A)
                                  : placeInk2,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              available
                                  ? (availability.nextDate != null
                                        ? '${availability.availableDays} يوم متاح · أقربها ${placeFormatDateShort(availability.nextDate!)}'
                                        : '${availability.availableDays} يوم متاح')
                                  : 'لا توفر حالياً لهذه الفترة',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: available
                                    ? const Color(0xFF15803D)
                                    : placeInk2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // السعر
                if (price > 0)
                  PlaceFullPriceText(price, size: 14.5)
                else
                  const Text(
                    '—',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                      color: placeInk2,
                    ),
                  ),
                const SizedBox(width: 8),
                // راديو
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? tint : placeLine,
                      width: selected ? 7 : 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ═══════════════ لوحة الضيوف — كتابة من الكيبورد + اختصارات ═══════════════
Future<int?> showPlaceGuestsSheet({
  required BuildContext context,
  required int current,
  required int capacity,
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    isScrollControlled: true,
    builder: (ctx) {
      var value = current;
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: StatefulBuilder(
          builder: (ctx, setSheet) {
            final max = capacity > 0 ? capacity : 200;
            return PlaceSheetFrame(
              title: 'كم عدد الضيوف؟',
              subtitle: capacity > 0
                  ? 'سعة المكان $capacity — اكتب الرقم مباشرة'
                  : 'اكتب العدد من لوحة المفاتيح',
              child: PlaceGuestsEditor(
                value: value,
                max: max,
                onChanged: (v) => setSheet(() => value = v),
              ),
              footer: PlaceSheetConfirm(
                label: 'اعتماد عدد الضيوف',
                onPressed: () => Navigator.pop(ctx, value),
              ),
            );
          },
        ),
      );
    },
  );
}

/// محرّر الضيوف — حقل كيبورد رقمي +/− واختصارات سريعة.
class PlaceGuestsEditor extends StatefulWidget {
  const PlaceGuestsEditor({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  State<PlaceGuestsEditor> createState() => _PlaceGuestsEditorState();
}

class _PlaceGuestsEditorState extends State<PlaceGuestsEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  static const _scenes = [
    (1, 'شخصي', Icons.person_outline_rounded),
    (2, 'ثنائي', Icons.people_outline_rounded),
    (4, 'عائلي', Icons.family_restroom_rounded),
    (8, 'حفلة', Icons.celebration_outlined),
    (15, 'مناسبة كبيرة', Icons.groups_2_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
    _focus = FocusNode();
  }

  @override
  void didUpdateWidget(covariant PlaceGuestsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final text = '${widget.value}';
      if (_controller.text != text) {
        _controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _set(int next) {
    final clamped = next.clamp(1, widget.max);
    widget.onChanged(clamped);
  }

  void _onTyped(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      widget.onChanged(1);
      return;
    }
    final parsed = int.tryParse(digits) ?? 1;
    _set(parsed);
  }

  String get _sceneLabel {
    for (final (n, label, _) in _scenes.reversed) {
      if (widget.value >= n) return label;
    }
    return _scenes.first.$2;
  }

  IconData get _sceneIcon {
    for (final (n, _, icon) in _scenes.reversed) {
      if (widget.value >= n) return icon;
    }
    return _scenes.first.$3;
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final max = widget.max;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            decoration: BoxDecoration(
              color: placePaper,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_sceneIcon, size: 22, color: placeInk),
                    const SizedBox(width: 8),
                    Text(
                      _sceneLabel,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: placeInk2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _RoundBtn(
                      icon: Icons.remove_rounded,
                      enabled: value > 1,
                      onTap: () => _set(value - 1),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: placeInk,
                          height: 1.1,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: placeLine),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: placeLine),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: placeBrass,
                              width: 1.6,
                            ),
                          ),
                        ),
                        onChanged: _onTyped,
                        onTap: () {
                          _controller.selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: _controller.text.length,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    _RoundBtn(
                      icon: Icons.add_rounded,
                      enabled: value < max,
                      onTap: () => _set(value + 1),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  value == 1 ? 'ضيف واحد' : '$value ضيوف · حد أقصى $max',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: placeInk2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'اختيار سريع',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: placeInk2.withValues(alpha: 0.9),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (max >= 2)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final n in [1, 2, 4, 6, 8, 10, 15, 20])
                  if (n <= max)
                    _QuickCountChip(
                      value: n,
                      selected: value == n,
                      onTap: () => _set(n),
                    ),
              ],
            ),
        ],
      ),
    );
  }
}

class _QuickCountChip extends StatelessWidget {
  const _QuickCountChip({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? context.world.accentDeep : placePaper,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? context.world.accentDeep : placeLine,
            ),
          ),
          child: Text(
            '$value',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : placeInk,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? context.world.accentDeep : const Color(0xFFEDF0F4),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onTap();
              }
            : null,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(
            icon,
            size: 24,
            color: enabled ? Colors.white : placeInk2,
          ),
        ),
      ),
    );
  }
}

/// ═══════════════ لوحة الملاحظة ═══════════════
Future<String?> showPlaceNotesSheet({
  required BuildContext context,
  required String initial,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final controller = TextEditingController(text: initial);
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: PlaceSheetFrame(
          title: 'ملاحظة للمضيف',
          subtitle: 'مناسبتك أو طلب خاص — تصل للمضيف مع الحجز',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: TextField(
              controller: controller,
              maxLines: 4,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'مثال: حفل تخرج — نحتاج الطاولة الرئيسية قبل الوصول',
                hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
                filled: true,
                fillColor: placePaper,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          footer: PlaceSheetConfirm(
            label: 'حفظ',
            onPressed: () => Navigator.pop(ctx, controller.text),
          ),
        ),
      );
    },
  );
}

/// ═══════════════ لوحة الكوبون ═══════════════
Future<String?> showPlaceCouponSheet({
  required BuildContext context,
  required String initial,
  required List<String> suggested,
  required bool applied,
  required String? error,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final controller = TextEditingController(text: initial);
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: PlaceSheetFrame(
          title: 'رمز خصم',
          subtitle: 'يُطبَّق فوراً ويرى المضيف النتيجة',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: 'أدخل الرمز',
                    filled: true,
                    fillColor: placePaper,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: applied
                        ? const Icon(
                            Icons.check_circle,
                            color: Color(0xFF15803D),
                          )
                        : null,
                  ),
                ),
                if (suggested.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'رموز متاحة لهذا المكان',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: placeInk2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in suggested)
                        ActionChip(
                          label: Text(s),
                          onPressed: () => controller.text = s,
                        ),
                    ],
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ],
              ],
            ),
          ),
          footer: PlaceSheetConfirm(
            label: 'تطبيق',
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          ),
        ),
      );
    },
  );
}
