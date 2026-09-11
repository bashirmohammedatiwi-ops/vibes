
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/vibes_widgets.dart';

/// ═══════════════════════════════════════════════════════════
/// الاستكشاف — تدفّق ريلز عمودي غامر بفيديوهات 9:16
/// واجهة شفافة نصف ذائبة وزر حجز ذهبي فوق المحتوى
/// ═══════════════════════════════════════════════════════════

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final _controller = PageController(viewportFraction: 0.96);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reels = reelsProvider;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        forceMaterialTransparency: true,
        title: Text(
          'الاستكشاف',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
        ),
      ),
      body: Consumer(
        builder: (context, ref, _) {
          final items = ref.watch(reels);

          return items.when(
            loading: () => _reelsSkeleton(context),
            error: (e, _) => ErrorCanvas(
              message: e.toString(),
              onRetry: () => ref.invalidate(reels),
            ),
            data: (list) {
              if (list.isEmpty) {
                return EmptyCanvas(
                  icon: Icons.play_circle_outline_rounded,
                  title: 'لا فيديوهات بعد',
                  subtitle:
                      'ستظهر هنا جولات الفيديو للأماكن — تصفّح الأقسام الأخرى بالأثناء',
                );
              }

              return PageView.builder(
                controller: _controller,
                scrollDirection: Axis.vertical,
                itemCount: list.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  // تحسين الذاكرة: بناء المشاهد المجاورة فقط
                  final active = (i - _index).abs() <= 1;
                  return _ReelPage(
                    item: list[i],
                    play: active && i == _index,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _reelsSkeleton(BuildContext context) {
    return Column(
      children: List.generate(2, (i) {
        return Padding(
          padding: const EdgeInsets.all(8),
          child: ShimmerBox(
            height: MediaQuery.of(context).size.height * .44,
            radius: VibesRadius.xl,
          ),
        );
      }),
    );
  }
}

class _ReelPage extends StatefulWidget {
  const _ReelPage({required this.item, required this.play});

  final ReelItem item;
  final bool play;

  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage> {
  VideoPlayerController? _video;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.play) _initVideo();
  }

  @override
  void didUpdateWidget(covariant _ReelPage old) {
    super.didUpdateWidget(old);
    if (widget.play != old.play) {
      if (widget.play) {
        _initVideo();
      } else {
        _video?.pause();
      }
    }
  }

  Future<void> _initVideo() async {
    if (_video != null || _failed || !widget.item.media.isVideo) return;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.item.media.url),
    );
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0); // صامت تلقائياً
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _video = controller);
      await controller.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
      await controller.dispose();
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final v = _video;
    if (v == null) return;
    if (v.value.isPlaying) {
      v.pause();
    } else {
      v.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final property = widget.item.property;
    final media = widget.item.media;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(VibesRadius.xl),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // الخلفية — فيديو أو صورة
            if (_video != null && _video!.value.isInitialized)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _video!.value.size.width,
                  height: _video!.value.size.height,
                  child: VideoPlayer(_video!),
                ),
              )
            else if (media.isVideo && !_failed)
              (media.posterUrl != null
                  ? CachedNetworkImage(
                      imageUrl: media.posterUrl!,
                      fit: BoxFit.cover,
                    )
                  : const SizedBox.expand())
            else
              CachedNetworkImage(
                imageUrl: property.coverUrl ?? '',
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: InkColors.canvasHigh,
                ),
              ),

            // فيلات التعتيم للقراءة — تدرجات سفلية وعلوية هادئة
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, .45, 1],
                    colors: [
                      Colors.black.withValues(alpha: .35),
                      Colors.transparent,
                      Colors.black.withValues(alpha: .72),
                    ],
                  ),
                ),
              ),
            ),

            // زر تشغيل/إيقاف بمنتصف الشاشة
            if (_video != null)
              Center(
                child: GestureDetector(
                  onTap: _togglePlay,
                  child: AnimatedOpacity(
                    duration: VibesMotion.base,
                    opacity: _video!.value.isPlaying ? 0 : 1,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 40),
                    ),
                  ),
                ),
              ),

            // شريط التقدم الذهبي الرفيع
            if (_video != null)
              Positioned(
                bottom: 0,
                right: 0,
                left: 0,
                child: _ProgressStrip(controller: _video!),
              ),

            // شريط الأزرار الجانبي — قلب ومشاركة
            Positioned(
              bottom: 110,
              left: 12,
              child: Column(
                children: [
                  Consumer(
                    builder: (context, ref, _) {
                      final fav =
                          ref.watch(favoritesProvider);
                      final isFav = fav.value?.any(
                              (p) => p.id == property.id) ??
                          false;
                      return FavoriteHeart(
                        active: isFav,
                        size: 22,
                        onToggle: (_) => ref
                            .read(favoritesProvider.notifier)
                            .toggle(property),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _SideAction(
                    icon: Icons.ios_share_rounded,
                    onTap: () => Share.share(
                      '${property.name} — اكتشفها على تطبيق VIBES',
                    ),
                  ),
                ],
              ),
            ),

            // لوحة المعلومات السفلية — نصف ذائبة
            Positioned(
              bottom: 0,
              right: 0,
              left: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 76, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      property.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        property.typeLabelAr,
                        property.cityName ?? '',
                        if (property.ratingCount > 0)
                          '★ ${property.ratingAvg.toStringAsFixed(1)}'
                      ].where((s) => s.isNotEmpty).join('  ·  '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'يبدأ من  ',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.white60,
                                  ),
                        ),
                        PriceText(property.pricePerDay, compact: true),
                        const Spacer(),
                        SizedBox(
                          height: 40,
                          child: VibesButton(
                            label: 'احجز الآن',
                            small: true,
                            expanded: false,
                            onPressed: () =>
                                context.push('/property/${property.id}'),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
                    .animate(delay: VibesMotion.stagger)
                    .fadeIn(duration: VibesMotion.slow)
                    .slideY(
                      begin: .08,
                      end: 0,
                      duration: VibesMotion.slow,
                      curve: VibesMotion.curve,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideAction extends StatelessWidget {
  const _SideAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: const BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

/// شريط تقدم رفيع ذهبي أسفل الفيديو
class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final value = controller.value.duration.inMilliseconds == 0
            ? 0.0
            : controller.value.position.inMilliseconds /
                controller.value.duration.inMilliseconds;
        return LinearProgressIndicator(
          value: value,
          minHeight: 2.5,
          backgroundColor: Colors.white12,
          valueColor: const AlwaysStoppedAnimation(GoldColors.gold),
        );
      },
    );
  }
}
