import 'package:flutter/material.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../auth/auth_controller.dart';
import '../chat/conversations_screen.dart';
import 'provider_ui.dart';
import '../../core/theme/world_theme.dart';
import '../property/place_experience_ui.dart';

final myPlaceClaimsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final loggedIn = ref.watch(authControllerProvider).loggedIn;
  if (!loggedIn) return const [];
  final data = await ref
      .watch(apiClientProvider)
      .get('/api/providers/claims/mine');
  if (data is List) {
    return data.whereType<Map<String, dynamic>>().toList();
  }
  return const [];
});

/// مالك مزرعة أو قاعة: لا يطلب إضافة مكان، يراسل الدعم والفريق يربط الحساب.
class OwnerGateScreen extends ConsumerWidget {
  const OwnerGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final claims = ref.watch(myPlaceClaimsProvider);

    if (auth.isProvider) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/provider');
      });
    }

    return Scaffold(
      backgroundColor: WorldPalette.owner.canvas,
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          MaisonPageHeader(
            title: 'لأصحاب الأماكن'.tr,
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
          Container(
            width: 28,
            height: 3,
            decoration: BoxDecoration(
              color: ownerGoldDeep,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'إذا كنت مالك مزرعة أو قاعة'.tr,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: ownerNavy,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'راسل الدعم باسم المكان ورقم هاتفك. فريق أجواء يتحقق من الملكية ثم يربط المكان بحسابك. لا حاجة لإضافة المكان بنفسك.'.tr,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: placeInk2,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () async {
              if (!auth.loggedIn) {
                final ok = await context.push<bool>('/login?next=/owner');
                if (ok != true || !context.mounted) return;
              }
              await openSupportChat(context, ref);
            },
            icon: const Icon(Icons.forum_outlined),
            label: Text('راسل الدعم'.tr),
            style: FilledButton.styleFrom(
              backgroundColor: themed(ownerNavyDeep, WorldPalette.owner.accent),
              foregroundColor: themed(
                Colors.white,
                WorldPalette.owner.onAccent,
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: TextStyle(
                fontFamily: VibesFont.ui,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.push('/support'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ownerNavy,
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: ownerLine),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'مركز المساعدة'.tr,
              style: TextStyle(
                fontFamily: VibesFont.ui,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 28),
          claims.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (list) {
              final linked = list
                  .where((c) => c['status'] == 'APPROVED')
                  .toList();
              if (linked.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'أماكن رُبطت بحسابك'.tr,
                    style: TextStyle(
                      fontFamily: VibesFont.ui,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: ownerNavy,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final claim in linked)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        (claim['property'] is Map
                                    ? (claim['property'] as Map)['name']
                                    : null)
                                ?.toString() ??
                            'مكان'.tr,
                        style: TextStyle(
                          fontFamily: VibesFont.ui,
                          fontWeight: FontWeight.w700,
                          color: placeInk2,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
