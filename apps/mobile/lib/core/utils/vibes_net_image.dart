import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../constants/api_constants.dart';
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

/// المقاسات التي يولّدها الخادم (nginx image_filter) — أي عرض آخر يُرفض.
const kImageBuckets = [360, 480, 640, 800, 960, 1080, 1440];

/// أصغر مقاس يغطي [px] بكسل.
int imageBucketFor(int px) {
  for (final b in kImageBuckets) {
    if (b >= px) return b;
  }
  return kImageBuckets.last;
}

/// يحوّل رابط صورة الخادم إلى نسخة مصغّرة: /media/w/<عرض>/<ملف>.
/// النسخ تُولَّد مرة واحدة وتُحفظ على الخادم، وصور Unsplash تُطلب بعرض أصغر.
String sizedImageUrl(String url, int width) {
  // روابط قديمة بعنوان IP — نحوّلها إلى الدومين (HTTPS)
  if (url.startsWith(ApiConstants.legacyServer)) {
    url = ApiConstants.server + url.substring(ApiConstants.legacyServer.length);
  }
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return url;
  final bucket = imageBucketFor(width);
  final host = uri.host;

  if (host.contains('unsplash.com')) {
    final query = Map<String, String>.from(uri.queryParameters);
    query['w'] = '$bucket';
    query['q'] = '65';
    query['auto'] = 'format';
    query.remove('h');
    return uri.replace(queryParameters: query).toString();
  }

  final segments = uri.pathSegments;
  // /media/<ملف> فقط — لا نلمس روابط مصغّرة أصلاً أو مجلدات فرعية
  if (segments.length != 2 || segments.first != 'media') return url;
  final file = segments.last;
  final lower = file.toLowerCase();
  if (!lower.endsWith('.jpg') &&
      !lower.endsWith('.jpeg') &&
      !lower.endsWith('.png') &&
      !lower.endsWith('.webp')) {
    return url;
  }
  return uri.replace(pathSegments: ['media', 'w', '$bucket', file]).toString();
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

  /// عرض الصورة بالبكسل (عرض منطقي × كثافة الشاشة حتى 2× — حادّة للعين
  /// وأخف بكثير من 3×، ومقاسات متطابقة تعني إصابات أكثر في الكاش).
  static int bucketFor(BuildContext context, {double? logicalWidth}) {
    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0);
    final screen = MediaQuery.sizeOf(context).width;
    final logical =
        (logicalWidth != null && logicalWidth.isFinite && logicalWidth > 0)
        ? logicalWidth
        : screen;
    final px = (logical * (DataSaver.slow ? 1.0 : dpr)).round();
    return imageBucketFor(px);
  }

  static int decodeWidth(BuildContext context, {double? logicalWidth}) {
    return bucketFor(context, logicalWidth: logicalWidth);
  }

  @override
  State<VibesNetImage> createState() => _VibesNetImageState();
}

class _VibesNetImageState extends State<VibesNetImage> {
  bool _original = false;

  /// محاولات إعادة التحميل بعد الفشل (شبكة أول فتح أو انقطاع لحظي).
  int _attempt = 0;
  bool _retryScheduled = false;

  void _scheduleRetry() {
    if (_retryScheduled || _attempt >= 3) return;
    _retryScheduled = true;
    final wait = Duration(milliseconds: 900 * (1 << _attempt));
    Future<void>.delayed(wait, () async {
      if (!mounted) return;
      // امسح نسخة الفشل من ذاكرة الصور ثم أعد الطلب بمفتاح جديد
      await CachedNetworkImage.evictFromCache(
        widget.url,
        cacheManager: VibesNetImage.cache,
      );
      if (!mounted) return;
      setState(() {
        _attempt++;
        _retryScheduled = false;
        _original = false; // ابدأ من النسخة المصغّرة مجدداً
      });
    });
  }

  @override
  void didUpdateWidget(covariant VibesNetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _original = false;
      _attempt = 0;
    }
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
          key: ValueKey('$request#$_attempt'),
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
            // الأصل فشل أيضاً — أعد المحاولة لاحقاً بدل البقاء فارغة
            _scheduleRetry();
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
