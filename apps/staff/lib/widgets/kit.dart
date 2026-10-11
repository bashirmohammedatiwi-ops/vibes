import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// ═══════════════════════════════════════════════════════════
/// مكوّنات «VIBES مكتب» الموحّدة — كل شاشة تُبنى منها ليبقى التطبيق
/// متسقاً: رأس الصفحة، أقسام، بطاقات، مؤشرات، مهام، صفوف معلومات،
/// شارات حالة، حالات فارغة وتحميل.
/// ═══════════════════════════════════════════════════════════

/// صفحة قياسية: رأس كبير يصغر عند التمرير + محتوى + سحب للتحديث.
class StaffPage extends StatelessWidget {
  const StaffPage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.slivers,
    this.onRefresh,
    this.floatingActionButton,
    this.leading,
    this.showBack,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final List<Widget> slivers;
  final Future<void> Function()? onRefresh;
  final Widget? floatingActionButton;
  final Widget? leading;

  /// null = تلقائي (يظهر زر الرجوع إن أمكن الرجوع).
  final bool? showBack;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) {
    final canPop = showBack ?? Navigator.of(context).canPop();
    final scroll = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: subtitle == null ? 108 : 124,
          collapsedHeight: 60,
          automaticallyImplyLeading: canPop,
          leading: leading,
          actions: [...actions, const SizedBox(width: 8)],
          bottom: bottom,
          flexibleSpace: LayoutBuilder(
            builder: (context, c) {
              final top = MediaQuery.paddingOf(context).top;
              final minH = 60 + top + (bottom?.preferredSize.height ?? 0);
              final maxH = (subtitle == null ? 108 : 124) + top + (bottom?.preferredSize.height ?? 0);
              final t = ((c.maxHeight - minH) / (maxH - minH)).clamp(0.0, 1.0);
              return Stack(
                children: [
                  // العنوان الكبير — يتلاشى عند التمرير
                  PositionedDirectional(
                    start: StaffSpace.page,
                    end: StaffSpace.page,
                    bottom: 10 + (bottom?.preferredSize.height ?? 0),
                    child: Opacity(
                      opacity: t,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 26, fontWeight: FontWeight.w900, color: placeInk, height: 1.2),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600, color: placeInk2),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // العنوان الصغير — يظهر عند الطي
                  PositionedDirectional(
                    start: canPop || leading != null ? 56 : StaffSpace.page,
                    end: 56.0 * actions.length + 16,
                    top: top,
                    height: 60,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 1 - t,
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: placeInk),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        ...slivers,
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: onRefresh == null
          ? scroll
          : RefreshIndicator(color: placeGold, onRefresh: onRefresh!, child: scroll),
    );
  }
}

/// غلاف حشوة موحّد لعناصر الصفحة داخل slivers.
class Pad extends StatelessWidget {
  const Pad({super.key, required this.child, this.top = 0, this.bottom = StaffSpace.gap});

  final Widget child;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(StaffSpace.page, top, StaffSpace.page, bottom),
        child: child,
      );
}

/// عنوان قسم: نص عريض + وصف اختياري + إجراء على الطرف.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.actionLabel, this.onAction, this.count});

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(StaffSpace.page, 18, StaffSpace.page, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 16.5, fontWeight: FontWeight.w900, color: placeInk)),
                    if (count != null && count! > 0) ...[
                      const SizedBox(width: 8),
                      CountBadge(count!),
                    ],
                  ],
                ),
                if (subtitle != null)
                  Text(subtitle!, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600, color: placeInk2)),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// بطاقة بيضاء موحّدة (حدود رفيعة، زوايا 20) قابلة للضغط.
class StaffCard extends StatelessWidget {
  const StaffCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.color = Colors.white,
    this.borderColor = placeLine,
    this.radius = StaffRadius.lg,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return Material(
      color: color,
      borderRadius: r,
      child: InkWell(
        borderRadius: r,
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: Ink(
          decoration: BoxDecoration(borderRadius: r, border: Border.all(color: borderColor)),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// مؤشر رقمي: أيقونة في مربع ملوّن، رقم كبير، وعنوان.
class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = placeInk,
    this.onTap,
    this.alert = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return StaffCard(
      onTap: onTap,
      color: alert ? color.withValues(alpha: .06) : Colors.white,
      borderColor: alert ? color.withValues(alpha: .35) : placeLine,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBox(icon: icon, color: color, size: 34),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontFamily: 'Montserrat', fontSize: 22, fontWeight: FontWeight.w800, color: alert ? color : placeInk, height: 1.1)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: placeInk2)),
        ],
      ),
    );
  }
}

