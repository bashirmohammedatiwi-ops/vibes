import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../auth/auth_controller.dart';

/// ═══════════════════════════════════════════════════════════
/// الملف الشخصي — بياناتي، لغة، مظهر، مفضلة، دعم، خروج
/// ═══════════════════════════════════════════════════════════

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final prefs = ref.watch(prefsControllerProvider);
    final favorites = ref.watch(favoritesProvider);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('ملفي')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // بطاقة الهوية
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: GoldColors.gradient,
                ),
                child: Icon(
                  Icons.person_rounded,
                  size: 32,
                  color: GoldColors.onGold,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? 'ضيف VIBES',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        user?.phone ?? '',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: VibesTheme.textTertiaryOf(context),
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ).animate().fadeIn(),
          const SizedBox(height: 24),

          // المفضلة
          _MenuCard(
            icon: Icons.favorite_outline_rounded,
            label: 'المفضلة',
            trailing: Text(
              '${favorites.value?.length ?? 0}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: GoldColors.gold,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            onTap: () => context.push('/favorites'),
          ),
          const SizedBox(height: 12),

          // المظهر
          _MenuCard(
            icon: prefs.darkMode
                ? Icons.dark_mode_outlined
                : Icons.light_mode_outlined,
            label: 'المظهر',
            trailing: _ToggleMini(
              value: prefs.darkMode,
              onChanged: (v) => ref
                  .read(prefsControllerProvider.notifier)
                  .setDarkMode(v),
            ),
          ),
          const SizedBox(height: 12),

          // اللغة
          _MenuCard(
            icon: Icons.language_rounded,
            label: 'اللغة',
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'ar', label: Text('عربي')),
                ButtonSegment(value: 'en', label: Text('EN')),
              ],
              selected: {prefs.localeCode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                final code = selection.first;
                ref.read(prefsControllerProvider.notifier).setLocale(code);
                if (context.mounted) {
                  // easy_localization تبديل فوري
                  // (نكتفي بالحفظ — يسري بإعادة التشغيل)
                }
              },
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                backgroundColor: WidgetStatePropertyAll(Colors.transparent),
                foregroundColor:
                    WidgetStatePropertyAll(VibesThemeStatic.muted),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // الدعم
          _MenuCard(
            icon: Icons.support_agent_rounded,
            label: 'الدعم عبر واتساب',
            trailing: Icon(
              Icons.chevron_left_rounded,
              color: VibesTheme.textTertiaryOf(context),
            ),
            onTap: () async {
              final uri = Uri.parse('https://wa.me/9647700000000');
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
          ),
          const SizedBox(height: 12),

          _MenuCard(
            icon: Icons.info_outline_rounded,
            label: 'عن VIBES',
            trailing: Text(
              '1.0.0',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: VibesTheme.textTertiaryOf(context),
                  ),
            ),
          ),
          const SizedBox(height: 28),

          // خروج
          SizedBox(
            width: double.infinity,
            child: VibesButton(
              label: 'تسجيل الخروج',
              ghost: true,
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return VibesCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: GoldColors.gold),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _ToggleMini extends StatelessWidget {
  const _ToggleMini({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeColor: GoldColors.gold,
    );
  }
}
