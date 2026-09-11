import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/widgets/property_card.dart';
import '../../shared/widgets/vibes_widgets.dart';

/// قائمة المفضلة — الأماكن المحفوظة بحسابك
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('المفضلة')),
      body: favorites.when(
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
          message: e.toString(),
          onRetry: () => ref.invalidate(favoritesProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyCanvas(
              icon: Icons.favorite_outline_rounded,
              title: 'لا مفضلة بعد',
              subtitle: 'اضغط القلب على أي مكان لحفظه هنا ومتابعته',
            );
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            itemCount: list.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PropertyCard(
                property: list[i],
                isFavorite: true,
                onFavorite: (_) =>
                    ref.read(favoritesProvider.notifier).toggle(list[i]),
              ).animate(delay: Duration(milliseconds: i * 40)).fadeIn(),
            ),
          );
        },
      ),
    );
  }
}
