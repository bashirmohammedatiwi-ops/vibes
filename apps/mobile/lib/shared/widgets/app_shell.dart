import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../features/compare/compare_feature.dart';

/// ═══════════════════════════════════════════════════════════
/// قشرة الزبون — 4 تبويبات أنيقة بحالة محفوظة
/// ═══════════════════════════════════════════════════════════

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CompareBar(),
          NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: (i) => shell.goBranch(
              i,
              initialLocation: i == shell.currentIndex,
            ),
            destinations: [
              _dest(
                context,
                active: Icons.home_rounded,
                inactive: Icons.home_outlined,
                label: 'الرئيسية',
              ),
              _dest(
                context,
                active: Icons.play_circle_rounded,
                inactive: Icons.play_circle_outline_rounded,
                label: 'الاستكشاف',
              ),
              _dest(
                context,
                active: Icons.calendar_month_rounded,
                inactive: Icons.calendar_month_outlined,
                label: 'حجوزاتي',
              ),
              _dest(
                context,
                active: Icons.person_rounded,
                inactive: Icons.person_outline_rounded,
                label: 'ملفي',
              ),
            ],
          ),
        ],
      ),
    );
  }

  NavigationDestination _dest(
    BuildContext context, {
    required IconData active,
    required IconData inactive,
    required String label,
  }) {
    return NavigationDestination(
      icon: Icon(inactive, size: 24),
      selectedIcon: Icon(
        active,
        size: 26,
        color: GoldColors.gold,
      ),
      label: label,
    );
  }
}
