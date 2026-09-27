import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

export 'provider_screens.dart';
export 'provider_screens2.dart';

class ProviderShell extends StatelessWidget {
  const ProviderShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _tabs = [
    (Icons.space_dashboard_rounded, Icons.space_dashboard_outlined, 'لوحتي'),
    (Icons.calendar_month_rounded, Icons.calendar_month_outlined, 'الحجوزات'),
    (Icons.event_busy_rounded, Icons.event_busy_outlined, 'التقويم'),
    (Icons.home_work_rounded, Icons.home_work_outlined, 'ممتلكاتي'),
  ];

  @override
  Widget build(BuildContext context) {
    final current = shell.currentIndex;

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
      backgroundColor: VibesTheme.canvasOf(context),
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: VibesTheme.canvasOf(context),
          boxShadow: dark
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
                height: 64,
                child: Row(
                  children: [
                    for (var i = 0; i < _tabs.length; i++)
                      Expanded(
                        child: _OwnerTab(
                          filled: _tabs[i].$1,
                          outlined: _tabs[i].$2,
                          label: _tabs[i].$3,
                          active: i == current,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            shell.goBranch(i, initialLocation: i == current);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _OwnerTab extends StatelessWidget {
  const _OwnerTab({
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
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: color,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
