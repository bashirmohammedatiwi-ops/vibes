import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_widgets.dart';

/// مشاركة المكان كبطاقة صورة أنيقة — ترويسة VIBES ياقوتية + السعر
Future<void> sharePropertyAsImage(
  BuildContext context,
  GlobalKey cardKey,
  Property property,
) async {
  try {
    final boundary =
        cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 2.5);
    final bytes = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();

    final dir = Directory.systemTemp;
    final file = File('${dir.path}/vibes-${property.id}.png');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles([
      XFile(file.path),
    ], text: '${property.name} — اكتشفها على تطبيق VIBEES');
  } catch (_) {
    await Share.share('${property.name} — اكتشفها على تطبيق VIBEES');
  }
}

/// البطاقة القابلة للالتقاط — تُعرض خلف الستارة أثناء المشاركة
class ShareablePropertyCard extends StatelessWidget {
  const ShareablePropertyCard({super.key, required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FolioPanel(
        color: Vibes.canvas,
        borderColor: Vibes.teal.withValues(alpha: .35),
        shadows: Vibes.card,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FolioPanel(
                    color: Vibes.coral,
                    borderColor: Colors.transparent,
                    child: const SizedBox(
                      width: 34,
                      height: 34,
                      child: Center(
                        child: CrestSeal(size: 20, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'VIBEES',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Vibes.coral,
                    ),
                  ),
                  const Spacer(),
                  if (property.ratingCount > 0)
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 15,
                          color: Vibes.teal,
                        ),
                        Text(
                          property.ratingAvg.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Vibes.teal,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                property.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Vibes.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${property.typeLabelAr} · ${property.cityName ?? ''} · حتى ${property.capacity} ضيف',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Vibes.inkSecondary),
              ),
              const SizedBox(height: 14),
              FolioPanel(
                color: Vibes.tealMint,
                borderColor: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'يبدأ من  ',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Vibes.inkSecondary,
                        ),
                      ),
                      Text(
                        '${PriceText.format(property.pricePerDay)} د.ع',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Vibes.coral,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
