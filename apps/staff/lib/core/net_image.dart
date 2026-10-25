import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// صور تطبيق الموظفين: نسخة مصغّرة من الخادم، محفوظة على القرص،
/// ومفكوكة بمقاس العرض — بدل تنزيل الأصل (300–500 كيلوبايت) كل مرة.
class StaffImageCache extends CacheManager with ImageCacheManager {
  StaffImageCache._()
      : super(
          Config(
            'staffMediaCache_v1',
            stalePeriod: const Duration(days: 30),
            maxNrOfCacheObjects: 1200,
          ),
        );

  static final StaffImageCache instance = StaffImageCache._();
}

/// المقاسات التي يولّدها الخادم (nginx) — أي عرض آخر يُرفض.
const kImageBuckets = [360, 480, 640, 800, 960, 1080, 1440];

int imageBucketFor(int px) {
  for (final b in kImageBuckets) {
    if (b >= px) return b;
  }
  return kImageBuckets.last;
}

/// /media/<ملف> → /media/w/<عرض>/<ملف>. الروابط الأخرى (إيصالات، خارجية) كما هي.
String sizedMediaUrl(String url, int px) {
  // روابط قديمة بعنوان IP (قبل الدومين) → الدومين (HTTPS)
  const legacy = 'http://187.127.88.146:6001';
  if (url.startsWith(legacy)) url = 'https://vibesiraq.com${url.substring(legacy.length)}';
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return url;
  final s = uri.pathSegments;
  if (s.length != 2 || s.first != 'media') return url;
  final lower = s.last.toLowerCase();
  if (!(lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.webp'))) {
    return url;
  }
  return uri.replace(pathSegments: ['media', 'w', '${imageBucketFor(px)}', s.last]).toString();
}

/// مزوّد صورة جاهز للاستخدام في أي مكان (Image, DecorationImage, CircleAvatar…).
/// [px] العرض المطلوب بالبكسل الفعلي.
ImageProvider staffImageProvider(String url, {int px = 800}) {
  final bucket = imageBucketFor(px);
  return ResizeImage(
    CachedNetworkImageProvider(sizedMediaUrl(url, bucket), cacheManager: StaffImageCache.instance),
    width: bucket,
    policy: ResizeImagePolicy.fit,
  );
}

/// بديل مباشر لـ Image.network بنفس المعاملات الشائعة.
Image staffNetworkImage(
  String src, {
  Key? key,
  BoxFit? fit,
  double? width,
  double? height,
  AlignmentGeometry alignment = Alignment.center,
  bool gaplessPlayback = true,
  ImageErrorWidgetBuilder? errorBuilder,
  ImageLoadingBuilder? loadingBuilder,
  int? px,
}) {
  final target = px ?? (width != null && width.isFinite ? (width * 2.5).round() : 800);
  return Image(
    key: key,
    image: staffImageProvider(src, px: target),
    fit: fit,
    width: width,
    height: height,
    alignment: alignment,
    gaplessPlayback: gaplessPlayback,
    filterQuality: FilterQuality.medium,
    errorBuilder: errorBuilder,
    loadingBuilder: loadingBuilder,
  );
}

/// يحسب مقاس الطلب من عرض المساحة الفعلية.
class StaffSizedImage extends StatelessWidget {
  const StaffSizedImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.loadingBuilder,
  });

  final String url;
  final BoxFit fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0);
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth.isFinite && c.maxWidth > 0 ? c.maxWidth : MediaQuery.sizeOf(context).width;
        return staffNetworkImage(
          url,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          px: (w * dpr).round(),
          errorBuilder: errorBuilder,
          loadingBuilder: loadingBuilder,
        );
      },
    );
  }
}
