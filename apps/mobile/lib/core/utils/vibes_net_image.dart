import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'data_saver.dart';

/// صورة شبكة تُفكّ بمقاس العرض لا بدقة المصدر الكاملة.
class VibesNetImage extends StatelessWidget {
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

  static int decodeWidth(BuildContext context, {double? logicalWidth}) {
    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.5);
    final screen = MediaQuery.sizeOf(context).width;
    final logical = logicalWidth ?? screen;
    final raw = (logical * dpr).round();
    final scaled = DataSaver.slow ? (raw * 0.55).round() : raw;
    return scaled.clamp(280, 1080);
  }

  static int decodeHeight(BuildContext context, double logicalHeight) {
    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.5);
    final raw = (logicalHeight * dpr).round();
    final scaled = DataSaver.slow ? (raw * 0.55).round() : raw;
    return scaled.clamp(160, 900);
  }

  @override
  Widget build(BuildContext context) {
    final cacheW = memCacheWidth ??
        decodeWidth(context, logicalWidth: width?.isFinite == true ? width : null);
    final cacheH = memCacheHeight ??
        (height != null ? decodeHeight(context, height!) : null);

    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: cacheW,
      memCacheHeight: cacheH,
      fadeInDuration: fade,
      fadeOutDuration: Duration.zero,
      placeholder: (context, url) => ColoredBox(
        color: VibesTheme.surfaceHighOf(context),
      ),
      errorWidget: (context, url, err) =>
          fallback ??
          ColoredBox(
            color: VibesTheme.surfaceHighOf(context),
            child: Icon(
              Icons.image_not_supported_outlined,
              color: VibesTheme.textTertiaryOf(context),
            ),
          ),
    );
  }
}

bool get isAppResumed {
  final state = WidgetsBinding.instance.lifecycleState;
  return state == null || state == AppLifecycleState.resumed;
}
