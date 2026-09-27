import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/marketplace_providers.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../../core/utils/vibes_net_image.dart';

Future<void> openSupportChat(BuildContext context, WidgetRef ref) async {
  try {
    final data = await ref
        .read(apiClientProvider)
        .post('/api/conversations/support');
    final id = (data as Map<String, dynamic>)['id'] as String?;
    if (!context.mounted || id == null) return;
    ref.invalidate(conversationsProvider);
    context.push('/chat/$id');
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(maisonError(e))));
  }
}

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  Timer? _poll;
  int _ticks = 0;
  int? _lastUnread;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 12), (_) async {
      if (!mounted || !isAppResumed) return;
      _ticks++;
      try {
        final data = await ref
            .read(apiClientProvider)
            .get('/api/conversations/unread');
        final unread = data is Map ? (data['unread'] as num?)?.toInt() ?? 0 : 0;
        final changed = _lastUnread != null && unread != _lastUnread;
        _lastUnread = unread;
        if (changed || _ticks % 3 == 0) {
          ref.invalidate(conversationsProvider);
        }
        ref.invalidate(conversationsUnreadProvider);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(conversationsProvider);
    return Scaffold(
      body: MaisonWash(
        child: Column(
          children: [
            MaisonPageHeader(
              title: 'الرسائل',
              kicker: 'محادثاتك',
              onBack: () => context.pop(),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'قراءة الكل',
                    onPressed: () async {
                      await ref
                          .read(apiClientProvider)
                          .patch('/api/conversations/read');
                      ref.invalidate(conversationsProvider);
                      ref.invalidate(conversationsUnreadProvider);
                    },
                    icon: const Icon(Icons.done_all_rounded),
                  ),
                  IconButton(
                    tooltip: 'دعم VIBEES',
                    onPressed: () => openSupportChat(context, ref),
                    icon: const Icon(Icons.support_agent_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: list.when(
                loading: () => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: const [
                    ShimmerBox(height: 86, radius: VibesRadius.md),
                    SizedBox(height: 10),
                    ShimmerBox(height: 86, radius: VibesRadius.md),
                    SizedBox(height: 10),
                    ShimmerBox(height: 86, radius: VibesRadius.md),
                  ],
                ),
                error: (e, _) => ErrorCanvas(
                  message: maisonError(e),
                  onRetry: () => ref.invalidate(conversationsProvider),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return EmptyCanvas(
                      icon: Icons.forum_outlined,
                      title: 'لا رسائل بعد',
                      subtitle: 'ستظهر هنا محادثات حجوزاتك مع المالك',
                      action: VibesButton(
                        label: 'راسل الدعم',
                        small: true,
                        expanded: false,
                        onPressed: () => openSupportChat(context, ref),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: Vibes.teal,
                    onRefresh: () async =>
                        ref.invalidate(conversationsProvider),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final c = items[i];
                        return FolioPanel(
                          railColor: c.unread > 0 ? Vibes.teal : null,
                          shadows: Vibes.card,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => context.push('/chat/${c.id}'),
                              customBorder: Folio.shape,
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                            children: [
                              MaisonIconWell(
                                icon: c.kind == 'SUPPORT'
                                    ? Icons.support_agent_rounded
                                    : Icons.chat_bubble_outline_rounded,
                                color: Vibes.coral,
                                background: Vibes.surface,
                                size: 44,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    if (c.stage != null)
                                      Text(
                                        c.stage!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Vibes.teal,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    if (c.lastMessage != null)
                                      Text(
                                        c.lastMessage!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
                              if (c.unread > 0)
                                DecoratedBox(
                                  decoration: const ShapeDecoration(
                                    color: Vibes.coral,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: Folio.compact,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      '${c.unread}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                              ),
                            ),
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
