import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/api_constants.dart';
import '../../core/i18n/i18n.dart';
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
            MaisonPageHeader(
              title: 'ملفي'.tr,
              kicker: 'العضوية'.tr,
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
            MaisonKicker('حسابك'.tr),
            const SizedBox(height: 10),
            MaisonMenuGroup(
              children: [
                MaisonMenuRow(
                  icon: Icons.notifications_none_rounded,
                  label: 'الإشعارات'.tr,
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
                  label: 'الرسائل'.tr,
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
                  label: 'الفواتير'.tr,
                  onTap: () => context.push('/invoices'),
                ),
                MaisonMenuRow(
                  icon: Icons.favorite_outline_rounded,
                  label: 'المفضلة والقوائم'.tr,
                  trailing: _CountMark('${favorites.valueOrNull?.length ?? 0}'),
                  onTap: () => context.push('/favorites'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            MaisonKicker('اكتشف'.tr),
            const SizedBox(height: 10),
            MaisonMenuGroup(
              children: [
                MaisonMenuRow(
                  icon: Icons.card_giftcard_rounded,
                  label: 'بطاقات الولاء'.tr,
                  onTap: () => context.push('/loyalty'),
                ),
                MaisonMenuRow(
                  icon: Icons.local_offer_outlined,
                  label: 'العروض الخاصة'.tr,
                  onTap: () => context.push('/offers'),
                ),
                MaisonMenuRow(
                  icon: Icons.confirmation_number_outlined,
                  label: 'كوبونات الخصم'.tr,
                  onTap: () => context.push('/coupons'),
                ),
                MaisonMenuRow(
                  icon: Icons.auto_awesome_outlined,
                  label: 'تجارب الضيوف'.tr,
                  onTap: () => context.push('/experiences'),
                ),
                MaisonMenuRow(
                  icon: Icons.person_add_alt_1_outlined,
                  label: 'أتابعهم'.tr,
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
            MaisonKicker('التفضيلات'.tr),
            const SizedBox(height: 10),
            MaisonMenuGroup(
              children: [
                MaisonMenuRow(
                  icon: switch (prefs.themeMode) {
                    ThemeMode.dark => Icons.dark_mode_outlined,
                    ThemeMode.light => Icons.light_mode_outlined,
                    ThemeMode.system => Icons.brightness_auto_outlined,
                  },
                  label: 'المظهر'.tr,
                  trailing: _ValueMark(switch (prefs.themeMode) {
                    ThemeMode.dark => 'داكن'.tr,
                    ThemeMode.light => 'فاتح'.tr,
                    ThemeMode.system => 'حسب الجهاز'.tr,
                  }),
                  onTap: () => _pickTheme(context, ref),
                ),
                MaisonMenuRow(
                  icon: Icons.language_rounded,
                  label: 'اللغة'.tr,
                  trailing: _ValueMark(
                    I18n.isEn ? 'English' : 'العربية', // i18n-ok
                  ),
                  onTap: () => _pickLanguage(context, ref),
                ),
                MaisonMenuRow(
                  icon: Icons.data_saver_on_outlined,
                  label: 'توفير البيانات'.tr,
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
                  label: 'الدعم والمساعدة'.tr,
                  onTap: () => context.push('/support'),
                ),
                MaisonMenuRow(
                  icon: Icons.privacy_tip_outlined,
                  label: 'سياسة الخصوصية'.tr,
                  onTap: () => openLegal('/privacy'),
                ),
                MaisonMenuRow(
                  icon: Icons.description_outlined,
                  label: 'شروط الاستخدام'.tr,
                  onTap: () => openLegal('/terms'),
                ),
                MaisonMenuRow(
                  icon: Icons.info_outline_rounded,
                  label: 'عن أجواء'.tr,
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
                label: 'تسجيل الخروج'.tr,
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
                  'حذف الحساب'.tr,
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
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
    title: 'حذف الحساب نهائياً؟'.tr,
    message:
        'سيُحذف رقمك واسمك ومفضلتك وإشعاراتك ومنشوراتك، وتُلغى الحجوزات غير المدفوعة. الحجوزات المؤكدة تبقى لدى صاحب المكان دون هويتك. لا يمكن التراجع عن الحذف.'.tr,
    confirmLabel: 'احذف حسابي'.tr,
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('حُذف حسابك وبياناتك الشخصية'.tr)));
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
    title: 'اسمك'.tr,
    initial: current,
    hint: 'اكتب اسمك'.tr,
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
            MaisonPageHeader(
              title: 'ملفي'.tr,
              kicker: 'الضيافة'.tr,
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
                      'تصفح بحرية'.tr,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'الدخول يُطلب عند إتمام الحجز. تستطيع الدخول من هنا متى شئت.'.tr,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: VibesTheme.textSecondaryOf(context),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 18),
                    VibesButton(
                      label: 'دخول'.tr,
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
                  label: 'الدعم والمساعدة'.tr,
                  onTap: () => context.push('/support'),
                ),
                MaisonMenuRow(
                  icon: Icons.privacy_tip_outlined,
                  label: 'سياسة الخصوصية'.tr,
                  onTap: () => openLegal('/privacy'),
                ),
                MaisonMenuRow(
                  icon: Icons.description_outlined,
                  label: 'شروط الاستخدام'.tr,
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
                        ? 'الانتقال إلى بوابة المالك'.tr
                        : 'مالك مزرعة أو قاعة؟'.tr,
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
  I18n.isEn ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
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
                fontFamily: VibesFont.ui,
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
          // ليلاً اللون العميق فاتح: تدرّج ليل العالم حتى يبقى النص الأبيض مقروءاً
          colors: Appearance.isDark
              ? [
                  p.nightHigh,
                  p.night,
                  Color.lerp(p.night, VibesDark.canvas, .6)!,
                ]
              : [
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
                            decoration: BoxDecoration(
                              color: Vibes.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                n.characters.first,
                                style: TextStyle(
                                  fontFamily: VibesFont.ui,
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
                            'عضو أجواء'.tr,
                            style: TextStyle(
                              fontFamily: VibesFont.ui,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: .75),
                            ),
                          ),
                          Text(
                            n.isEmpty ? 'أضف اسمك'.tr : n,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: VibesFont.ui,
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
                          'حجوزات'.tr,
                          () => context.go('/bookings'),
                        ),
                        VerticalDivider(
                          width: 1,
                          color: Colors.white.withValues(alpha: .2),
                        ),
                        stat(
                          '$favs',
                          'مفضلة'.tr,
                          () => context.push('/favorites'),
                        ),
                        VerticalDivider(
                          width: 1,
                          color: Colors.white.withValues(alpha: .2),
                        ),
                        stat(
                          '$following',
                          'أتابعهم'.tr,
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

class _ValueMark extends StatelessWidget {
  const _ValueMark(this.value);

  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value,
        style: TextStyle(
          fontFamily: VibesFont.ui,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Vibes.inkSecondary,
        ),
      ),
      const SizedBox(width: 4),
      Icon(Icons.chevron_right_rounded, size: 18, color: Vibes.inkTertiary),
    ],
  );
}

void _pickTheme(BuildContext context, WidgetRef ref) {
  final prefs = ref.read(prefsControllerProvider);
  _pickOne<ThemeMode>(
    context,
    title: 'المظهر'.tr,
    current: prefs.themeMode,
    options: {
      ThemeMode.system: ('حسب الجهاز'.tr, Icons.brightness_auto_outlined),
      ThemeMode.light: ('فاتح'.tr, Icons.light_mode_outlined),
      ThemeMode.dark: ('داكن'.tr, Icons.dark_mode_outlined),
    },
    onPick: ref.read(prefsControllerProvider.notifier).setThemeMode,
  );
}

void _pickLanguage(BuildContext context, WidgetRef ref) {
  _pickOne<String>(
    context,
    title: 'اللغة'.tr,
    current: I18n.locale,
    options: const {
      'ar': ('العربية', Icons.translate_rounded), // i18n-ok
      'en': ('English', Icons.translate_rounded),
    },
    onPick: ref.read(prefsControllerProvider.notifier).setLocale,
  );
}

void _pickOne<T>(
  BuildContext context, {
  required String title,
  required T current,
  required Map<T, (String, IconData)> options,
  required void Function(T) onPick,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Vibes.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Vibes.ink,
            ),
          ),
          const SizedBox(height: 10),
          for (final e in options.entries)
            ListTile(
              leading: Icon(e.value.$2, color: Vibes.inkSecondary),
              title: Text(
                e.value.$1,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Vibes.ink,
                ),
              ),
              trailing: e.key == current
                  ? Icon(
                      Icons.check_circle_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                Navigator.pop(sheet);
                onPick(e.key);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
