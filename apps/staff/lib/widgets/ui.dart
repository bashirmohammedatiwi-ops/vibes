import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/shift.dart';
import '../core/theme.dart';

/// ═══════════════════════════════════════════════════════════
/// عناصر قديمة مشتركة — أُعيد تنسيقها على نظام «VIBES مكتب»
/// (نفس الواجهات البرمجية؛ تستفيد منها كل الشاشات تلقائياً).
/// ═══════════════════════════════════════════════════════════

/// رأس شاشة بسيط: عنوان كبير + وصف + عنصر على الطرف.
class MaisonHeader extends StatelessWidget {
  const MaisonHeader({super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(StaffSpace.page, 10, StaffSpace.page, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 24, fontWeight: FontWeight.w900, color: placeInk, height: 1.25),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600, color: placeInk2, height: 1.45),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// مؤشر رقمي صغير (يُستخدم داخل Row — يتمدد تلقائياً).
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.accent});

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? placeInk;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(StaffRadius.lg),
          border: Border.all(color: placeLine),
          boxShadow: staffCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: accent ?? placeGold, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: placeInk2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                style: TextStyle(fontFamily: 'Montserrat', fontSize: 20, fontWeight: FontWeight.w800, color: color, height: 1.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// شارة الشفت (صباحي/مسائي/كامل).
class ShiftBadge extends StatelessWidget {
  const ShiftBadge({super.key, required this.shift});

  final String? shift;

  @override
  Widget build(BuildContext context) {
    final color = shiftColor(shift);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            shiftLabel(shift),
            style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

/// نقطة الحضور (متاح/مشغول…) مع نبض اختياري.
class PresenceDot extends StatelessWidget {
  const PresenceDot({super.key, required this.state, this.pulse = false});

  final String state;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final color = presenceColor(state);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: pulse ? 1.15 : 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6)],
        ),
      ),
    );
  }
}

/// صف شرائح تصفية أفقي قابل للتمرير.
class FilterChipsRow extends StatelessWidget {
  const FilterChipsRow({super.key, required this.options, required this.selected, required this.onSelected, this.labelBuilder});

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final String Function(String)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: StaffSpace.page, vertical: 8),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Padding(
              padding: EdgeInsetsDirectional.only(end: i == options.length - 1 ? 0 : 8),
              child: _FilterPill(
                label: labelBuilder?.call(options[i]) ?? options[i],
                selected: selected == options[i],
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(options[i]);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(999);
    return Material(
      color: selected ? placeInk : Colors.white,
      borderRadius: r,
      child: InkWell(
        borderRadius: r,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: r,
            border: Border.all(color: selected ? placeInk : placeLine),
          ),
          child: Text(
            label,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w800, color: selected ? Colors.white : placeInk),
          ),
        ),
      ),
    );
  }
}

class AudioWaveBars extends StatefulWidget {
  const AudioWaveBars({super.key, this.active = true, this.color = placeBrass});

  final bool active;
  final Color color;

  @override
  State<AudioWaveBars> createState() => _AudioWaveBarsState();
}

class _AudioWaveBarsState extends State<AudioWaveBars> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (i) => _bar(12, widget.color.withValues(alpha: 0.25))),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(7, (i) {
            final t = (_controller.value + i * 0.12) % 1.0;
            final h = 10 + (t < 0.5 ? t * 40 : (1 - t) * 40);
            return _bar(h, widget.color);
          }),
        );
      },
    );
  }

  Widget _bar(double height, Color color) {
    return Container(
      width: 5,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
    );
  }
}

/// حالة فارغة (النسخة القديمة) — بنفس شكل EmptyView الجديد.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: placeGoldSoft, shape: BoxShape.circle),
              child: const Icon(Icons.inbox_rounded, size: 34, color: placeBrass),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 16.5, fontWeight: FontWeight.w900, color: placeInk),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: placeInk2, height: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// نافذة سفلية لإدخال نص قصير (سبب، ملاحظة…).
Future<String?> promptText(BuildContext context, {required String title, String hint = '', int maxLines = 3}) async {
  final controller = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(StaffRadius.xl))),
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(StaffSpace.page, 8, StaffSpace.page, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: placeLine, borderRadius: BorderRadius.circular(99)),
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: placeInk),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: maxLines,
            autofocus: true,
            decoration: InputDecoration(hintText: hint),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('إرسال')),
          ),
        ],
      ),
    ),
  );
}

void lightTap() => HapticFeedback.selectionClick();

void strongTap() => HapticFeedback.mediumImpact();
