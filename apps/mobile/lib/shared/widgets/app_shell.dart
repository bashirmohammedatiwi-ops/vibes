import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../features/compare/compare_feature.dart';
import 'maison_shapes.dart';

/// هيكل التطبيق — قاعدة ورقية هادئة بعرض الشاشة، بلا لوح ليلي ثقيل
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _tabs = [
    (Icons.home_rounded, Icons.home_outlined, 'الرئيسية'),
    (Icons.play_circle_rounded, Icons.play_circle_outline_rounded, 'استكشف'),
    (Icons.calendar_month_rounded, Icons.calendar_today_outlined, 'حجوزاتي'),
    (Icons.person_rounded, Icons.person_outline_rounded, 'ملفي'),
  ];

  static const _tabRoutes = ['/home', '/explore', '/bookings', '/profile'];

  @override
  Widget build(BuildContext context) {
    final current = widget.shell.currentIndex;
    final path = GoRouterState.of(context).uri.path;
    final nadeemActive = path == '/nadeem';

    final dark = VibesTheme.isDark(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: VibesTheme.canvasOf(context),
        systemNavigationBarIconBrightness: dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
      body: widget.shell,
      bottomNavigationBar: Material(
        color: Colors.transparent,
        clipBehavior: Clip.none,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CompareBar(),
            _PaperPlinth(
              currentIndex: current,
              tabs: _tabs,
              nadeemActive: nadeemActive,
              onNadeem: () {
                HapticFeedback.mediumImpact();
                if (!nadeemActive) context.push('/nadeem');
              },
              onTap: (i) {
                HapticFeedback.selectionClick();
                if (nadeemActive) {
                  context.go(_tabRoutes[i]);
                } else {
                  widget.shell.goBranch(i, initialLocation: i == current);
                }
              },
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _PaperPlinth extends StatelessWidget {
  const _PaperPlinth({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
    required this.onNadeem,
    required this.nadeemActive,
  });

  final int currentIndex;
  final List<(IconData, IconData, String)> tabs;
  final ValueChanged<int> onTap;
  final VoidCallback onNadeem;
  final bool nadeemActive;

  Widget _side(int index) {
    return Expanded(
      child: SizedBox(
        height: 54,
        child: _PlinthTab(
          filled: tabs[index].$1,
          outlined: tabs[index].$2,
          label: tabs[index].$3,
          active: !nadeemActive && currentIndex == index,
          onTap: () => onTap(index),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: VibesTheme.canvasOf(context),
        boxShadow: VibesTheme.isDark(context)
            ? VibesDark.floating
            : const [
                BoxShadow(
                  color: Color(0x141B3857),
                  blurRadius: 24,
                  offset: Offset(0, -8),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ColoredBox(
            color: Vibes.teal,
            child: SizedBox(height: 1.5, width: double.infinity),
          ),
          SafeArea(
            top: false,
            child: SizedBox(
              height: 62,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _side(0),
                  _side(2),
                  _ExploreDock(
                    active: !nadeemActive && currentIndex == 1,
                    onTap: () => onTap(1),
                  ),
                  _NadeemTab(active: nadeemActive, onTap: onNadeem),
                  _side(3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreDock extends StatelessWidget {
  const _ExploreDock({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'استكشف',
      selected: active,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 76,
          height: 62,
          child: Align(
            alignment: Alignment.topCenter,
            child: Transform.translate(
              offset: const Offset(0, -14),
              child: FolioPanel(
                color: VibesDark.canvas,
                borderColor: active
                    ? Vibes.tealBright
                    : Vibes.teal.withValues(alpha: .55),
                radius: Folio.chrome,
                shadows: VibesTheme.floatOf(context),
                child: SizedBox(
                  width: 62,
                  height: 58,
                  child: Column(
                    children: [
                      const SizedBox(
                        height: 2,
                        width: double.infinity,
                        child: ColoredBox(color: Vibes.teal),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const VibesLogo.mark(size: 18),
                            const SizedBox(height: 3),
                            Text(
                              'استكشف',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Vibes.tealBright,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                    height: 1,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NadeemTab extends StatelessWidget {
  const _NadeemTab({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 54,
        child: _PlinthTab(
          filled: Icons.auto_awesome_rounded,
          outlined: Icons.auto_awesome_outlined,
          label: 'نديم',
          active: active,
          onTap: onTap,
        ),
      ),
    );
  }
}

class _PlinthTab extends StatelessWidget {
  const _PlinthTab({
    required this.filled,
    required this.outlined,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData filled;
  final IconData outlined;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? (VibesTheme.isDark(context) ? Vibes.tealBright : Vibes.coral)
        : VibesTheme.textTertiaryOf(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: VibesMotion.fast,
            height: 2,
            width: active ? 18 : 0,
            color: Vibes.teal,
          ),
          const SizedBox(height: 6),
          Icon(active ? filled : outlined, size: 22, color: color),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: VibesMotion.fast,
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: color,
              fontSize: 11,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
