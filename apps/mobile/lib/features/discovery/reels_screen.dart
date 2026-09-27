import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/vibes_net_image.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../social/experiences_screen.dart';

/// ═══════════════════════════════════════════════════════════
/// الاستكشاف — تدفّق ريلز عمودي غامر بفيديوهات 9:16
/// ملء الشاشة + شريط جانبي زجاجي + حجز ياقوتي فوق المحتوى
/// ═══════════════════════════════════════════════════════════

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final _controller = PageController();
  int _index = 0;
  bool _experiences = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reels = reelsProvider;

    return Scaffold(
      backgroundColor: _experiences ? null : VibesDark.canvas,
      body: Stack(
        children: [
          Positioned.fill(
            child: _experiences
                ? const ExperiencesScreen(embedded: true)
                : Consumer(
                    builder: (context, ref, _) {
                      final items = ref.watch(reels);

                      return items.when(
                        loading: () => _reelsSkeleton(context),
                        error: (e, _) => ErrorCanvas(
                          message: e.toString().contains('الاتصال')
                              ? 'لا اتصال بالإنترنت — تحقق من الشبكة'
                              : maisonError(e),
                          onRetry: () => ref.invalidate(reels),
                        ),
                        data: (list) {
                          if (list.isEmpty) return const _PlaceDiscover();

                          return PageView.builder(
                            controller: _controller,
                            scrollDirection: Axis.vertical,
                            itemCount: list.length,
                            onPageChanged: (i) => setState(() => _index = i),
                            itemBuilder: (context, i) {
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
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  const VibesLogo.mark(size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'استكشف',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _experiences ? VibesTheme.textPrimaryOf(context) : Colors.white,
                      height: 1,
                    ),
                  ),
                  const Spacer(),
                  _ModeTab(
                    label: 'جولات',
                    active: !_experiences,
                    light: !_experiences,
                    onTap: () => setState(() => _experiences = false),
                  ),
                  const SizedBox(width: 14),
                  _ModeTab(
                    label: 'تجارب',
                    active: _experiences,
                    light: !_experiences,
                    onTap: () => setState(() => _experiences = true),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reelsSkeleton(BuildContext context) {
    return const ColoredBox(
      color: VibesDark.canvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 180, height: 22, radius: 8),
                  SizedBox(height: 10),
                  ShimmerBox(width: 120, height: 14, radius: 6),
                  SizedBox(height: 16),
                  ShimmerBox(width: 96, height: 40, radius: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceDiscover extends ConsumerStatefulWidget {
  const _PlaceDiscover();

  @override
  ConsumerState<_PlaceDiscover> createState() => _PlaceDiscoverState();
}

class _PlaceDiscoverState extends ConsumerState<_PlaceDiscover> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final places = ref.watch(propertiesProvider(null));
    return places.when(
      loading: () => const ColoredBox(color: VibesDark.canvas),
      error: (e, _) => ErrorCanvas(
        message: maisonError(e),
        onRetry: () => ref.invalidate(propertiesProvider(null)),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyCanvas(
            icon: Icons.explore_outlined,
            title: 'لا أماكن بعد',
            subtitle: 'ستظهر هنا الجولات حالما تُنشر الأماكن',
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: list.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => _PlaceSlide(property: list[i]),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 52,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '${_index + 1}  /  ${list.length}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlaceSlide extends StatelessWidget {
  const _PlaceSlide({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    final cover = property.coverUrl;
    final kicker = property.type == PropertyType.hall
        ? 'قاعة أعراس'
        : property.typeLabelAr;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (cover != null)
          VibesNetImage(url: cover, fit: BoxFit.cover)
        else
          const ColoredBox(color: VibesDark.canvas),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, .45, 1],
              colors: [Color(0x660F2138), Color(0x00000000), Color(0xE60F2138)],
            ),
          ),
        ),
        const Positioned.fill(child: PlateCorners(inset: 16, arm: 18)),
        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                kicker,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Vibes.tealBright,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                property.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      [
                        property.cityName ?? '',
                        if (property.capacity > 0) '${property.capacity} ضيف',
                      ].where((s) => s.isNotEmpty).join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  PriceText(property.pricePerDay, compact: true, onDark: true),
                  const SizedBox(width: 12),
                  VibesButton(
                    label: 'المكان',
                    small: true,
                    expanded: false,
                    onPressed: () => context.push('/property/${property.id}'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.active,
    required this.light,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool light;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: VibesMotion.fast,
        curve: VibesMotion.curve,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active
                  ? Vibes.tealBright
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: light
                ? (active ? Colors.white : Colors.white70)
                : (active
                    ? VibesTheme.textPrimaryOf(context)
                    : VibesTheme.textTertiaryOf(context)),
          ),
        ),
      ),
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
      await controller.setVolume(0);
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

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
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
                : const ColoredBox(color: VibesDark.canvas))
          else
            CachedNetworkImage(
              imageUrl: property.coverUrl ?? '',
              fit: BoxFit.cover,
              errorWidget: (_, _, _) =>
                  const ColoredBox(color: VibesDark.canvas),
            ),

          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, .42, 1],
                  colors: [
                    Color(0x8A0F2138),
                    Colors.transparent,
                    Color(0xE00F2138),
                  ],
                ),
              ),
            ),
          ),

          if (_video != null)
            Center(
              child: GestureDetector(
                onTap: _togglePlay,
                child: AnimatedOpacity(
                  duration: VibesMotion.base,
                  opacity: _video!.value.isPlaying ? 0 : 1,
                  child: FolioPanel(
                    color: Colors.black38,
                    borderColor: Colors.white24,
                    child: const SizedBox(
                      width: 72,
                      height: 72,
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          if (_video != null)
            Positioned(
              bottom: 0,
              right: 0,
              left: 0,
              child: _ProgressStrip(controller: _video!),
            ),

          Positioned(
            bottom: 118,
            left: 12,
            child: Column(
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final fav = ref.watch(favoritesProvider);
                    final isFav =
                        fav.valueOrNull?.any((p) => p.id == property.id) ??
                        false;
                    return _GlassAction(
                      icon: isFav
                          ? Icons.favorite_rounded
                          : Icons.favorite_outline_rounded,
                      highlighted: isFav,
                      onTap: () =>
                          ref.read(favoritesProvider.notifier).toggle(property),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _GlassAction(
                  icon: _video?.value.volume == 0
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  onTap: () {
                    final v = _video;
                    if (v != null) {
                      v.setVolume(v.value.volume == 0 ? 1 : 0);
                      setState(() {});
                    }
                  },
                ),
                const SizedBox(height: 12),
                _GlassAction(
                  icon: Icons.ios_share_rounded,
                  onTap: () =>
                      Share.share('${property.name} — اكتشفها على تطبيق VIBEES'),
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 0,
            right: 0,
            left: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 72, 16),
              child:
                  Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            property.type == PropertyType.hall
                                ? 'قاعة أعراس'
                                : property.typeLabelAr,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Vibes.tealBright,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            property.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.15,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Text(
                                  [
                                    property.cityName ?? '',
                                    if (property.capacity > 0)
                                      '${property.capacity} ضيف',
                                  ].where((s) => s.isNotEmpty).join('  ·  '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: Colors.white70),
                                ),
                              ),
                              PriceText(
                                property.pricePerDay,
                                compact: true,
                                onDark: true,
                              ),
                              const SizedBox(width: 10),
                              VibesButton(
                                label: 'المكان',
                                small: true,
                                expanded: false,
                                onPressed: () =>
                                    context.push('/property/${property.id}'),
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
    );
  }
}

class _GlassAction extends StatelessWidget {
  const _GlassAction({
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: FolioPanel(
        color: highlighted ? Vibes.teal : const Color(0xCC0F2138),
        borderColor: highlighted
            ? Vibes.tealBright
            : Colors.white.withValues(alpha: .28),
        radius: Folio.compact,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            color: highlighted ? VibesDark.onCoral : Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

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
          valueColor: const AlwaysStoppedAnimation(Vibes.tealBright),
        );
      },
    );
  }
}
