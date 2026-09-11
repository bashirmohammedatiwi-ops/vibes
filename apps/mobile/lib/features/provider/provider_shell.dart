import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

export 'provider_screens.dart';
export 'provider_screens2.dart';

/// ═══════════════════════════════════════════════════════════
/// قشرة المزوّد — حبر أعمق ولمسات ذهبية أوضح (تمييز هوية المالك)
/// ═══════════════════════════════════════════════════════════

class ProviderShell extends StatelessWidget {
  const ProviderShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12), // حبر أعمق للمزوّد
      extendBody: true,
      body: shell,
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xF012141A),
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(
          i,
          initialLocation: i == shell.currentIndex,
        ),
        destinations: [
          _dest(Icons.space_dashboard_rounded, Icons.space_dashboard_outlined,
              'لوحتي'),
          _dest(Icons.calendar_month_rounded,
              Icons.calendar_month_outlined, 'الحجوزات'),
          _dest(Icons.event_busy_rounded, Icons.event_busy_outlined, 'التقويم'),
          _dest(Icons.home_work_rounded, Icons.home_work_outlined, 'ممتلكاتي'),
        ],
      ),
    );
  }

  NavigationDestination _dest(IconData active, IconData inactive, String label) {
    return NavigationDestination(
      icon: Icon(inactive, size: 24),
      selectedIcon: Icon(active, size: 26, color: GoldColors.gold),
      label: label,
    );
  }
}
