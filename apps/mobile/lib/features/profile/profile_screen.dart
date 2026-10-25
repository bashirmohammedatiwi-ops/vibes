import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/world_theme.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/data/marketplace_providers.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_graphics.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../auth/auth_controller.dart';
import '../../core/app_mode/app_mode_controller.dart';
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
          children: [
            const MaisonPageHeader(
              title: 'ملفي',
              kicker: 'العضوية',
              safe: true,
            ),
            const SizedBox(height: 8),
            // بطاقة العضوية — تدرّج العالم، الهوية، والأرقام
            _MemberCard(
              name: user?.name,
              phone: user?.phone,
              onEdit: () => _editName(context, ref, user?.name),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: .05, end: 0),
            const SizedBox(height: 24),
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
                  icon: Icons.privacy_tip_outlined,
                  label: 'سياسة الخصوصية',
                  onTap: () => openLegal('/privacy'),
                ),
                MaisonMenuRow(
                  icon: Icons.description_outlined,
                  label: 'شروط الاستخدام',
                  onTap: () => openLegal('/terms'),
                ),
                MaisonMenuRow(
                  icon: Icons.info_outline_rounded,
                  label: 'عن VIBES',
                  onTap: () => openLegal('/'),
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
                  await ref.read(appModeProvider.notifier).resetAfterLogout();
                  if (context.mounted) context.go('/home');
                },
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                onPressed: () => confirmDeleteAccount(context, ref),
                icon: Icon(
                  Icons.delete_forever_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
                label: Text(
                  'حذف الحساب',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
            _OwnerWhisper(
              isOwner: auth.isProvider,
              onTap: () {
                if (auth.isProvider) {
                  switchToProviderPortal(context, ref);
                } else {
                  context.push('/owner');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// صفحات الخصوصية والشروط على موقع VIBES.
Future<void> openLegal(String path) => launchUrl(
  Uri.parse('${ApiConstants.server}$path'),
  mode: LaunchMode.inAppBrowserView,
);

Future<void> confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
  final ok = await showMaisonConfirm(
    context: context,
    title: 'حذف الحساب نهائياً؟',
    message:
        'سيُحذف رقمك واسمك ومفضلتك وإشعاراتك ومنشوراتك، وتُلغى الحجوزات غير المدفوعة. '
        'الحجوزات المؤكدة تبقى لدى صاحب المكان دون هويتك. لا يمكن التراجع عن الحذف.',
    confirmLabel: 'احذف حسابي',
    destructive: true,
  );
  if (!ok || !context.mounted) return;
  try {
    final pending = await ref
        .read(authControllerProvider.notifier)
        .deleteAccount();
    if (pending != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(pending)));
      }
      return;
    }
    await ref.read(appModeProvider.notifier).resetAfterLogout();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('حُذف حسابك وبياناتك الشخصية')),
    );
    context.go('/home');
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(maisonError(error))));
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
    return Scaffold(
      body: MaisonWash(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
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
            MaisonMenuGroup(
              children: [
                MaisonMenuRow(
                  icon: Icons.support_agent_rounded,
                  label: 'الدعم والمساعدة',
                  onTap: () => context.push('/support'),
                ),
                MaisonMenuRow(
                  icon: Icons.privacy_tip_outlined,
                  label: 'سياسة الخصوصية',
                  onTap: () => openLegal('/privacy'),
                ),
                MaisonMenuRow(
                  icon: Icons.description_outlined,
                  label: 'شروط الاستخدام',
                  onTap: () => openLegal('/terms'),
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
                if (auth.isProvider) {
                  switchToProviderPortal(context, ref);
                } else {
                  context.push('/owner');
                }
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOwner
                        ? Icons.space_dashboard_outlined
                        : Icons.home_work_outlined,
                    size: 14,
                    color: VibesTheme.textTertiaryOf(context),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOwner
                        ? 'الانتقال إلى بوابة المالك'
                        : 'مالك مزرعة أو قاعة؟',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: VibesTheme.textTertiaryOf(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
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
        color: context.world.accentDeep,
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
      activeTrackColor: context.world.accent,
    );
  }
}

/// بطاقة العضوية — تدرّج العالم بزخرفة، الحرف الأول أو الشعار الأبيض،
/// والاسم والهاتف، وأرقام الحجوزات والمفضلة داخل البطاقة.
class _MemberCard extends ConsumerWidget {
  const _MemberCard({
    required this.name,
    required this.phone,
    required this.onEdit,
  });

  final String? name;
  final String? phone;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.world;
    final n = (name ?? '').trim();
    final bookings = ref.watch(myBookingsProvider).valueOrNull?.length ?? 0;
    final favs = ref.watch(favoritesProvider).valueOrNull?.length ?? 0;
    final following =
        ref.watch(followingProvidersProvider).valueOrNull?.length ?? 0;

    Widget stat(String value, String label, VoidCallback onTap) => Expanded(
      child: PressScale(
        onTap: onTap,
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.2,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: .75),
              ),
            ),
          ],
        ),
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color.lerp(p.accent, p.accentDeep, .2)!,
            p.accentDeep,
            Color.lerp(p.accentDeep, p.night, .5)!,
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: p.glow.withValues(alpha: .30),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            end: -30,
            top: -40,
            child: Opacity(
              opacity: .10,
              child: VibesLogo.mark(size: 170, color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    n.isEmpty
                        ? const VibesLogo.mark(size: 52, color: Colors.white)
                        : Container(
                            width: 58,
                            height: 58,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                n.characters.first,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: p.accentDeep,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'عضو VIBES',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: .75),
                            ),
                          ),
                          Text(
                            n.isEmpty ? 'أضف اسمك' : n,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.25,
                            ),
                          ),
                          if ((phone ?? '').isNotEmpty)
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                phone!,
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: .8),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    PressScale(
                      onTap: onEdit,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .16),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .3),
                          ),
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          size: 17,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .18),
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        stat(
                          '$bookings',
                          'حجوزات',
                          () => context.go('/bookings'),
                        ),
                        VerticalDivider(
                          width: 1,
                          color: Colors.white.withValues(alpha: .2),
                        ),
                        stat(
                          '$favs',
                          'مفضلة',
                          () => context.push('/favorites'),
                        ),
                        VerticalDivider(
                          width: 1,
                          color: Colors.white.withValues(alpha: .2),
                        ),
                        stat(
                          '$following',
                          'أتابعهم',
                          () => context.push('/following'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
