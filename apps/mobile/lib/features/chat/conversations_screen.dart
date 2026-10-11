import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../shared/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/marketplace_providers.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../../core/theme/world_theme.dart';
import '../../shared/widgets/world_ui.dart';
import '../../core/utils/vibes_net_image.dart';
import '../auth/auth_controller.dart';
import 'call_screen.dart';

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(maisonError(e))));
  }
}

bool _isMineBy(String? myId, ConversationSummary c) =>
    myId != null && c.lastMessageSenderId == myId;

String _relative(DateTime at) {
  final diff = DateTime.now().difference(at);
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) return '${diff.inMinutes} د';
  if (diff.inHours < 24) return '${diff.inHours} س';
  final days = diff.inDays;
  if (days == 1) return 'أمس';
  if (days < 7) return '$days أيام';
  return '${at.day}/${at.month}';
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
    final myId = ref.watch(authControllerProvider).user?.id;
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
                    tooltip: 'دعم VIBES',
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
                    WorldSkeleton(height: 86, radius: 20),
                    SizedBox(height: 10),
                    WorldSkeleton(height: 86, radius: 20),
                    SizedBox(height: 10),
                    WorldSkeleton(height: 86, radius: 20),
                  ],
                ),
                error: (e, _) => ErrorCanvas(
                  message: maisonError(e),
                  onRetry: () => ref.invalidate(conversationsProvider),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: WorldEmpty(
                        icon: Icons.forum_outlined,
                        title: 'لا رسائل بعد',
                        subtitle: 'ستظهر هنا محادثات حجوزاتك مع المضيفين',
                        actionLabel: 'راسل الدعم',
                        onAction: () => openSupportChat(context, ref),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: context.world.accent,
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
                        return SurfaceListCard(
                          accent: c.unread > 0 ? context.world.accent : null,
                          highlighted: c.unread > 0,
                          onTap: () => context.push('/chat/${c.id}'),
                          child: Row(
                            children: [
                              // أفاتار بحلقة نحاسية للغير مقروء
                              Container(
                                width: 52,
                                height: 52,
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: c.unread > 0
                                      ? context.world.fill
                                      : null,
                                  border: c.unread > 0
                                      ? null
                                      : Border.all(
                                          color: context.world.accent
                                              .withValues(alpha: .15),
                                        ),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: context.world.canvasTint,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: c.kind == 'SUPPORT'
                                      ? Icon(
                                          Icons.support_agent_rounded,
                                          color: context.world.accentDeep,
                                          size: 24,
                                        )
                                      : Text(
                                          c.title.trim().isEmpty
                                              ? 'م'
                                              : c.title.trim().substring(0, 1),
                                          style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 19,
                                            fontWeight: FontWeight.w900,
                                            color: context.world.accentDeep,
                                          ),
                                        ),
                                ),
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
                                              color: context.world.accentDeep,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    if (c.updatedAt != null)
                                      Text(
                                        _relative(c.updatedAt!),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: VibesTheme.textTertiaryOf(
                                                context,
                                              ),
                                              fontSize: 10,
                                            ),
                                      ),
                                    if (c.lastMessage != null)
                                      Row(
                                        children: [
                                          // اتجاه المكالمة في سطر المعاينة
                                          if (c.lastMessageKind == 'CALL') ...[
                                            Icon(
                                              Icons.call_rounded,
                                              size: 12,
                                              color:
                                                  (c.lastMessage ?? '')
                                                      .contains('لم يُرد')
                                                  ? SemanticColors.danger
                                                  : context.world.accentDeep,
                                            ),
                                            const SizedBox(width: 4),
                                          ],
                                          if (_isMineBy(myId, c) &&
                                              c.lastMessageKind != 'CALL') ...[
                                            Text(
                                              'أنت: ',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: context
                                                        .world
                                                        .accentDeep,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                          ],
                                          Expanded(
                                            child: Text(
                                              c.lastMessage!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        VibesTheme.textTertiaryOf(
                                                          context,
                                                        ),
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                              // اتصال مباشر من القائمة — بلا فتح المحادثة
                              GestureDetector(
                                onTap: () => startCall(
                                  ref,
                                  context,
                                  conversationId: c.id,
                                ),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  margin: const EdgeInsetsDirectional.only(
                                    end: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.world.accentFaint,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.call_rounded,
                                    size: 18,
                                    color: context.world.accentDeep,
                                  ),
                                ),
                              ),
                              if (c.unread > 0)
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: context.world.fill,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      '${c.unread}',
                                      style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        color: context.world.onAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
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
