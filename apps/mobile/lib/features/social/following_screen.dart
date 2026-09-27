import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/vibes_net_image.dart';
import '../../shared/data/marketplace_providers.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_widgets.dart';

class FollowingScreen extends ConsumerWidget {
  const FollowingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final following = ref.watch(followingProvidersProvider);
    return Scaffold(
      body: MaisonWash(
        child: Column(
          children: [
            MaisonPageHeader(
              title: 'أتابعهم',
              kicker: 'أصحاب الأماكن',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: following.when(
                loading: () => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: const [
                    ShimmerBox(height: 86, radius: VibesRadius.lg),
                    SizedBox(height: 10),
                    ShimmerBox(height: 86, radius: VibesRadius.lg),
                    SizedBox(height: 10),
                    ShimmerBox(height: 86, radius: VibesRadius.lg),
                  ],
                ),
                error: (e, _) => ErrorCanvas(
                  message: maisonError(e),
                  onRetry: () => ref.invalidate(followingProvidersProvider),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const EmptyCanvas(
                      icon: Icons.person_add_alt_1_outlined,
                      title: 'لا تتابع أحداً بعد',
                      subtitle:
                          'تابع مزوداً من صفحته لتصلك تجاربه وأماكنه الجديدة',
                    );
                  }
                  return RefreshIndicator(
                    color: Vibes.coral,
                    onRefresh: () async =>
                        ref.invalidate(followingProvidersProvider),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final p = list[i];
                        return VibesCard(
                          onTap: () => context.push('/providers/${p.id}'),
                          child: Row(
                            children: [
                              FolioPanel(
                                color: Vibes.surface,
                                clip: true,
                                child: SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: p.avatar != null
                                      ? VibesNetImage(
                                          url: p.avatar!,
                                          width: 52,
                                          height: 52,
                                          memCacheWidth: 104,
                                        )
                                      : const Icon(
                                          Icons.storefront_outlined,
                                          color: Vibes.coral,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.displayName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${p.propertiesCount} مكان · ${p.followers} متابع',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: VibesTheme.textSecondaryOf(
                                              context,
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              if (p.verified)
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 18,
                                  color: Vibes.teal,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
