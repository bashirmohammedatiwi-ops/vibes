import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
            MaisonPageHeader(title: 'حساب المالك', onBack: () => context.pop()),
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
                                  : 'م')
                              .toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
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
                                  : 'مالك VIBES',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: ownerNavy,
                              ),
                            ),
                            Text(
                              user?.phone ?? '',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
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
                                  '${o.propertyCount} مكان مربوط · ${o.activeBookings} حجز نشط',
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: ownerNavy,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_left_rounded,
                                color: placeInk2,
                              ),
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
                        const Text(
                          'ألوان التقويم',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: ownerNavy,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const OwnerCalendarLegend(),
                        const SizedBox(height: 6),
                        const Text(
                          'الشرائط أسفل اليوم تعرض الشفتات المحجوزة — صباح، مساء، أو يوم كامل.',
                          style: TextStyle(
                            fontFamily: 'Cairo',
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
                          label: 'تصفّح التطبيق كضيف',
                          onTap: () => switchToGuestExperience(context, ref),
                        ),
                        const Divider(height: 1, color: ownerLine),
                        OwnerMenuTile(
                          icon: Icons.forum_outlined,
                          label: 'مراسلة الدعم',
                          onTap: () => openSupportChat(context, ref),
                        ),
                        const Divider(height: 1, color: ownerLine),
                        OwnerMenuTile(
                          icon: Icons.help_outline_rounded,
                          label: 'مركز المساعدة',
                          onTap: () => context.push('/support'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => providerLogout(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ownerNavy,
                      side: const BorderSide(color: ownerLine),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'تسجيل الخروج',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w900,
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
