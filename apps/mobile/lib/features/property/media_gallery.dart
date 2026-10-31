import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/world_theme.dart';
import '../../core/utils/vibes_net_image.dart';
import '../../shared/models/models.dart';

/// ═══════════════════════════════════════════════════════════
/// المعرض — صور + فيديو + جولات 360° بترقيم أنيق
/// ═══════════════════════════════════════════════════════════

class MediaGallery extends StatefulWidget {
  const MediaGallery({
    super.key,
    required this.items,
    this.height = 300,
    this.bottomInset = 0,
  });

  final List<MediaItem> items;
  final double height;

  /// مسافة إضافية أسفل المؤشر والعدّاد (حين يُغطّى أسفل المعرض).
  final double bottomInset;

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
        pageBuilder: (_, __, ___) =>
            _GalleryFullscreen(items: widget.items, initialIndex: _index),
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

          // مؤشر الموضع — كبسولات بيضاء، النشطة أعرض بلون العالم
          if (widget.items.length > 1)
            Positioned(
              bottom: 16 + widget.bottomInset,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.items.length.clamp(0, 9), (i) {
                  final active = i == _index.clamp(0, 8);
                  return AnimatedContainer(
                    duration: VibesMotion.base,
                    curve: VibesMotion.curve,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: active
                          ? Colors.white
                          : Colors.white.withValues(alpha: .55),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: context.world.glow.withValues(alpha: .6),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                  );
                }),
              ),
            ),

          // عدّاد الصور — كبسولة زجاجية داكنة
          Positioned(
            bottom: 10 + widget.bottomInset,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .42),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: .2)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.photo_library_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${_index + 1}/${widget.items.length}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // شارة نوع الوسيط الحالي
          Positioned(
            bottom: 10 + widget.bottomInset,
            right: 14,
            child: Builder(
              builder: (context) {
                final kind = widget.items[_index];
                if (kind.kind == MediaKind.panorama) {
                  return _MediaChip(
                    icon: Icons.threed_rotation_rounded,
                    label: 'جولة 360°',
                  );
                }
                if (kind.isVideo) {
                  return _MediaChip(
                    icon: Icons.videocam_rounded,
                    label: 'فيديو',
                  );
                }
                return const SizedBox.shrink();
              },
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

  void _openFullscreenPano(BuildContext context, String url) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: VibesMotion.slow,
        pageBuilder: (_, __, ___) => _PanoramaFullscreen(url: url),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _playVideo() async {
    if (_video != null) {
      await _video!.play();
      setState(() {});
      return;
    }
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.media.playbackUrl),
    );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذّر تشغيل الفيديو')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;

    if (media.kind == MediaKind.panorama) {
      // جولة 360° — انجراف سينمائي، سحب للتحكم، ونقرة لملء الشاشة
      return Stack(
        fit: StackFit.expand,
        children: [
          _PanoramaView(
            url: media.url,
            onOpenFullscreen: () => _openFullscreenPano(context, media.url),
          ),
          // شريط تلميح سفلي أنيق يخبو بعد لحظة
          const Positioned(bottom: 34, left: 0, right: 0, child: _PanoHint()),
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
            VibesNetImage(url: media.posterUrl!, fit: BoxFit.cover)
          else
            Container(color: VibesTheme.surfaceHighOf(context)),
          // زر تشغيل ذهبي
          Center(
            child: _video != null && _video!.value.isPlaying
                ? const SizedBox.shrink()
                : GestureDetector(
                    onTap: _playVideo,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .45),
                        border: Border.all(
                          color: Vibes.coral.withValues(alpha: .8),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Vibes.coral,
                        size: 38,
                      ),
                    ),
                  ),
          ),
        ],
      );
    }

    return VibesNetImage(url: media.url, fit: BoxFit.cover);
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
                return Center(child: _FullscreenVideo(url: media.playbackUrl));
              }
              if (media.kind == MediaKind.panorama) {
                // بانوراما: ابدأ مغطية الشاشة ودور بحرية
                return PhotoView(
                  imageProvider: CachedNetworkImageProvider(
                    media.url,
                    cacheManager: VibesNetImage.cache,
                  ),
                  backgroundDecoration: const BoxDecoration(
                    color: Colors.black,
                  ),
                  initialScale: PhotoViewComputedScale.covered,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2.6,
                  enablePanAlways: true,
                  gaplessPlayback: true,
                );
              }
              return PhotoView(
                // 1440 يكفي للتكبير بوضوح، وأخف بكثير من الأصل
                imageProvider: CachedNetworkImageProvider(
                  sizedImageUrl(media.url, 1440),
                  cacheManager: VibesNetImage.cache,
                ),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2.4,
                heroAttributes: PhotoViewHeroAttributes(
                  tag: 'media-${media.id}',
                ),
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
                decoration: const BoxDecoration(color: Colors.black54),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 22,
                ),
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
    _controller
        .initialize()
        .then((_) {
          if (mounted) {
            setState(() => _ready = true);
            _controller.play();
          }
        })
        .catchError((_) {
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
        child: Text(
          'تعذّر تشغيل الفيديو',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    if (!_ready) {
      return Center(child: CircularProgressIndicator(color: Vibes.coral));
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

/// عارض 360° سينمائي — انجراف تلقائي حلقي بلا فواصل (ثلاث نسخ
/// من الصورة تعيد الضبط عند الحدود)، والسحب اليدوي يوقف
/// الانجراف مؤقتاً ثم يستأنف. ملء الشاشة يفتح تحكماً كاملاً.
class _PanoramaView extends StatefulWidget {
  const _PanoramaView({required this.url, this.onOpenFullscreen});

  final String url;
  final VoidCallback? onOpenFullscreen;

  @override
  State<_PanoramaView> createState() => _PanoramaViewState();
}

class _PanoramaViewState extends State<_PanoramaView>
    with SingleTickerProviderStateMixin {
  final _controller = ScrollController();
  late final Ticker _drift;
  Duration? _last;
  bool _holding = false;
  double _velocity = 14.0; // بكسل منطقي/ثانية — نظرة هادئة

  static const _copies = 3;

  @override
  void initState() {
    super.initState();
    final reduce = false;
    _drift = createTicker(_onTick);
    if (!reduce) _drift.start();
  }

  void _onTick(Duration elapsed) {
    final previous = _last;
    _last = elapsed;
    if (previous == null || _holding || !_controller.hasClients) return;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) return;
    final dt = (elapsed - previous).inMicroseconds / 1e6;
    final extent = _controller.position.maxScrollExtent;
    if (extent <= 0) return;
    var next = _controller.offset + dt * _velocity;
    // الحلقة: عند تجاوز النسخة الوسطى عد إلى بدايتها — القفز غير مرئي
    final one = extent / (_copies - 1);
    if (next >= one * 2) next -= one;
    _controller.jumpTo(next);
  }

  @override
  void dispose() {
    _drift.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: widget.url,
      memCacheWidth: VibesNetImage.decodeWidth(context),
      fadeInDuration: const Duration(milliseconds: 80),
      imageBuilder: (context, provider) {
        final image = Image(image: provider);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _holding = true,
          onHorizontalDragUpdate: (details) {
            if (!_controller.hasClients) return;
            final extent = _controller.position.maxScrollExtent;
            final one = extent / (_copies - 1);
            var target = (_controller.offset - details.delta.dx * 1.8).clamp(
              0.0,
              extent,
            );
            // اسمح باللف الدائري عند الطرفين
            if (target <= 0) target = one * 2 - 1;
            if (target >= extent) target = one + 1;
            _controller.jumpTo(target);
          },
          onHorizontalDragEnd: (_) {
            // استئناف الانجراف بعد لحظة من السكون
            Future<void>.delayed(const Duration(milliseconds: 1200), () {
              if (mounted) _holding = false;
            });
          },
          onTap: widget.onOpenFullscreen,
          child: ListView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < _copies; i++)
                AspectRatio(aspectRatio: 2.05, child: image),
            ],
          ),
        );
      },
      placeholder: (_, __) => const ColoredBox(color: VibesDark.canvas),
      errorWidget: (_, __, ___) => const ColoredBox(color: VibesDark.canvas),
    );
  }
}

