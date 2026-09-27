import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/data/marketplace_providers.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/property_card.dart';
import '../../shared/widgets/vibes_widgets.dart';

/// قائمة المفضلة — الأماكن المحفوظة بحسابك
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      body: MaisonWash(
        child: Column(
          children: [
            MaisonPageHeader(
              title: 'المفضلة',
              kicker: 'محفوظاتك',
              trailing: IconButton(
                tooltip: 'قائمة جديدة',
                onPressed: () => _createCollection(context, ref),
                icon: const Icon(Icons.playlist_add_rounded),
              ),
            ),
            Expanded(
              child: favorites.when(
                loading: () => ListView(
                  padding: const EdgeInsets.all(20),
                  children: List.generate(
                    3,
                    (_) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ShimmerBox(height: 240, radius: VibesRadius.lg),
                    ),
                  ),
                ),
                error: (e, _) => ErrorCanvas(
                  message: maisonError(e),
                  onRetry: () => ref.invalidate(favoritesProvider),
                ),
                data: (list) {
                  final collections =
                      ref.watch(collectionsProvider).valueOrNull ?? [];
                  final publicLists =
                      ref.watch(publicCollectionsProvider).valueOrNull ?? [];
                  if (list.isEmpty &&
                      collections.isEmpty &&
                      publicLists.isEmpty) {
                    return const EmptyCanvas(
                      icon: Icons.favorite_outline_rounded,
                      title: 'لا مفضلة بعد',
                      subtitle: 'اضغط القلب على أي مكان لحفظه هنا ومتابعته',
                    );
                  }

                  return RefreshIndicator(
                    color: Vibes.coral,
                    onRefresh: () async {
                      await ref.read(favoritesProvider.notifier).refresh();
                      ref.invalidate(collectionsProvider);
                      ref.invalidate(publicCollectionsProvider);
                    },
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                      itemCount: list.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          final publicLists =
                              ref
                                  .watch(publicCollectionsProvider)
                                  .valueOrNull ??
                              [];
                          if (collections.isEmpty && publicLists.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (collections.isNotEmpty)
                                  SizedBox(
                                    height: 86,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: collections.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(width: 8),
                                      itemBuilder: (context, ci) {
                                        final col = collections[ci];
                                        return _CollectionChip(
                                          name: col.name,
                                          coverUrl: col.coverUrl,
                                          count: col.itemCount,
                                          onTap: () => context.push(
                                            '/collections/${col.id}',
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                if (publicLists.isNotEmpty) ...[
                                  if (collections.isNotEmpty)
                                    const SizedBox(height: 12),
                                  Text(
                                    'قوائم عامة',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 86,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: publicLists.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(width: 8),
                                      itemBuilder: (context, ci) {
                                        final col = publicLists[ci];
                                        return _CollectionChip(
                                          name: col.name,
                                          coverUrl: col.coverUrl,
                                          count: col.itemCount,
                                          subtitle: col.ownerName,
                                          onTap: () => context.push(
                                            '/collections/${col.id}',
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }
                        final property = list[i - 1];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child:
                              PropertyCard(
                                    property: property,
                                    heroNamespace: 'fav',
                                    isFavorite: true,
                                    onFavorite: (_) => ref
                                        .read(favoritesProvider.notifier)
                                        .toggle(property),
                                  )
                                  .animate(
                                    delay: Duration(milliseconds: i * 40),
                                  )
                                  .fadeIn(),
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

Future<void> _createCollection(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController();
  final description = TextEditingController();
  final created = await showMaisonSheet<bool>(
    context: context,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'قائمة جديدة',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          MaisonField(label: 'اسم القائمة', controller: name),
          const SizedBox(height: 12),
          MaisonField(label: 'وصف اختياري', controller: description),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: VibesButton(
                  label: 'إلغاء',
                  ghost: true,
                  small: true,
                  onPressed: () => Navigator.pop(context, false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: VibesButton(
                  label: 'إنشاء',
                  small: true,
                  onPressed: () => Navigator.pop(context, true),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  final title = name.text.trim();
  final note = description.text.trim();
  name.dispose();
  description.dispose();
  if (created != true || title.length < 2) return;
  try {
    await ref
        .read(apiClientProvider)
        .post(
          '/api/collections',
          body: {'name': title, if (note.isNotEmpty) 'description': note},
        );
    ref.invalidate(collectionsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إنشاء القائمة')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(maisonError(e))));
    }
  }
}

class _CollectionChip extends StatelessWidget {
  const _CollectionChip({
    required this.name,
    required this.count,
    required this.onTap,
    this.coverUrl,
    this.subtitle,
  });

  final String name;
  final int count;
  final VoidCallback onTap;
  final String? coverUrl;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 168,
        child: FolioPanel(
          borderColor: Vibes.teal.withValues(alpha: .22),
          railColor: Vibes.teal,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                MaisonThumb(
                  url: coverUrl,
                  size: 42,
                  fallback: const Icon(
                    Icons.bookmark_outline_rounded,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      Text(
                        subtitle == null || subtitle!.isEmpty
                            ? '$count مكان'
                            : '$count · $subtitle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
