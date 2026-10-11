import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../features/compare/compare_feature.dart';
import '../../core/theme/world_theme.dart';
import 'maison_shapes.dart';
import 'experience_mode_switcher.dart';
import '../../core/app_mode/app_mode_controller.dart';

/// ═══════════════════════════════════════════════════════════
/// هيكل التطبيق — دوك VIBEES العائم:
/// كبسولة زجاجية تطفو فوق المحتوى، جوهرة استكشاف مركزية تتوهج
/// بلون العالم وتتنفس، أيقونات تنبثق بفيزياء spring مرنة،
/// ومؤشر نحاسي يزحف تحت التبويب النشط بانسيابية emphasized.
/// ═══════════════════════════════════════════════════════════
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// فهرس الفرع لكل تبويب — الاستكشاف جوهرة المنتصف (فرع 1)
  static const _slots = [
    (Icons.home_rounded, 'الرئيسية', 0),
    (Icons.calendar_month_rounded, 'حجوزاتي', 2),
    (null, 'استكشف', 1),
    (Icons.auto_awesome_rounded, 'نديم', -1),
    (Icons.person_rounded, 'ملفي', 3),
  ];

  static String _routeOf(int branch) => switch (branch) {
    0 => '/home',
    1 => '/explore',
    2 => '/bookings',
    _ => '/profile',
  };

  void _go(int branch, int current) {
    HapticFeedback.selectionClick();
    final nadeemActive = GoRouterState.of(context).uri.path == '/nadeem';
    if (branch == -1) {
      context.push('/nadeem');
      return;
    }
    if (nadeemActive) {
      context.go(_routeOf(branch));
    } else {
      widget.shell.goBranch(branch, initialLocation: branch == current);
    }
    final container = ProviderScope.containerOf(context);
    container
        .read(appModeProvider.notifier)
        .rememberGuestPath(_routeOf(branch));
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.shell.currentIndex;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: PopScope(
        // الرجوع من أي فرع غير الرئيسية يعيد إليها بدل إنهاء التطبيق —
        // الخروج لا يكون إلا من الرئيسية نفسها (سلوك Google الرسمي).
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (widget.shell.currentIndex != 0) {
            HapticFeedback.selectionClick();
            widget.shell.goBranch(0);
          }
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          body: widget.shell,
          extendBody: current != 1,
          bottomNavigationBar: current == 1
              ? null
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ExperienceModeSwitcherBar(inProviderPortal: false),
                    const CompareBar(),
                    _GlassDock(current: current, onSelect: _go),
                  ],
                ),
        ),
      ),
    );
  }
}

/// ═════ الدوك الزجاجي ═════
/// كبسولة blur عائمة بحافة علوية مضاءة — يمر المحتوى تحتها
/// ويتشوش بلطف، والتبويب النشط يلتقط لون عالمه.
class _GlassDock extends ConsumerWidget {
  const _GlassDock({required this.current, required this.onSelect});

  final int current;
  final void Function(int branch, int current) onSelect;

  static const _slots = _AppShellState._slots;

  bool _slotActive(BuildContext context, {required int branch}) {
    final onNadeem = GoRouterState.of(context).uri.path == '/nadeem';
    if (branch == -1) return onNadeem;
    return !onNadeem && current == branch;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // لون العالم من الثيم المتحرك — يتبدّل بانسياب مع تبديل العالم
    // في كل التبويبات، لا الرئيسية وحدها.
    final world = context.world;
    final dockAccent = world.accent;
    final dockDeep = world.accentDeep;
    final dockOn = world.onAccent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 66,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x1A0F2138),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: dockAccent.withValues(alpha: 0.10),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Row(
              children: [
                for (var i = 0; i < _slots.length; i++)
                  Expanded(
                    child: _DockItem(
                      icon: _slots[i].$1,
                      label: _slots[i].$2,
                      branch: _slots[i].$3,
                      active: _slotActive(context, branch: _slots[i].$3),
                      accent: dockAccent,
                      accentDeep: dockDeep,
                      onAccent: dockOn,
                      isJewel: _slots[i].$3 == 1,
                      onTap: () => onSelect(_slots[i].$3, current),
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

/// تبويب دوك — أيقونة تنبثق بspring عند التفعيل، والجوهرة
/// المركزية (استكشف) تتوهج وتتنفس بلون العالم.
class _DockItem extends StatefulWidget {
  const _DockItem({
    required this.icon,
    required this.label,
    required this.branch,
    required this.active,
    required this.accent,
    required this.accentDeep,
    required this.onAccent,
    required this.isJewel,
    required this.onTap,
  });

  final IconData? icon;
  final String label;
  final int branch;
  final bool active;
  final Color accent;
  final Color accentDeep;
  final Color onAccent;
  final bool isJewel;
  final VoidCallback onTap;

  @override
  State<_DockItem> createState() => _DockItemState();
}

class _DockItemState extends State<_DockItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  late final Animation<double> _scale = Tween(
    begin: 0.72,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _spring, curve: Curves.elasticOut));

  @override
  void initState() {
    super.initState();
    if (widget.active) _spring.value = 1;
  }

  @override
  void didUpdateWidget(covariant _DockItem old) {
    super.didUpdateWidget(old);
    // نبضة spring عند التفعيل فقط — بلا كثرة عند الخمول.
    if (widget.active && !old.active) {
      _spring.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final scale = reduce ? 1.0 : _scale.value;

    Widget iconPart;
    if (widget.isJewel) {
      // ── جوهرة الاستكشاف — كرة نحاسية متوهجة تتنفس ──
      iconPart = _ExploreJewel(
        accent: widget.accent,
        onAccent: widget.onAccent,
      );
    } else {
      iconPart = ScaleTransition(
        scale: reduce ? const AlwaysStoppedAnimation(1.0) : _scale,
        child: AnimatedContainer(
          duration: VibesMotion.base,
          curve: VibesMotion.curve,
          width: 48,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.active ? widget.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: widget.active
                ? [
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            widget.icon,
            size: 21,
            color: widget.active ? widget.onAccent : Vibes.inkSecondary,
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      selected: widget.active,
      label: widget.label,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.scale(scale: scale.clamp(0.72, 1.0), child: iconPart),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: VibesMotion.fast,
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                fontSize: 10.5,
                fontWeight: widget.active ? FontWeight.w800 : FontWeight.w600,
                color: widget.active ? widget.accentDeep : Vibes.inkSecondary,
                height: 1.05,
              ),
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// جوهرة الاستكشاف — قرص نحاسي متدرج بحافة مضاءة، يتنفس
/// بتوهج نابض دائم بلون العالم، ويحمل شعار الدار.
class _ExploreJewel extends StatefulWidget {
  const _ExploreJewel({required this.accent, required this.onAccent});

  final Color accent;
  final Color onAccent;

  @override
  State<_ExploreJewel> createState() => _ExploreJewelState();
}

class _ExploreJewelState extends State<_ExploreJewel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      return _jewelBody(const AlwaysStoppedAnimation(0.5));
    }
    return AnimatedBuilder(
      animation: _breath,
      builder: (context, _) => _jewelBody(_breath),
    );
  }

  Widget _jewelBody(Animation<double> t) {
    // الشعار نفسه بلون العالم — بلا دائرة أو إطار، يتنفّس بلطف
    return Transform.scale(
      scale: 1 + t.value * .06,
      child: VibesLogo.mark(size: 30, color: widget.accent),
    );
  }
}
