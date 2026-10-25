import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/moderation/moderation.dart';
import '../../core/network/api_client.dart';
import '../auth/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/vibes_net_image.dart';
import '../../shared/data/marketplace_providers.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_editorial.dart';
import '../../shared/widgets/vibes_widgets.dart';

class ExperiencesScreen extends ConsumerStatefulWidget {
  const ExperiencesScreen({super.key, this.embedded = false, this.highlightId});

  final bool embedded;
  final String? highlightId;

  @override
  ConsumerState<ExperiencesScreen> createState() => _ExperiencesScreenState();
}

class _ExperiencesScreenState extends ConsumerState<ExperiencesScreen> {
  bool _followingOnly = false;

  /// الزائر يُطلب منه الدخول أولاً — لا أزرار صامتة.
  Future<bool> _requireLogin() async {
    if (ref.read(authControllerProvider).user != null) return true;
    final ok = await context.push<bool>('/login');
    return ok == true && ref.read(authControllerProvider).user != null;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _comment(SocialExperience post) async {
    if (!await _requireLogin() || !mounted) return;
    final controller = TextEditingController();
    List<Map<String, dynamic>> rows;
    try {
      final comments = await ref
          .read(apiClientProvider)
          .get('/api/social/posts/${post.id}/comments');
      final mod = ref.read(moderationProvider);
      rows = (comments as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .where(
            (r) => !mod.shouldHide(
              'COMMENT',
              r['id']?.toString(),
              userId: r['userId']?.toString(),
            ),
          )
          .toList();
    } catch (e) {
      controller.dispose();
      _toast(maisonError(e));
      return;
    }
    if (!mounted) {
      controller.dispose();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VibesTheme.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(12),
        ),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MaisonSheetHandle(),
            Row(
              children: [
                const CrestSeal(size: 22, color: Vibes.coral),
                const SizedBox(width: 10),
                Text(
                  'تعليقات',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                const ArcFlourish(width: 24),
              ],
            ),
            const SizedBox(height: 14),
            if (rows.isEmpty)
              Text(
                'كن أول من يعلّق',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: VibesTheme.textSecondaryOf(context),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * .45,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final row in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: FolioPanel(
                          color: VibesTheme.surfaceHighOf(context),
                          borderColor: Colors.transparent,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              12,
                              4,
                              0,
                              4,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${row['user'] is Map ? row['user']['name'] ?? 'ضيف' : 'ضيف'}: ${row['body'] ?? ''}',
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'إبلاغ أو حظر',
                                  icon: const Icon(Icons.more_horiz, size: 20),
                                  onPressed: () async {
                                    final hidden = await showModerationSheet(
                                      context,
                                      ref,
                                      type: 'COMMENT',
                                      targetId: row['id'].toString(),
                                      userId: row['userId']?.toString(),
                                      userName: row['user'] is Map
                                          ? row['user']['name']?.toString()
                                          : null,
                                    );
                                    if (hidden && context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            MaisonField(
              label: 'تعليق',
              controller: controller,
              hint: 'اكتب تعليقاً',
            ),
            const SizedBox(height: 12),
            VibesButton(
              label: 'إرسال',
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                try {
                  await ref
                      .read(apiClientProvider)
                      .post(
                        '/api/social/posts/${post.id}/comments',
                        body: {'body': text},
                      );
                } catch (e) {
                  _toast(maisonError(e));
                  return;
                }
                ref.invalidate(experiencesProvider);
                ref.invalidate(followingExperiencesProvider);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _report(SocialExperience post) async {
    await showModerationSheet(
      context,
      ref,
      type: 'POST',
      targetId: post.id,
      userId: post.authorId,
      userName: post.authorName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(
      _followingOnly ? followingExperiencesProvider : experiencesProvider,
    );
    final feedBody = Expanded(
      child: feed.when(
        loading: () => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: const [
            ShimmerBox(height: 260, radius: VibesRadius.xl),
            SizedBox(height: 14),
            ShimmerBox(height: 220, radius: VibesRadius.xl),
          ],
        ),
        error: (e, _) => ErrorCanvas(
          message: maisonError(e),
          onRetry: () {
            ref.invalidate(experiencesProvider);
            ref.invalidate(followingExperiencesProvider);
          },
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyCanvas(
              icon: Icons.auto_awesome_outlined,
              title: _followingOnly ? 'لا تجارب من المتابَعين' : 'لا تجارب بعد',
              subtitle: _followingOnly
                  ? 'تابع مالكين لتظهر تجارب ضيوفهم هنا'
                  : 'انشر تجربتك بعد اكتمال الحجز لتظهر هنا',
            );
          }
          final mod = ref.watch(moderationProvider);
          final posts = [
            for (final p in list)
              if (!mod.shouldHide('POST', p.id, userId: p.authorId)) p,
          ];
          final highlightId = widget.highlightId;
          if (highlightId != null && highlightId.isNotEmpty) {
            posts.sort((a, b) {
              if (a.id == highlightId) return -1;
              if (b.id == highlightId) return 1;
              return 0;
            });
          }
          return RefreshIndicator(
            color: Vibes.teal,
            onRefresh: () async {
              ref.invalidate(experiencesProvider);
              ref.invalidate(followingExperiencesProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              itemCount: posts.length,
              itemBuilder: (context, i) {
                final post = posts[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _ExperienceCard(
                    post: post,
                    featured: widget.highlightId == post.id,
                    onLike: () async {
                      if (!await _requireLogin()) return;
                      try {
                        await ref
                            .read(apiClientProvider)
                            .post('/api/social/posts/${post.id}/like');
                      } catch (e) {
                        _toast(maisonError(e));
                        return;
                      }
                      ref.invalidate(experiencesProvider);
                      ref.invalidate(followingExperiencesProvider);
                    },
                    onComment: () => _comment(post),
                    onReport: () => _report(post),
                  ),
                );
              },
            ),
          );
        },
      ),
    );

    final chip = MaisonChip(
      label: _followingOnly ? 'الكل' : 'المتابَعون',
      active: _followingOnly,
      onTap: () => setState(() => _followingOnly = !_followingOnly),
    );

    final column = Column(
      children: [
        if (!widget.embedded)
          MaisonPageHeader(
            title: 'تجارب الضيوف',
            kicker: 'من عاش المكان',
            onBack: () => context.pop(),
            trailing: chip,
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const EditorialEyebrow(
                        label: 'ضيوف VIBES',
                        accent: Vibes.coral,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'تجارب حقيقية',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                chip,
              ],
            ),
          ),
        feedBody,
      ],
    );

    if (widget.embedded) {
      return MaisonWash(child: column);
    }
    return Scaffold(body: MaisonWash(child: column));
  }
}

class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard({
    required this.post,
    required this.featured,
    required this.onLike,
    required this.onComment,
    required this.onReport,
  });

  final SocialExperience post;
  final bool featured;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final accent = featured ? Vibes.teal : Vibes.coral;
    return Container(
      decoration: editorialCardShell(context, accent: accent),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.mediaUrls.isNotEmpty)
            GestureDetector(
              onDoubleTap: onLike,
              child: VibesNetImage(
                url: post.mediaUrls.first,
                height: 220,
                width: double.infinity,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        size: 20,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.authorName ?? 'ضيف VIBES',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'تجربة ضيف',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: VibesTheme.textTertiaryOf(context),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (post.propertyId != null)
                      Flexible(
                        child: MaisonSoftChip(
                          label: post.propertyName ?? 'المكان',
                        ),
                      ),
                  ],
                ),
                if (post.caption.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(post.caption),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Action(
                      icon: post.liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      label: '${post.likesCount}',
                      color: post.liked ? Vibes.mapple : Vibes.coral,
                      onTap: onLike,
                    ),
                    const SizedBox(width: 8),
                    _Action(
                      icon: Icons.mode_comment_outlined,
                      label: '${post.commentsCount}',
                      onTap: onComment,
                    ),
                    if (post.propertyId != null) ...[
                      const SizedBox(width: 8),
                      _Action(
                        icon: Icons.home_work_outlined,
                        label: 'المكان',
                        onTap: () =>
                            context.push('/property/${post.propertyId}'),
                      ),
                    ],
                    const Spacer(),
                    IconButton(
                      onPressed: onReport,
                      tooltip: 'إبلاغ أو حظر',
                      icon: const Icon(Icons.more_horiz, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? VibesTheme.textSecondaryOf(context);
    return GestureDetector(
      onTap: onTap,
      child: FolioPanel(
        color: tint.withValues(alpha: .08),
        borderColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: tint),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: tint,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