/// ملء الشاشة البانورامي — PhotoView بحجم الصورة الطبيعي:
/// تبدأ مغطية للشاشة فتُرى كأنك داخل المكان، والسحب يدور بك
/// بحرية، والقرص يقرّب، والنقر المزدوج يبدّل التقريب.
class _PanoramaFullscreen extends StatefulWidget {
  const _PanoramaFullscreen({required this.url});

  final String url;

  @override
  State<_PanoramaFullscreen> createState() => _PanoramaFullscreenState();
}

class _PanoramaFullscreenState extends State<_PanoramaFullscreen> {
  bool _hintVisible = true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) setState(() => _hintVisible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PhotoView(
            imageProvider: CachedNetworkImageProvider(widget.url),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            initialScale: PhotoViewComputedScale.covered,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2.6,
            enablePanAlways: true,
            gaplessPlayback: true,
          ),
          // إغلاق
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: Colors.black54),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 22,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _hintVisible ? 1 : 0,
              duration: VibesMotion.slow,
              child: const _PanoHint(),
            ),
          ),
        ],
      ),
    );
  }
}

/// شريط تلميح البانوراما — زجاجي بإطار نحاسي يرشد للتحكم
class _PanoHint extends StatelessWidget {
  const _PanoHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipPath(
        clipper: const ShapeBorderClipper(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(9),
              topRight: Radius.circular(3),
              bottomRight: Radius.circular(9),
              bottomLeft: Radius.circular(8),
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .55),
            border: Border.all(color: Vibes.teal.withValues(alpha: .5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.threed_rotation_rounded,
                size: 15,
                color: Vibes.tealBright,
              ),
              const SizedBox(width: 8),
              Text(
                'جولة 360° — اسحب للدوران · انقر لتكبير',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
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

/// شارة نوع الوسيط — زجاجية فوق المعرض
class _MediaChip extends StatelessWidget {
  const _MediaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const ShapeBorderClipper(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(7)),
        ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: const BoxDecoration(color: Color(0x61000000)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
