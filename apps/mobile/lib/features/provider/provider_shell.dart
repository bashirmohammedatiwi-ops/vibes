import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/world_theme.dart';
import 'provider_data.dart';
import '../../shared/widgets/experience_mode_switcher.dart';

export 'provider_screens.dart';
export 'provider_screens2.dart';

class ProviderShell extends ConsumerWidget {
  const ProviderShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _tabs = [
    (
      Icons.space_dashboard_rounded,
      Icons.space_dashboard_outlined,
      'لوحتي', // i18n-ok
    ),
    (
      Icons.calendar_month_rounded,
      Icons.calendar_month_outlined,
      'الحجوزات', // i18n-ok
    ),
    (Icons.event_busy_rounded, Icons.event_busy_outlined, 'التقويم'), // i18n-ok
    (Icons.home_work_rounded, Icons.home_work_outlined, 'ممتلكاتي'), // i18n-ok
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = shell.currentIndex;
    final pending =
        ref.watch(providerOverviewProvider).valueOrNull?.pendingBookings ?? 0;

    final dark = VibesTheme.isDark(context);
    final p = WorldPalette.owner;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Theme(
      data: applyWorld(Theme.of(context), p),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: dark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: p.canvas,
          systemNavigationBarIconBrightness: dark
              ? Brightness.light
              : Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: p.canvas,
          extendBody: false,
          body: shell,
          bottomNavigationBar: Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 10 + bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ExperienceModeSwitcherBar(inProviderPortal: true),
                const SizedBox(height: 6),
                Container(
                  height: 68,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: Vibes.surface,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: themed(const Color(0xFFEDEEF1), Vibes.hairline),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: p.night.withValues(alpha: .12),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < _tabs.length; i++)
                        Expanded(
                          child: _OwnerTab(
                            filled: _tabs[i].$1,
                            outlined: _tabs[i].$2,
                            label: _tabs[i].$3.tr,
                            active: i == current,
                            badge: i == 1 ? pending : null,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              shell.goBranch(i, initialLocation: i == current);
                            },
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
    );
  }
}

Color get _inactive => themed(const Color(0xFF7C8594), Vibes.inkTertiary);

class _OwnerTab extends StatelessWidget {
  const _OwnerTab({
    required this.filled,
    required this.outlined,
    required this.label,
    required this.active,
    required this.onTap,
    this.badge,
  });

  final IconData filled;
  final IconData outlined;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final p = WorldPalette.owner;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  width: active ? 52 : 40,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: active
                        ? LinearGradient(colors: [p.nightHigh, p.night])
                        : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    active ? filled : outlined,
                    size: 21,
                    color: active ? p.accentLight : _inactive,
                  ),
                ),
                if (badge != null && badge! > 0)
                  Positioned(
                    top: -4,
                    right: -2,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 17),
                      height: 17,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: p.fill,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Vibes.surface, width: 1.5),
                      ),
                      child: Text(
                        badge! > 9 ? '9+' : '$badge',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: p.onAccent,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 260),
              style: TextStyle(
                fontFamily: VibesFont.ui,
                fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                color: active ? themed(p.night, p.accentLight) : _inactive,
                fontSize: 11,
                height: 1.1,
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