/// مربع أيقونة ملوّن خفيف.
class IconBox extends StatelessWidget {
  const IconBox({super.key, required this.icon, this.color = placeInk, this.size = 40, this.filled = false});

  final IconData icon;
  final Color color;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(size * .32),
      ),
      child: Icon(icon, size: size * .55, color: filled ? Colors.white : color),
    );
  }
}

/// صف مهمة/تنقل: أيقونة، عنوان ووصف، وعدّاد أو سهم.
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.color = placeInk,
    this.count,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final int? count;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            IconBox(icon: icon, color: color, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14.5, fontWeight: FontWeight.w800, color: placeInk)),
                  if (subtitle != null)
                    Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600, color: placeInk2)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                (count != null && count! > 0
                    ? CountBadge(count!, color: color == placeInk ? placeDanger : color)
                    : const Icon(Icons.chevron_left_rounded, color: placeInk3)),
          ],
        ),
      ),
    );
  }
}

/// مجموعة صفوف داخل بطاقة واحدة مع فواصل.
class TileGroup extends StatelessWidget {
  const TileGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(const Divider(height: 1, indent: 66));
      items.add(children[i]);
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(StaffRadius.lg),
        border: Border.all(color: placeLine),
      ),
      child: Material(color: Colors.white, child: Column(children: items)),
    );
  }
}

/// عدّاد صغير دائري.
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key, this.color = placeDanger});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(fontFamily: 'Montserrat', fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white, height: 1),
      ),
    );
  }
}

/// شارة حالة ملوّنة (نقطة + نص).
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, required this.color, this.dense = false});

  final String label;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: dense ? 11 : 12, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

/// صف معلومة: عنوان صغير وقيمة.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value, this.icon, this.valueColor, this.onTap});

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 18, color: placeInk3), const SizedBox(width: 10)],
            Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600, color: placeInk2)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13.5, fontWeight: FontWeight.w800, color: valueColor ?? placeInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// صورة رمزية بالحرف الأول.
class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.size = 44, this.color = placeNavyHigh});

  final String name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '؟' : name.trim().characters.first;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: .1), shape: BoxShape.circle),
      child: Text(letter, style: TextStyle(fontFamily: 'Cairo', fontSize: size * .42, fontWeight: FontWeight.w900, color: color, height: 1.2)),
    );
  }
}

/// زر بحث بشكل حقل — يفتح شاشة البحث.
class SearchLauncher extends StatelessWidget {
  const SearchLauncher({super.key, required this.hint, required this.onTap});

  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StaffCard(
      onTap: onTap,
      radius: StaffRadius.md,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: placeInk2),
          const SizedBox(width: 10),
          Expanded(child: Text(hint, style: const TextStyle(fontFamily: 'Cairo', color: placeInk3, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

/// بلاطة إجراء سريع (أيقونة فوق نص).
class QuickAction extends StatelessWidget {
  const QuickAction({super.key, required this.icon, required this.label, required this.onTap, this.color = placeInk, this.badge = 0});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return StaffCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Badge(
            isLabelVisible: badge > 0,
            label: Text('$badge'),
            child: IconBox(icon: icon, color: color, size: 42),
          ),
          const SizedBox(height: 8),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w800, color: placeInk)),
        ],
      ),
    );
  }
}

/// حالة فارغة موحّدة.
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.title, this.subtitle, this.actionLabel, this.onAction});

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: placeGoldSoft, shape: BoxShape.circle),
            child: Icon(icon, size: 34, color: placeBrass),
          ),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo', fontSize: 16.5, fontWeight: FontWeight.w900, color: placeInk)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: placeInk2, height: 1.5)),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// هيكل تحميل (مستطيلات رمادية نابضة بلطف).
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.height = 72, this.radius = StaffRadius.lg, this.width});

  final double height;
  final double radius;
  final double? width;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: .55, end: 1.0).animate(_c),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: placeLineSoft, borderRadius: BorderRadius.circular(widget.radius)),
      ),
    );
  }
}

/// قائمة هياكل تحميل جاهزة كـ sliver.
class SkeletonSliver extends StatelessWidget {
  const SkeletonSliver({super.key, this.count = 5, this.height = 76});

  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SliverList.separated(
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Pad(bottom: 0, child: SkeletonBox(height: height)),
    );
  }
}

/// نافذة سفلية موحّدة بعنوان.
Future<T?> showStaffSheet<T>(BuildContext context, {required String title, required Widget child}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(StaffSpace.page, 0, StaffSpace.page, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900, color: placeInk)),
          const SizedBox(height: 12),
          Flexible(child: child),
        ],
      ),
    ),
  );
}
