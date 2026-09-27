import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/atelier_widgets.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/vibes_widgets.dart';
import 'booking_providers.dart';

Future<bool> showReviewSheet(
  BuildContext context,
  WidgetRef ref,
  Booking booking,
) async {
  final comment = TextEditingController();
  var stars = 0;
  var saving = false;

  final submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
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
              Text(
                'قيّم ${booking.propertyName ?? 'تجربتك'}',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'تقييمك يساعد غيرك على الاختيار الصحيح',
                style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                      color: VibesTheme.textTertiaryOf(sheetContext),
                    ),
              ),
              const SizedBox(height: 22),
              Center(
                child: AtelierStars(
                  rating: stars.toDouble(),
                  size: 34,
                  onChanged: (value) => setSheet(() => stars = value.toInt()),
                ),
              ),
              if (stars > 0) ...[
                const SizedBox(height: 18),
                MaisonField(
                  label: 'تعليق اختياري',
                  controller: comment,
                  hint: 'ما أعجبك أكثر؟',
                  maxLines: 2,
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: VibesButton(
                  label: 'إرسال التقييم',
                  loading: saving,
                  onPressed: stars == 0
                      ? null
                      : () async {
                          setSheet(() => saving = true);
                          try {
                            await ref.read(apiClientProvider).post(
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
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(content: Text(error.toString())),
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
  );

  comment.dispose();
  return submitted == true;
}
