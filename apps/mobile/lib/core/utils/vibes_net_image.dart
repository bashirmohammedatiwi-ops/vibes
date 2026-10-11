import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../theme/app_theme.dart';
import 'data_saver.dart';

/// مدير قرص مخصص للوسائط — 30 يوماً و500 ملف،
/// يُشارك عبر كل صور التطبيق فلا تُنزّل الصورة نفسها مرتين أبداً.
class VibesImageCacheManager extends CacheManager with ImageCacheManager {
  VibesImageCacheManager()
    : super(
        Config(
          'vibesMediaCache_v2',
          stalePeriod: const Duration(days: 30),
          maxNrOfCacheObjects: 800,
          repo: JsonCacheInfoRepository(databaseName: 'vibesMediaCache_v2'),
          fileService: HttpFileService(),
        ),
      );
}

/// يحوّل رابط الصورة إلى نسخة تناسب العرض: 480 أو 960 بكسل.
/// صور الخادم تُخدم من /media/w480 و /media/w960، وصور Unsplash تُطلب بعرض أصغر.
String sizedImageUrl(String url, int bucket) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return url;
  final safeBucket = bucket <= 480 ? 480 : 960;
  final host = uri.host;

  if (host.contains('unsplash.com')) {
    final query = Map<String, String>.from(uri.queryParameters);
    query['w'] = '$safeBucket';
    query['q'] = '60';
    query.remove('h');
    return uri.replace(queryParameters: query).toString();
  }

  final segments = uri.pathSegments;
  if (segments.length < 2) return url;
  final parent = segments[segments.length - 2];
  if (parent.startsWith('w') && parent.length <= 5) return url;
  if (parent != 'media') return url;
  final file = segments.last;
  final lower = file.toLowerCase();
  if (!lower.endsWith('.jpg') &&
      !lower.endsWith('.jpeg') &&
      !lower.endsWith('.png') &&
      !lower.endsWith('.webp')) {
    return url;
  }
  final next = [
    ...segments.sublist(0, segments.length - 1),
    'w$safeBucket',
    file,
  ];
  return uri.replace(pathSegments: next).toString();
}

/// صورة شبكة تُطلب بمقاس العرض، وتُفكّ بنفس المقاس لا بدقة المصدر.
class VibesNetImage extends StatefulWidget {
  const VibesNetImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.memCacheHeight,
    this.fade = const Duration(milliseconds: 80),
    this.fallback,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Duration fade;
  final Widget? fallback;

  static final VibesImageCacheManager cache = VibesImageCacheManager();

  static int bucketFor(BuildContext context, {double? logicalWidth}) {
    if (DataSaver.slow) return 480;
    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0);
    final screen = MediaQuery.sizeOf(context).width;
    final logical =
        (logicalWidth != null && logicalWidth.isFinite && logicalWidth > 0)
        ? logicalWidth
        : screen;
    final px = (logical * dpr).round();
    return px <= 700 ? 480 : 960;
  }

  static int decodeWidth(BuildContext context, {double? logicalWidth}) {
    return bucketFor(context, logicalWidth: logicalWidth);
  }

  @override
  State<VibesNetImage> createState() => _VibesNetImageState();
}

class _VibesNetImageState extends State<VibesNetImage> {
  bool _original = false;

  @override
  void didUpdateWidget(covariant VibesNetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _original = false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutWidth =
            constraints.maxWidth.isFinite && constraints.maxWidth > 8
            ? constraints.maxWidth
            : widget.width;
        final bucket = VibesNetImage.bucketFor(
          context,
          logicalWidth: layoutWidth,
        );
        final request = _original
            ? widget.url
            : sizedImageUrl(widget.url, bucket);
        final cacheW = widget.memCacheWidth ?? bucket;

        return CachedNetworkImage(
          imageUrl: request,
          cacheManager: VibesNetImage.cache,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          memCacheWidth: cacheW,
          filterQuality: FilterQuality.medium,
          fadeInDuration: widget.fade,
          fadeOutDuration: Duration.zero,
          placeholder: (context, _) =>
              const ColoredBox(color: Color(0xFFF3F0EA)),
          errorWidget: (context, _, __) {
            if (!_original && request != widget.url) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_original) setState(() => _original = true);
              });
              return const ColoredBox(color: Color(0xFFF3F0EA));
            }
            return widget.fallback ??
                ColoredBox(
                  color: VibesTheme.surfaceHighOf(context),
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: VibesTheme.textTertiaryOf(context),
                  ),
                );
          },
        );
      },
    );
  }
}

bool get isAppResumed {
  final state = WidgetsBinding.instance.lifecycleState;
  return state == null || state == AppLifecycleState.resumed;
}
