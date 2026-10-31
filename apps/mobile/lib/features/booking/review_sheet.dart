import 'package:flutter/material.dart';
import '../../core/i18n/i18n.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/world_theme.dart';
import '../../shared/widgets/world_ui.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/atelier_widgets.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/vibes_graphics.dart';
import 'booking_providers.dart';

Future<bool> showReviewSheet(
  BuildContext context,
  WidgetRef ref,
  Booking booking,
) async {
  final comment = TextEditingController();
  var stars = 0;
  var saving = false;

  final palette = WorldPalette.forType(booking.propertyType);
  final theme = applyWorld(Theme.of(context), palette);
  final submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Vibes.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => Theme(
      data: theme,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: StatefulBuilder(
          builder: (sheetContext, setSheet) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MaisonSheetHandle(),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: palette.fill,
                        shape: BoxShape.circle,
                        boxShadow: palette.glowShadow,
                      ),
                      child: Icon(
                        Icons.star_rounded,
                        color: palette.onAccent,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'قيّم {name}'.trArgs({
                          'name': booking.propertyName ?? 'تجربتك'.tr,
                        }),
                        style: TextStyle(
                          fontFamily: VibesFont.ui,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: Vibes.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'تقييمك يساعد غيرك على الاختيار الصحيح'.tr,
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                    color: VibesTheme.textTertiaryOf(sheetContext),
                  ),
                ),
                const SizedBox(height: 22),
                Center(
                  child: _BouncingStars(
                    rating: stars,
                    onChanged: (value) => setSheet(() => stars = value),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: AnimatedSwitcher(
                    duration: VibesMotion.fast,
                    child: Text(
                      _starLabel(stars),
                      key: ValueKey(stars),
                      style: Theme.of(sheetContext).textTheme.labelLarge
                          ?.copyWith(
                            color: stars > 0
                                ? palette.accentDeep
                                : VibesTheme.textTertiaryOf(sheetContext),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ),
                if (stars > 0) ...[
                  const SizedBox(height: 18),
                  MaisonField(
                    label: 'تعليق اختياري'.tr,
                    controller: comment,
                    hint: 'ما أعجبك أكثر؟'.tr,
                    maxLines: 2,
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: WorldButton(
                    label: 'إرسال التقييم'.tr,
                    icon: Icons.send_rounded,
                    palette: palette,
                    loading: saving,
                    onTap: stars == 0
                        ? null
                        : () async {
                            setSheet(() => saving = true);
                            try {
                              await ref
                                  .read(apiClientProvider)
                                  .post(
                                    '/api/reviews',
                                    body: {
                                      'propertyId': booking.propertyId,
                                      'rating': stars,
                                      'comment': comment.text.trim(),
                                    },
                                  );
                              ref.invalidate(myBookingsProvider);
                              ref.invalidate(bookingDetailProvider(booking.id));
                              ref.invalidate(
                                propertyReviewsProvider(booking.propertyId),
                              );
                              if (sheetContext.mounted) {
                                HapticFeedback.mediumImpact();
                                Navigator.pop(sheetContext, true);
                              }
                            } catch (error) {
                              setSheet(() => saving = false);
                              if (sheetContext.mounted) {
                                showVibesToast(
                                  sheetContext,
                                  maisonError(error),
                                  type: VibesToastType.danger,
                                );
                              }
                            }
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  comment.dispose();
  return submitted == true;
}

const _starLabels = {
  1: 'لم يعجبنا — نخطط للأفضل', // i18n-ok
  2: 'مقبول — تجربة تحتاج تحسيناً', // i18n-ok
  3: 'جيد — أجزاء أعجبتنا', // i18n-ok
  4: 'جيد جداً — تجربة تليق', // i18n-ok
  5: 'ممتاز — لحظة تُروى', // i18n-ok
};

String _starLabel(int stars) =>
    stars > 0 ? (_starLabels[stars]?.tr ?? '') : 'اضغط على النجوم للتقييم'.tr;

/// نجوم تقفز — كل نجمة مختارة تنبض elasticOut مع هزة لمسية
class _BouncingStars extends StatelessWidget {
  const _BouncingStars({required this.rating, required this.onChanged});

  final int rating;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: rating.toDouble()),
      duration: const Duration(milliseconds: 420),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        final pop = value.floor() == rating && value > rating - 1
            ? 1.0 + 0.18 * (value - value.floorToDouble())
            : 1.0;
        return Transform.scale(
          scale: rating > 0 ? pop.clamp(1.0, 1.18) : 1.0,
          child: child,
        );
      },
      child: AtelierStars(
        rating: rating.toDouble(),
        size: 36,
        onChanged: (value) {
          HapticFeedback.selectionClick();
          onChanged(value.toInt());
        },
      ),
    );
  }
}
