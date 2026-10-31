import 'package:flutter/material.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../profile/profile_screen.dart' show confirmDeleteAccount, openLegal;

import '../../shared/widgets/maison_chrome.dart';
import '../auth/auth_controller.dart';
import '../chat/conversations_screen.dart';
import '../property/place_experience_ui.dart';
import 'provider_actions.dart';
import 'provider_data.dart';
import 'provider_ui.dart';
import '../../core/theme/world_theme.dart';
import '../../core/app_mode/app_mode_controller.dart';

class ProviderAccountScreen extends ConsumerWidget {
  const ProviderAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final overview = ref.watch(providerOverviewProvider);
    final user = auth.user;

    return Scaffold(
      backgroundColor: WorldPalette.owner.canvas,
      body: OwnerPortalCanvas(
        child: Column(
          children: [
            MaisonPageHeader(
              title: 'حساب المالك'.tr,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  const OwnerBrassRule(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: ownerPaper,
                        child: Text(
                          (user?.name?.trim().isNotEmpty == true
                                  ? user!.name!.trim()[0]
                                  : (I18n.isEn ? 'O' : 'م')) // i18n-ok
                              .toUpperCase(),
                          style: TextStyle(
                            fontFamily: VibesFont.ui,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: ownerNavy,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name?.trim().isNotEmpty == true
                                  ? user!.name!
                                  : 'مالك أجواء'.tr,
                              style: TextStyle(
                                fontFamily: VibesFont.ui,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: ownerNavy,
                              ),
                            ),
                            Text(
                              user?.phone ?? '',
                              style: TextStyle(
                                fontFamily: VibesFont.ui,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: placeInk2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  overview.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (o) => Material(
                      color: ownerPaper,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () => context.go('/provider/properties'),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  [
                                    '{n} مكان مربوط'.trN(o.propertyCount),
                                    '{n} حجز نشط'.trN(o.activeBookings),
                                  ].join(' · '),
                                  style: TextStyle(
                                    fontFamily: VibesFont.ui,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: ownerNavy,
                                  ),
                                ),
                              ),
                              Icon(ownerForwardChevron, color: placeInk2),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ownerPaper,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ownerLine),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ألوان التقويم'.tr,
                          style: TextStyle(
                            fontFamily: VibesFont.ui,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: ownerNavy,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const OwnerCalendarLegend(),
                        const SizedBox(height: 6),
                        Text(
                          'الشرائط أسفل اليوم تعرض الشفتات المحجوزة — صباح، مساء، أو يوم كامل.'.tr,
                          style: TextStyle(
                            fontFamily: VibesFont.ui,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: placeInk2,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: ownerLine),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        OwnerMenuTile(
                          icon: Icons.explore_outlined,
                          label: 'تصفّح التطبيق كضيف'.tr,
                          onTap: () => switchToGuestExperience(context, ref),
                        ),
                        Divider(height: 1, color: ownerLine),
                        OwnerMenuTile(
                          icon: Icons.forum_outlined,
                          label: 'مراسلة الدعم'.tr,
                          onTap: () => openSupportChat(context, ref),
                        ),
                        Divider(height: 1, color: ownerLine),
                        OwnerMenuTile(
                          icon: Icons.help_outline_rounded,
                          label: 'مركز المساعدة'.tr,
                          onTap: () => context.push('/support'),
                        ),
                        Divider(height: 1, color: ownerLine),
                        OwnerMenuTile(
                          icon: Icons.privacy_tip_outlined,
                          label: 'سياسة الخصوصية'.tr,
                          onTap: () => openLegal('/privacy'),
                        ),
                        Divider(height: 1, color: ownerLine),
                        OwnerMenuTile(
                          icon: Icons.description_outlined,
                          label: 'شروط الاستخدام'.tr,
                          onTap: () => openLegal('/terms'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => providerLogout(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ownerNavy,
                      side: BorderSide(color: ownerLine),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'تسجيل الخروج'.tr,
                      style: TextStyle(
                        fontFamily: VibesFont.ui,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => confirmDeleteAccount(context, ref),
                    icon: Icon(
                      Icons.delete_forever_outlined,
                      size: 18,
                      color: themed(const Color(0xFFC2402F), Vibes.danger),
                    ),
                    label: Text(
                      'حذف الحساب'.tr,
                      style: TextStyle(
                        fontFamily: VibesFont.ui,
                        fontWeight: FontWeight.w800,
                        color: themed(const Color(0xFFC2402F), Vibes.danger),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
