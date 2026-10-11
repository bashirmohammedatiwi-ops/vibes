import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/shift.dart';
import '../core/theme.dart';

class MaisonHeader extends StatelessWidget {
  const MaisonHeader({super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: placeInk)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: placeInk2)),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.accent});

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: placeLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: placeInk2)),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: accent ?? placeInk,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShiftBadge extends StatelessWidget {
  const ShiftBadge({super.key, required this.shift});

  final String? shift;

  @override
  Widget build(BuildContext context) {
    final color = shiftColor(shift);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        shiftLabel(shift),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

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
        decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 6)]),
      ),
    );
  }
}

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (final item in options)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                label: Text(labelBuilder?.call(item) ?? item),
                selected: selected == item,
                onSelected: (_) => onSelected(item),
                selectedColor: placeInk,
                labelStyle: TextStyle(
                  color: selected == item ? Colors.white : placeInk,
                  fontWeight: FontWeight.w600,
                ),
                side: const BorderSide(color: placeLine),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
        ],
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

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: placeInk2.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: placeInk2)),
            ],
          ],
        ),
      ),
    );
  }
}

Future<String?> promptText(BuildContext context, {required String title, String hint = '', int maxLines = 3}) async {
  final controller = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(controller: controller, maxLines: maxLines, decoration: InputDecoration(hintText: hint)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('إرسال'),
          ),
        ],
      ),
    ),
  );
}

void lightTap() => HapticFeedback.selectionClick();

void strongTap() => HapticFeedback.mediumImpact();
