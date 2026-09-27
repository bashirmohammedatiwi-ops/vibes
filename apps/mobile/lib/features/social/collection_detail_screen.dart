import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/vibes_net_image.dart';
import '../../shared/data/marketplace_providers.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/property_card.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../auth/auth_controller.dart';

class CollectionDetailScreen extends ConsumerWidget {
  const CollectionDetailScreen({super.key, required this.id});

  final String id;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    CollectionDetail collection,
  ) async {
    final name = TextEditingController(text: collection.name);
    final description = TextEditingController(text: collection.description);
    final visibility = ValueNotifier(collection.visibility);
    final ok = await showMaisonSheet<bool>(
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'تعديل القائمة',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            MaisonField(label: 'الاسم', controller: name),
            const SizedBox(height: 12),
            MaisonField(label: 'وصف أو ملاحظات', controller: description),
            const SizedBox(height: 8),
            ValueListenableBuilder(
              valueListenable: visibility,
              builder: (context, value, _) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('قائمة عامة'),
                value: value == 'PUBLIC',
                onChanged: (on) => visibility.value = on ? 'PUBLIC' : 'PRIVATE',
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: VibesButton(
                    label: 'تراجع',
                    ghost: true,
                    small: true,
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: VibesButton(
                    label: 'حفظ',
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
    final nextName = name.text.trim();
    final nextDescription = description.text.trim();
    final nextVisibility = visibility.value;
    name.dispose();
    description.dispose();
    visibility.dispose();
    if (ok != true || nextName.length < 2) return;
    await ref
        .read(apiClientProvider)
        .patch(
          '/api/collections/${collection.id}',
          body: {
            'name': nextName,
            'description': nextDescription,
            'visibility': nextVisibility,
          },
        );
    ref.invalidate(collectionDetailProvider(collection.id));
    ref.invalidate(collectionsProvider);
  }

  Future<void> _setCover(
    WidgetRef ref,
    CollectionDetail collection,
    Property property,
  ) async {
    final url = property.coverUrl;
    if (url == null || url.isEmpty) return;
    await ref
        .read(apiClientProvider)
        .patch('/api/collections/${collection.id}', body: {'coverUrl': url});
    ref.invalidate(collectionDetailProvider(collection.id));
    ref.invalidate(collectionsProvider);
  }

  Future<void> _editNote(
    BuildContext context,
    WidgetRef ref,
    CollectionDetail collection,
    CollectionEntry entry,
  ) async {
    final text = await showMaisonPrompt(
      context: context,
      title: 'ملاحظة على ${entry.property.name}',
      initial: entry.note,
      hint: 'لماذا حفظت هذا المكان؟',
    );
    if (text == null) return;
    await ref
        .read(apiClientProvider)
        .patch(
          '/api/collections/${collection.id}/items/${entry.property.id}',
          body: {'note': text},
        );
    ref.invalidate(collectionDetailProvider(collection.id));
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CollectionDetail collection,
  ) async {
    final ok = await showMaisonConfirm(
      context: context,
      title: 'حذف القائمة',
      message: 'سيتم حذف القائمة دون حذف الأماكن نفسها.',
      confirmLabel: 'حذف',
      cancelLabel: 'تراجع',
      destructive: true,
    );
    if (ok != true) return;
    await ref
        .read(apiClientProvider)
        .delete('/api/collections/${collection.id}');
    ref.invalidate(collectionsProvider);
    if (context.mounted) context.pop();
  }

  Future<void> _removeItem(
    BuildContext context,
    WidgetRef ref,
    CollectionDetail collection,
    Property property,
  ) async {
    await ref
        .read(apiClientProvider)
        .delete('/api/collections/${collection.id}/items/${property.id}');
    ref.invalidate(collectionDetailProvider(collection.id));
    ref.invalidate(collectionsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(collectionDetailProvider(id));
    final userId = ref.watch(authControllerProvider).user?.id;
    return Scaffold(
      body: MaisonWash(
        child: Column(
          children: [
            MaisonPageHeader(
              title: detail.valueOrNull?.name ?? 'القائمة',
              onBack: () => context.pop(),
              trailing: detail.valueOrNull == null
                  ? null
                  : PopupMenuButton<String>(
                      onSelected: (value) async {
                        final collection = detail.valueOrNull!;
                        switch (value) {
                          case 'edit':
                            await _edit(context, ref, collection);
                            break;
                          case 'share':
                            await Share.share(
                              'قائمة ${collection.name} على VIBEES\n'
                              'افتحها من التطبيق عبر /collections/${collection.id}\n'
                              '${collection.items.map((e) => e.property.name).join('\n')}',
                            );
                            break;
                          case 'delete':
                            await _delete(context, ref, collection);
                            break;
                        }
                      },
                      itemBuilder: (context) {
                        final collection = detail.valueOrNull!;
                        final mine =
                            collection.userId.isEmpty ||
                            collection.userId == userId;
                        return [
                          const PopupMenuItem(
                            value: 'share',
                            child: Text('مشاركة'),
                          ),
                          if (mine)
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('تعديل'),
                            ),
                          if (mine && !collection.isDefault)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('حذف'),
                            ),
                        ];
                      },
                    ),
            ),
            Expanded(
              child: detail.when(
                loading: () => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: const [
                    ShimmerBox(height: 148, radius: VibesRadius.xl),
                    SizedBox(height: 14),
                    ShimmerBox(height: 220, radius: VibesRadius.xl),
                    SizedBox(height: 14),
                    ShimmerBox(height: 220, radius: VibesRadius.xl),
                  ],
                ),
                error: (e, _) => ErrorCanvas(
                  message: maisonError(e),
                  onRetry: () => ref.invalidate(collectionDetailProvider(id)),
                ),
                data: (collection) {
                  final mine =
                      collection.userId.isEmpty || collection.userId == userId;
                  return Column(
                    children: [
                      if (collection.coverUrl != null &&
                          collection.coverUrl!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                          child: ClipPath(
                            clipper: const ShapeBorderClipper(
                              shape: Folio.shape,
                            ),
                            child: VibesNetImage(
                              url: collection.coverUrl!,
                              height: 148,
                            ),
                          ),
                        ),
                      if (collection.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(collection.description),
                          ),
                        ),
                      Expanded(
                        child: collection.items.isEmpty
                            ? EmptyCanvas(
                                icon: Icons.bookmark_outline_rounded,
                                title: collection.name,
                                subtitle:
                                    'أضف أماكن إلى هذه القائمة من صفحة المكان',
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  8,
                                  20,
                                  28,
                                ),
                                itemCount: collection.items.length,
                                itemBuilder: (context, i) {
                                  final entry = collection.items[i];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Stack(
                                          children: [
                                            PropertyCard(
                                              property: entry.property,
                                              heroNamespace: 'col',
                                            ),
                                            if (mine)
                                              Positioned(
                                                top: 8,
                                                left: 8,
                                                child: IconButton.filledTonal(
                                                  onPressed: () => _removeItem(
                                                    context,
                                                    ref,
                                                    collection,
                                                    entry.property,
                                                  ),
                                                  icon: const Icon(
                                                    Icons.remove_circle_outline,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (mine || entry.note.isNotEmpty)
                                          Wrap(
                                            spacing: 4,
                                            children: [
                                              if (mine || entry.note.isNotEmpty)
                                                TextButton.icon(
                                                  onPressed: mine
                                                      ? () => _editNote(
                                                          context,
                                                          ref,
                                                          collection,
                                                          entry,
                                                        )
                                                      : null,
                                                  icon: const Icon(
                                                    Icons
                                                        .sticky_note_2_outlined,
                                                    size: 16,
                                                  ),
                                                  label: Text(
                                                    entry.note.isEmpty
                                                        ? 'أضف ملاحظة'
                                                        : entry.note,
                                                  ),
                                                ),
                                              if (mine &&
                                                  entry.property.coverUrl !=
                                                      null)
                                                TextButton.icon(
                                                  onPressed: () => _setCover(
                                                    ref,
                                                    collection,
                                                    entry.property,
                                                  ),
                                                  icon: Icon(
                                                    collection.coverUrl ==
                                                            entry
                                                                .property
                                                                .coverUrl
                                                        ? Icons
                                                              .check_box_outlined
                                                        : Icons.image_outlined,
                                                    size: 16,
                                                  ),
                                                  label: Text(
                                                    collection.coverUrl ==
                                                            entry
                                                                .property
                                                                .coverUrl
                                                        ? 'الغلاف الحالي'
                                                        : 'تعيين غلاف',
                                                  ),
                                                ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
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

class CollectionEntry {
  const CollectionEntry({required this.property, this.note = ''});

  final Property property;
  final String note;
}

class CollectionDetail {
  const CollectionDetail({
    required this.id,
    required this.name,
    this.description = '',
    this.items = const [],
    this.visibility = 'PRIVATE',
    this.isDefault = false,
    this.userId = '',
    this.coverUrl,
  });

  final String id;
  final String name;
  final String description;
  final List<CollectionEntry> items;
  final String visibility;
  final bool isDefault;
  final String userId;
  final String? coverUrl;

  List<Property> get properties => items.map((e) => e.property).toList();
}

final collectionDetailProvider =
    FutureProvider.family<CollectionDetail, String>((ref, id) async {
      final client = ref.watch(apiClientProvider);
      final data =
          await client.get('/api/collections/$id') as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>? ?? const [];
      final user = data['user'] as Map<String, dynamic>?;
      return CollectionDetail(
        id: data['id'] as String? ?? id,
        name: data['name'] as String? ?? 'قائمة',
        description: data['description'] as String? ?? '',
        visibility: data['visibility'] as String? ?? 'PRIVATE',
        isDefault: data['isDefault'] == true,
        userId: data['userId'] as String? ?? user?['id'] as String? ?? '',
        coverUrl: data['coverUrl'] as String?,
        items: items.whereType<Map<String, dynamic>>().map((item) {
          final property = item['property'];
          return CollectionEntry(
            property: property is Map<String, dynamic>
                ? Property.fromJson(property)
                : Property.fromJson(item),
            note: item['note'] as String? ?? '',
          );
        }).toList(),
      );
    });
