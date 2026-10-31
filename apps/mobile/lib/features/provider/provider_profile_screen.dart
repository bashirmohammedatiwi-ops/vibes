import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';

import '../../core/i18n/i18n.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/marketplace_providers.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/property_card.dart';
import 'provider_ui.dart';
import '../../shared/widgets/world_ui.dart';
import '../../shared/widgets/vibes_widgets.dart';

final _providerProfileProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
      final data = await ref
          .watch(apiClientProvider)
          .get('/api/providers/$id/profile');
      return data as Map<String, dynamic>;
    });

class ProviderProfileScreen extends ConsumerWidget {
  const ProviderProfileScreen({super.key, required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(_providerProfileProvider(providerId));
    final follow = ref.watch(followStatusProvider(providerId));

    return Scaffold(
      body: MaisonWash(
        child: profile.when(
          loading: () => ListView(
            padding: const EdgeInsets.fromLTRB(20, 72, 20, 28),
            children: const [
              WorldSkeleton(height: 88, radius: 20),
              SizedBox(height: 16),
              WorldSkeleton(height: 220, radius: 20),
              SizedBox(height: 14),
              WorldSkeleton(height: 220, radius: 20),
            ],
          ),
          error: (e, _) => ErrorCanvas(
            message: maisonError(e),
            onRetry: () => ref.invalidate(_providerProfileProvider(providerId)),
          ),
          data: (data) {
            final user = data['user'] as Map<String, dynamic>?;
            final name =
                data['businessName'] as String? ??
                user?['name'] as String? ??
                'مالك أجواء'.tr;
            final avatar = user?['avatar'] as String?;
            final properties =
                (data['properties'] as List<dynamic>? ?? const [])
                    .whereType<Map<String, dynamic>>()
                    .map(Property.fromJson)
                    .toList();
            final count = data['_count'] is Map
                ? (data['_count']['followers'] as num?)?.toInt() ?? 0
                : follow.valueOrNull?.followers ?? 0;

            return Column(
              children: [
                MaisonPageHeader(title: name, onBack: () => context.pop()),
                Expanded(
                  child: RefreshIndicator(
                    color: ownerNavyHigh,
                    onRefresh: () async {
                      ref.invalidate(_providerProfileProvider(providerId));
                      ref.invalidate(followStatusProvider(providerId));
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      children: [
                        VibesCard(
                          child: Row(
                            children: [
                              MaisonThumb(
                                url: avatar != null && avatar.isNotEmpty
                                    ? avatar
                                    : null,
                                size: 56,
                                fallback: const Icon(Icons.person_rounded),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    Text(
                                      '{n} متابع'.trN(count),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: VibesTheme.textTertiaryOf(
                                              context,
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  if (ref.read(authControllerProvider).user ==
                                      null) {
                                    await context.push<bool>('/login');
                                    return;
                                  }
                                  final client = ref.read(apiClientProvider);
                                  final following =
                                      follow.valueOrNull?.following == true;
                                  try {
                                    if (following) {
                                      await client.delete(
                                        '/api/follows/$providerId',
                                      );
                                    } else {
                                      await client.post(
                                        '/api/follows/$providerId',
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text(maisonError(e))),
                                      );
                                    }
                                    return;
                                  }
                                  ref.invalidate(
                                    followStatusProvider(providerId),
                                  );
                                  ref.invalidate(
                                    _providerProfileProvider(providerId),
                                  );
                                  ref.invalidate(followingExperiencesProvider);
                                  ref.invalidate(followingProvidersProvider);
                                },
                                child: Text(
                                  follow.valueOrNull?.following == true
                                      ? 'إلغاء المتابعة'.tr
                                      : 'متابعة'.tr,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        SectionHeader('أماكن هذا المالك'.tr),
                        if (properties.isEmpty)
                          WorldEmpty(
                            icon: Icons.home_work_outlined,
                            title: 'لا أماكن ظاهرة'.tr,
                            subtitle: 'لم ينشر هذا المالك أماكن بعد'.tr,
                          )
                        else
                          for (final property in properties)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: PropertyCard(
                                property: property,
                                heroNamespace: 'host',
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
