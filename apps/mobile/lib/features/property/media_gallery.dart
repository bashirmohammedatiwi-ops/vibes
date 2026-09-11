import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/vibes_widgets.dart';

/// ═══════════════════════════════════════════════════════════
/// المعرض — صور + فيديو + جولات 360° بترقيم أنيق
/// ═══════════════════════════════════════════════════════════

class MediaGallery extends StatefulWidget {
  const MediaGallery({super.key, required this.items, this.height = 300});

  final List<MediaItem> items;
  final double height;

  @override
  State<MediaGallery> createState() => _MediaGalleryState();
}

class _MediaGalleryState extends State<MediaGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: VibesMotion.slow,
        pageBuilder: (_, __, ___) => _GalleryFullscreen(
          items: widget.items,
          initialIndex: _index,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Container(
        height: widget.height,
        color: VibesTheme.surfaceHighOf(context),
        child: Icon(
          Icons.home_work_outlined,
          size: 52,
          color: VibesTheme.textTertiaryOf(context),
        ),
      );
    }

    return GestureDetector(
      onTap: _openFullscreen,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final media = widget.items[i];
              return _MediaPage(media: media);
            },
          ),

          // مؤشر الموضع — شريحة ذهبية رقيقة
          if (widget.items.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.items.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: VibesMotion.fast,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 6,
                    height: 4,
                    decoration: BoxDecoration(
                      color: active
                          ? GoldColors.gold
                          : Colors.white.withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),

          // عدّاد أنيق
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(VibesRadius.pill),
              ),
              child: Text(
                '${_index + 1} / ${widget.items.length}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaPage extends StatefulWidget {
  const _MediaPage({required this.media});

  final MediaItem media;

  @override
  State<_MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends State<_MediaPage> {
  VideoPlayerController? _video;

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  Future<void> _playVideo() async {
    if (_video != null) {
      await _video!.play();
      setState(() {});
      return;
    }
    final controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.media.url));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _video = controller);
      await controller.play();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر تشغيل الفيديو')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;

    if (media.kind == MediaKind.panorama) {
      // جولة 360° — سحب أفقي للنظر حول المكان
      return Stack(
        fit: StackFit.expand,
        children: [
          _PanoramaView(url: media.url),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                    border: Border.all(color: GoldColors.gold, width: 1),
                  ),
                  child: const Icon(Icons.threed_rotation_rounded,
                      color: GoldColors.gold, size: 30),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(VibesRadius.pill),
                  ),
                  child: Text(
                    'جولة 360° — اسحب للاستكشاف',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (media.isVideo) {
      return Stack(
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
          else if (media.posterUrl != null)
            CachedNetworkImage(
              imageUrl: media.posterUrl!,
              fit: BoxFit.cover,
            )
          else
            Container(color: VibesTheme.surfaceHighOf(context)),
          // زر تشغيل ذهبي
          Center(
            child: _video != null && _video!.value.isPlaying
                ? const SizedBox.shrink()
                : GestureDetector(
                    onTap: _playVideo,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .45),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: GoldColors.gold.withValues(alpha: .8),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: GoldColors.gold, size: 38),
                    ),
                  ),
          ),
        ],
      );
    }

    return CachedNetworkImage(
      imageUrl: media.url,
      fit: BoxFit.cover,
      fadeInDuration: VibesMotion.base,
      placeholder: (_, __) =>
          ShimmerBox(height: widget.media.height?.toDouble() ?? 200, radius: 0),
    );
  }
}

/// العرض الملء — صور بتكبير + فيديو + بانوراما
class _GalleryFullscreen extends StatelessWidget {
  const _GalleryFullscreen({required this.items, required this.initialIndex});

  final List<MediaItem> items;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    final controller = PageController(initialPage: initialIndex);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: controller,
            itemCount: items.length,
            itemBuilder: (context, i) {
              final media = items[i];
              if (media.isVideo) {
                return Center(
                  child: _FullscreenVideo(url: media.url),
                );
              }
              return PhotoView(
                imageProvider: CachedNetworkImageProvider(media.url),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2.4,
                heroAttributes: PhotoViewHeroAttributes(tag: 'media-${media.id}'),
              );
            },
          ),
          // إغلاق
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullscreenVideo extends StatefulWidget {
  const _FullscreenVideo({required this.url});

  final String url;

  @override
  State<_FullscreenVideo> createState() => _FullscreenVideoState();
}

class _FullscreenVideoState extends State<_FullscreenVideo> {
  late final VideoPlayerController _controller =
      VideoPlayerController.networkUrl(Uri.parse(widget.url));
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller.initialize().then((_) {
      if (mounted) {
        setState(() => _ready = true);
        _controller.play();
      }
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Text('تعذّر تشغيل الفيديو',
            style: TextStyle(color: Colors.white70)),
      );
    }
    if (!_ready) {
      return const Center(
        child: CircularProgressIndicator(color: GoldColors.gold),
      );
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: GestureDetector(
        onTap: () {
          if (_controller.value.isPlaying) {
            _controller.pause();
          } else {
            _controller.play();
          }
          setState(() {});
        },
        child: VideoPlayer(_controller),
      ),
    );
  }
}

/// عارض بانوراما بسيط وأنيق — صورة عريضة تُسحب أفقياً للنظر حول المكان.
/// بلا حزم خارجية: Physics مخصصة تجعل السحب دائرياً (يلف حول الصورة).
class _PanoramaView extends StatefulWidget {
  const _PanoramaView({required this.url});

  final String url;

  @override
  State<_PanoramaView> createState() => _PanoramaViewState();
}

class _PanoramaViewState extends State<_PanoramaView> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: widget.url,
      imageBuilder: (context, provider) {
        final image = Image(image: provider);
        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            if (!_controller.hasClients) return;
            final target =
                (_controller.offset - details.delta.dx * 1.6).clamp(
              0.0,
              _controller.position.maxScrollExtent,
            );
            _controller.jumpTo(target);
          },
          child: ListView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              AspectRatio(
                aspectRatio: 2.05, // بانوراما عريضة
                child: image,
              ),
            ],
          ),
        );
      },
      placeholder: (_, __) => const ColoredBox(color: Color(0xFF16181D)),
      errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFF16181D)),
    );
  }
}
