import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/data/marketplace_providers.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_widgets.dart';

class CouponsScreen extends ConsumerWidget {
  const CouponsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coupons = ref.watch(publicCouponsProvider);
    return Scaffold(
      body: MaisonWash(
        child: Column(
          children: [
            MaisonPageHeader(
              title: 'كوبونات الخصم',
              kicker: 'وفر على حجزك',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: coupons.when(
                loading: () => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: const [
                    ShimmerBox(height: 154, radius: VibesRadius.md),
                    SizedBox(height: 10),
                    ShimmerBox(height: 154, radius: VibesRadius.md),
                  ],
                ),
                error: (e, _) => ErrorCanvas(
                  message: maisonError(e),
                  onRetry: () => ref.invalidate(publicCouponsProvider),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const EmptyCanvas(
                      icon: Icons.confirmation_number_outlined,
                      title: 'لا كوبونات حالياً',
                      subtitle: 'عندما يفعّل الفريق عرضاً سيظهر رمزه هنا',
                    );
                  }
                  return RefreshIndicator(
                    color: Vibes.coral,
                    onRefresh: () async =>
                        ref.invalidate(publicCouponsProvider),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _CouponCard(coupon: list[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.coupon});

  final PublicCoupon coupon;

  @override
  Widget build(BuildContext context) {
    return FolioPanel(
      color: Vibes.tealMint,
      borderColor: Vibes.teal.withValues(alpha: .28),
      railColor: Vibes.teal,
      shadows: Vibes.card,
      child: Stack(
        children: [
          const PositionedDirectional(
            end: 14,
            top: 10,
            child: IgnorePointer(
              child: Opacity(
                opacity: .12,
                child: CrestSeal(size: 68, color: Vibes.teal),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 17, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const MaisonIconWell(
                      icon: Icons.confirmation_number_outlined,
                      color: Vibes.teal,
                      background: Colors.white,
                      size: 38,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      coupon.discountLabel,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Vibes.teal,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    FolioPanel(
                      color: VibesDark.canvas,
                      borderColor: Colors.transparent,
                      radius: Folio.compact,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(
                          coupon.code,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Vibes.canvas,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  coupon.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Vibes.ink,
                    height: 1.55,
                  ),
                ),
                if (coupon.propertyName != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'لمكان: ${coupon.propertyName}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Vibes.inkSecondary),
                  ),
                ],
                if (coupon.minBookingTotal != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'الحد الأدنى ${coupon.minBookingTotal!.toInt()} د.ع',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: Vibes.inkTertiary),
                  ),
                ],
                const SizedBox(height: 14),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: VibesButton(
                    label: 'نسخ الرمز',
                    small: true,
                    expanded: false,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: coupon.code));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('تم نسخ ${coupon.code}')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
