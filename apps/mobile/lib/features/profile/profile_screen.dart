import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/data/marketplace_providers.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../auth/auth_controller.dart';
import '../booking/booking_providers.dart';

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

    if (!auth.loggedIn) return const _GuestProfile();

    return Scaffold(
      body: MaisonWash(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const MaisonPageHeader(
              title: 'ملفي',
              kicker: 'العضوية',
              safe: true,
            ),
            const SizedBox(height: 8),
            FolioPanel(
              color: Vibes.coral,
              borderColor: Vibes.teal.withValues(alpha: .4),
              shadows: Vibes.floating,
              railColor: Vibes.teal,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(gradient: Vibes.coralFill),
                child: Row(
                  children: [
                    FolioPanel(
                      color: Vibes.canvas,
                      borderColor: Vibes.teal.withValues(alpha: .5),
                      clip: true,
                      child: const SizedBox(
                        width: 72,
                        height: 72,
                        child: Center(child: VibesLogo.mark(size: 40)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'عضوية VIBEES',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: const Color(0xCCFAF7F0),
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  user?.name ?? 'ضيف VIBEES',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: Vibes.canvas,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'تعديل الاسم',
                                onPressed: () =>
                                    _editName(context, ref, user?.name),
                                icon: const Icon(
                                  Icons.edit_rounded,
                                  size: 18,
                                  color: Vibes.canvas,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 28,
                            height: 2,
                            color: Vibes.tealBright,
                          ),
                          const SizedBox(height: 6),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              user?.phone ?? '',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: const Color(0xB8FAF7F0),
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(),
            const SizedBox(height: 24),

            // صف الإحصاءات — بطاقة أفقية أنيقة
            Row(
              children: [
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final bookings = ref.watch(myBookingsProvider);
                      return _StatTile(
                        icon: Icons.calendar_month_rounded,
                        value: '${bookings.valueOrNull?.length ?? 0}',
                        label: 'حجوزات',
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final favs = ref.watch(favoritesProvider);
                      return _StatTile(
                        icon: Icons.favorite_rounded,
                        value: '${favs.valueOrNull?.length ?? 0}',
                        label: 'مفضلة',
                        honey: true,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const MaisonKicker('حسابك'),
            const SizedBox(height: 10),
            MaisonMenuGroup(
              children: [
                MaisonMenuRow(
                  icon: Icons.notifications_none_rounded,
                  label: 'الإشعارات',
                  trailing: Consumer(
                    builder: (context, ref, _) {
                      final unread =
                          ref.watch(notificationsUnreadProvider).valueOrNull ??
                          0;
                      if (unread <= 0) return _chevron(context);
                      return _CountMark('$unread');
                    },
                  ),
                  onTap: () => context.push('/notifications'),
                ),
                MaisonMenuRow(
                  icon: Icons.forum_outlined,
                  label: 'الرسائل',
                  trailing: Consumer(
                    builder: (context, ref, _) {
                      final unread =
                          ref.watch(conversationsUnreadProvider).valueOrNull ??
                          0;
                      if (unread <= 0) return _chevron(context);
                      return _CountMark('$unread');
                    },
                  ),
                  onTap: () => context.push('/conversations'),
                ),
                MaisonMenuRow(
                  icon: Icons.receipt_long_outlined,
                  label: 'الفواتير',
                  onTap: () => context.push('/invoices'),
                ),
                MaisonMenuRow(
                  icon: Icons.favorite_outline_rounded,
                  label: 'المفضلة والقوائم',
                  trailing: _CountMark('${favorites.valueOrNull?.length ?? 0}'),
                  onTap: () => context.push('/favorites'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const MaisonKicker('اكتشف'),
            const SizedBox(height: 10),
            MaisonMenuGroup(
              children: [
                MaisonMenuRow(
                  icon: Icons.local_offer_outlined,
                  label: 'العروض الخاصة',
                  onTap: () => context.push('/offers'),
                ),
                MaisonMenuRow(
                  icon: Icons.confirmation_number_outlined,
                  label: 'كوبونات الخصم',
                  onTap: () => context.push('/coupons'),
                ),
                MaisonMenuRow(
                  icon: Icons.auto_awesome_outlined,
                  label: 'تجارب الضيوف',
                  onTap: () => context.push('/experiences'),
                ),
                MaisonMenuRow(
                  icon: Icons.person_add_alt_1_outlined,
                  label: 'أتابعهم',
                  trailing: Consumer(
                    builder: (context, ref, _) {
                      final count =
                          ref
                              .watch(followingProvidersProvider)
                              .valueOrNull
                              ?.length ??
                          0;
                      if (count <= 0) return _chevron(context);
                      return _CountMark('$count');
                    },
                  ),
                  onTap: () => context.push('/following'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const MaisonKicker('التفضيلات'),
            const SizedBox(height: 10),
            MaisonMenuGroup(
              children: [
                MaisonMenuRow(
                  icon: prefs.darkMode
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                  label: 'المظهر الداكن',
                  trailing: _ToggleMini(
                    value: prefs.darkMode,
                    onChanged: (v) => ref
                        .read(prefsControllerProvider.notifier)
                        .setDarkMode(v),
                  ),
                ),
                MaisonMenuRow(
                  icon: Icons.data_saver_on_outlined,
                  label: 'توفير البيانات',
                  trailing: _ToggleMini(
                    value: prefs.dataSaver,
                    onChanged: (v) => ref
                        .read(prefsControllerProvider.notifier)
                        .setDataSaver(v),
                  ),
                ),
                MaisonMenuRow(
                  icon: Icons.language_rounded,
                  label: 'اللغة',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MaisonChip(
                        label: 'عربي',
                        active: prefs.localeCode == 'ar',
                        onTap: () => ref
                            .read(prefsControllerProvider.notifier)
                            .setLocale('ar'),
                      ),
                      const SizedBox(width: 6),
                      MaisonChip(
                        label: 'EN',
                        active: prefs.localeCode == 'en',
                        onTap: () => ref
                            .read(prefsControllerProvider.notifier)
                            .setLocale('en'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            MaisonMenuGroup(
              children: [
                MaisonMenuRow(
                  icon: Icons.support_agent_rounded,
                  label: 'الدعم والمساعدة',
                  onTap: () => context.push('/support'),
                ),
                MaisonMenuRow(
                  icon: Icons.info_outline_rounded,
                  label: 'عن VIBEES',
                  trailing: Text(
                    '1.0.0',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: VibesTheme.textTertiaryOf(context),
                    ),
                  ),
                ),
              ],
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
                  if (context.mounted) context.go('/home');
                },
              ),
            ),
            const SizedBox(height: 36),
            _OwnerWhisper(
              isOwner: auth.isProvider,
              onTap: () =>
                  context.push(auth.isProvider ? '/provider' : '/owner'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _editName(
  BuildContext context,
  WidgetRef ref,
  String? current,
) async {
  final next = await showMaisonPrompt(
    context: context,
    title: 'اسمك',
    initial: current,
    hint: 'اكتب اسمك',
  );
  if (next == null || next.isEmpty) return;
  try {
    await ref.read(authControllerProvider.notifier).updateName(next);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(maisonError(error))));
    }
  }
}

/// ملف الزائر — تصفح حر، والدخول اختيار من هنا
class _GuestProfile extends ConsumerWidget {
  const _GuestProfile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsControllerProvider);

    return Scaffold(
      body: MaisonWash(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const MaisonPageHeader(
              title: 'ملفي',
              kicker: 'الضيافة',
              safe: true,
            ),
            const SizedBox(height: 8),
            FolioPanel(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'تصفح بحرية',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'الدخول يُطلب عند إتمام الحجز. تستطيع الدخول من هنا متى شئت.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: VibesTheme.textSecondaryOf(context),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 18),
                    VibesButton(
                      label: 'دخول',
                      onPressed: () => context.push('/login'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            FolioPanel(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'اللغة',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    MaisonChip(
                      label: 'عربي',
                      active: prefs.localeCode == 'ar',
                      onTap: () => ref
                          .read(prefsControllerProvider.notifier)
                          .setLocale('ar'),
                    ),
                    const SizedBox(width: 6),
                    MaisonChip(
                      label: 'EN',
                      active: prefs.localeCode == 'en',
                      onTap: () => ref
                          .read(prefsControllerProvider.notifier)
                          .setLocale('en'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            MaisonMenuGroup(
              children: [
                MaisonMenuRow(
                  icon: Icons.support_agent_rounded,
                  label: 'الدعم والمساعدة',
                  onTap: () => context.push('/support'),
                ),
              ],
            ),
            const SizedBox(height: 36),
            _OwnerWhisper(
              isOwner: false,
              onTap: () async {
                final ok = await context.push<bool>('/login?next=/owner');
                if (ok != true || !context.mounted) return;
                final auth = ref.read(authControllerProvider);
                context.push(auth.isProvider ? '/provider' : '/owner');
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// سطر هادئ في ذيل الملف — لأصحاب الأماكن، بلا صف في قائمة الضيف
class _OwnerWhisper extends StatelessWidget {
  const _OwnerWhisper({required this.isOwner, required this.onTap});

  final bool isOwner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Column(
            children: [
              const ArcFlourish(width: 22),
              const SizedBox(height: 10),
              Text(
                isOwner ? 'لوحة الإدارة' : 'لأصحاب الأماكن',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: VibesTheme.textTertiaryOf(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _chevron(BuildContext context) => Icon(
  Icons.chevron_left_rounded,
  color: VibesTheme.textTertiaryOf(context),
  size: 20,
);

class _CountMark extends StatelessWidget {
  const _CountMark(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Vibes.coral,
        fontWeight: FontWeight.w800,
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
    return Switch.adaptive(
      value: value,
      onChanged: onChanged,
      activeTrackColor: Vibes.coral,
    );
  }
}

/// بطاقة إحصاء — رقم كبير عسلي أو زمردي
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.honey = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final bool honey;

  @override
  Widget build(BuildContext context) {
    final color = honey ? Vibes.teal : Vibes.coral;
    return FolioPanel(
      color: VibesTheme.surfaceOf(context),
      borderColor: VibesTheme.hairlineOf(context),
      shadows: Vibes.card,
      clip: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            FolioPanel(
              color: color.withValues(alpha: .10),
              borderColor: Colors.transparent,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(icon, size: 20, color: color),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: VibesTheme.textTertiaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
