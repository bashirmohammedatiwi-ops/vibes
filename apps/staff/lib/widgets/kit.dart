import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// ═══════════════════════════════════════════════════════════
/// مكوّنات «VIBES مكتب» الموحّدة — كل شاشة تُبنى منها ليبقى التطبيق
/// متسقاً: رأس الصفحة، أقسام، بطاقات، مؤشرات، مهام، صفوف معلومات،
/// شارات حالة، حالات فارغة وتحميل.
/// ═══════════════════════════════════════════════════════════

/// صفحة قياسية: رأس كبير يصغر عند التمرير + محتوى + سحب للتحديث.
///
/// نمطان للرأس:
///  • «علامة» (brand) — لصفحات التبويبات الرئيسية: تدرّج كحلي بزخرفة ذهبية،
///    عنوان أبيض كبير، أزرار في دوائر زجاجية، ويبدأ المحتوى بحافة مستديرة.
///  • «فاتح» — للصفحات الفرعية: رأس أبيض نظيف، زر رجوع واضح، وخط فاصل
///    رفيع يظهر عند التمرير.
/// الافتراضي: علامة إن لم يمكن الرجوع (صفحة تبويب)، وفاتح لما عداها.
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
    this.brand,
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

  /// null = تلقائي (علامة لصفحات التبويب).
  final bool? brand;

  @override
  Widget build(BuildContext context) {
    final canPop = showBack ?? Navigator.of(context).canPop();
    final isBrand = brand ?? !canPop;
    final bottomH = bottom?.preferredSize.height ?? 0;
    final expanded = (isBrand ? 132.0 : 112.0) + (subtitle == null ? 0 : 18);
    const collapsed = 60.0;
    final fg = isBrand ? Colors.white : placeInk;

    Widget? backButton;
    if (leading != null) {
      backButton = leading;
    } else if (canPop) {
      backButton = Padding(
        padding: const EdgeInsetsDirectional.only(start: 10),
        child: Center(
          child: _HeaderButton(
            brand: isBrand,
            icon: Icons.arrow_back_rounded,
            tooltip: 'رجوع',
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
      );
    }

    final scroll = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: expanded,
          collapsedHeight: collapsed,
          toolbarHeight: collapsed,
          backgroundColor: isBrand ? placeNavy : Colors.white,
          foregroundColor: fg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          leading: backButton,
          leadingWidth: backButton == null ? 0 : 58,
          systemOverlayStyle: (isBrand ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
              .copyWith(statusBarColor: Colors.transparent),
          actionsIconTheme: IconThemeData(color: fg, size: 22),
          iconTheme: IconThemeData(color: fg),
          actions: [
            for (final a in actions)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: Center(child: _HeaderActionFrame(brand: isBrand, child: a)),
              ),
            const SizedBox(width: 8),
          ],
          bottom: bottom,
          flexibleSpace: LayoutBuilder(
            builder: (context, c) {
              final top = MediaQuery.paddingOf(context).top;
              final minH = collapsed + top + bottomH;
              final maxH = expanded + top + bottomH;
              final t = ((c.maxHeight - minH) / (maxH - minH)).clamp(0.0, 1.0);
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (isBrand) const _BrandBackdrop() else _LightBackdrop(collapsed: t < .05),
                  // العنوان الكبير — يتلاشى ويصعد قليلاً عند التمرير
                  PositionedDirectional(
                    start: StaffSpace.page + 2,
                    end: StaffSpace.page,
                    bottom: (isBrand ? 26 : 12) + bottomH,
                    child: Opacity(
                      opacity: Curves.easeOut.transform(t),
                      child: Transform.translate(
                        offset: Offset(0, 8 * (1 - t)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontFamily: 'Cairo', fontSize: isBrand ? 27 : 25, fontWeight: FontWeight.w900, color: fg, height: 1.2),
                            ),
                            if (subtitle != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isBrand ? Colors.white.withValues(alpha: .72) : placeInk2,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // العنوان الصغير — يظهر عند الطي
                  PositionedDirectional(
                    start: backButton != null ? 68 : StaffSpace.page + 2,
                    end: 52.0 * actions.length + 16,
                    top: top,
                    height: collapsed,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: (1 - t * 1.6).clamp(0.0, 1.0),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w900, color: fg),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // حافة المحتوى المستديرة تحت رأس العلامة
                  if (isBrand)
                    PositionedDirectional(
                      start: 0,
                      end: 0,
                      bottom: bottomH - 1,
                      height: 18,
                      child: Opacity(
                        opacity: t,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            color: placePaper,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(StaffRadius.xl)),
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
          : RefreshIndicator(
              color: placeGold,
              edgeOffset: MediaQuery.paddingOf(context).top + collapsed,
              onRefresh: onRefresh!,
              child: scroll,
            ),
    );
  }
}

/// خلفية رأس العلامة: تدرّج كحلي مع دوائر ذهبية خافتة.
class _BrandBackdrop extends StatelessWidget {
  const _BrandBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [Color(0xFF1E3A5C), placeNavy, Color(0xFF0C1828)],
          stops: [0, .55, 1],
        ),
      ),
      child: ClipRect(
        child: Stack(
          children: [
            PositionedDirectional(
              end: -60,
              top: -70,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [placeGold.withValues(alpha: .28), placeGold.withValues(alpha: 0)]),
                ),
              ),
            ),
            PositionedDirectional(
              end: 40,
              top: 18,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: placeGold.withValues(alpha: .14), width: 1.2),
                ),
              ),
            ),
            PositionedDirectional(
              start: -30,
              bottom: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: .05), width: 1.2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// خلفية الرأس الفاتح: بيضاء، وخط سفلي رفيع عند الطي.
class _LightBackdrop extends StatelessWidget {
  const _LightBackdrop({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: collapsed ? placeLine : Colors.transparent)),
      ),
    );
  }
}

/// زر دائري في الرأس (رجوع) — زجاجي على الكحلي، ومحدد على الأبيض.
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.brand, required this.icon, required this.onTap, this.tooltip});

  final bool brand;
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final box = Material(
      color: brand ? Colors.white.withValues(alpha: .12) : placePaper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(color: brand ? Colors.white.withValues(alpha: .16) : placeLine),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 21, color: brand ? Colors.white : placeInk),
        ),
      ),
    );
    return tooltip == null ? box : Tooltip(message: tooltip!, child: box);
  }
}

/// إطار موحّد لأزرار الإجراءات في الرأس (الأيقونات فقط تُؤطَّر).
class _HeaderActionFrame extends StatelessWidget {
  const _HeaderActionFrame({required this.brand, required this.child});

  final bool brand;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (child is! IconButton) return child;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: brand ? Colors.white.withValues(alpha: .12) : placePaper,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: brand ? Colors.white.withValues(alpha: .16) : placeLine),
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: brand ? Colors.white : placeInk, size: 21),
        child: Center(child: child),
      ),
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
