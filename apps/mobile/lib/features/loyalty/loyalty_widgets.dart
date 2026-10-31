import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/world_theme.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../home/home_sections.dart';
import 'loyalty_data.dart';

/// عرض الولاء داخل الحجز: خصم جاهز بمفتاح استخدام، أو عدّاد التقدم.
/// [offer] هو حقل `loyalty` من رد التسعير.
class LoyaltyBookingOffer extends StatelessWidget {
  const LoyaltyBookingOffer({
    super.key,
    required this.offer,
    required this.applied,
    required this.onChanged,
    required this.section,
  });

  final Map<String, dynamic>? offer;
  final bool applied;
  final ValueChanged<bool> onChanged;
  final HomeSection section;

  @override
  Widget build(BuildContext context) {
    final data = offer;
    if (data == null) return const SizedBox.shrink();
    final world = WorldPalette.of(section);
    final percent = data['percent'] as num? ?? 25;
    final discount = data['discount'] as num? ?? 0;
    final eligible = data['eligible'] as bool? ?? false;
    if (!eligible) {
      final required = (data['required'] as num? ?? 5).toInt();
      final stamps = (data['stamps'] as num? ?? 0).toInt();
      return _Meter(
        world: world,
        required: required,
        stamps: stamps,
        label: 'باقي {n} حجوزات على خصم {percent}% في {world}'
            .trN(data['remaining'] as num? ?? required)
            .replaceAll('{percent}', '$percent')
            .replaceAll('{world}', section.label),
      );
    }
    return AnimatedContainer(
      duration: VibesMotion.base,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 8, 12),
      decoration: BoxDecoration(
        gradient: applied
            ? LinearGradient(colors: [world.nightHigh, world.night])
            : null,
        color: applied ? null : Vibes.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: applied ? world.accentLight : Vibes.hairline),
      ),
      child: Row(
        children: [
          Icon(
            Icons.card_giftcard_rounded,
            color: applied ? world.accentLight : world.accentDeep,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'استخدم خصم الولاء'.tr,
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: applied ? Colors.white : Vibes.ink,
                  ),
                ),
                Text(
                  'وفّر {amount} د.ع على هذا الحجز'.trArgs({
                    'amount': PriceText.format(discount),
                  }),
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: applied
                        ? Colors.white.withValues(alpha: .8)
                        : Vibes.inkSecondary,
                  ),
                ),
                Text(
                  'لا يُجمع مع الكوبون'.tr,
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: applied
                        ? Colors.white.withValues(alpha: .62)
                        : Vibes.inkTertiary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: applied,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({
    required this.world,
    required this.required,
    required this.stamps,
    required this.label,
  });

  final WorldPalette world;
  final int required;
  final int stamps;
  final String label;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => context.push('/loyalty'),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Vibes.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Vibes.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: VibesFont.ui,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Vibes.ink,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < required; i++)
                Expanded(
                  child: Container(
                    height: 6,
                    margin: const EdgeInsetsDirectional.only(end: 4),
                    decoration: BoxDecoration(
                      color: i < stamps ? world.accent : Vibes.surfaceMuted,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ),
              Icon(
                Icons.card_giftcard_rounded,
                size: 16,
                color: world.accentDeep,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// تنبيه الرئيسية عندما يكون لدى الزبون خصم جاهز في العالم الحالي.
class LoyaltyHomeBanner extends ConsumerWidget {
  const LoyaltyHomeBanner({super.key, required this.section});

  final HomeSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(loyaltyProvider).valueOrNull;
    final program = status?.forType(switch (section) {
      HomeSection.farm => 'FARM',
      HomeSection.hall => 'HALL',
      HomeSection.decoration => 'DECORATION',
    });
    if (program == null || !program.enabled || !program.rewardReady) {
      return const SizedBox.shrink();
    }
    final world = WorldPalette.of(section);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: GestureDetector(
        onTap: () => context.push('/loyalty'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [world.nightHigh, world.night]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.card_giftcard_rounded, color: world.accentLight),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'خصم {percent}% جاهز لحجزك في {world}'.trArgs({
                    'percent': program.percent,
                    'world': section.label,
                  }),
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}
