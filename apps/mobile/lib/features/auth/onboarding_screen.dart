import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/vibes_widgets.dart';

/// الانطلاق — ثلاث لوحات بخطوط ذهبية رفيعة تُرسم ذاتياً
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    (
      Icons.agriculture_outlined,
      'مزارع فاخرة',
      'اكتشف أجمل المزارع بإطلالات خلابة ومسابح وجلسات عائلية — واحجز شفتك المفضل بنبضات قليلة',
    ),
    (
      Icons.celebration_outlined,
      'قاعات أحلامك',
      'قاعات أعراس وقاعات مناسبات بأرقى التجهيزات — شاهد الجولات والفيديوهات قبل أن تحجز',
    ),
    (
      Icons.auto_awesome_outlined,
      'تزيين يليق بفرحك',
      'خدمات تزيين وديكور متكاملة — كوش وورد وإضاءة تحوّل مناسبتك إلى لوحة فنية',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarded', true);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      backgroundColor: InkColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            // تخطي — نص ذهبي هادئ
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('تخطي'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (context, i) {
                  final (icon, title, body) = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // الرسم الخطي الذهبي — دائرة بإطار رفيع
                        Container(
                          width: 168,
                          height: 168,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: GoldColors.goldSoft,
                            border: Border.all(
                              color: GoldColors.gold.withValues(alpha: .35),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            icon,
                            size: 72,
                            color: GoldColors.gold,
                          ),
                        )
                            .animate(key: ValueKey(i))
                            .scale(
                              begin: const Offset(.85, .85),
                              duration: VibesMotion.slow,
                              curve: VibesMotion.curve,
                            )
                            .fadeIn(duration: VibesMotion.slow),
                        const SizedBox(height: 36),
                        Text(
                          title,
                          style:
                              Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: InkColors.textPrimary,
                                  ),
                        ).animate(key: ValueKey('t$i')).fadeIn(delay: 150.ms),
                        const SizedBox(height: 14),
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: InkColors.textSecondary,
                                height: 1.8,
                              ),
                        ).animate(key: ValueKey('b$i')).fadeIn(delay: 300.ms),
                      ],
                    ),
                  );
                },
              ),
            ),
            // النقاط الذهبية
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: VibesMotion.base,
                  curve: VibesMotion.curve,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: active ? GoldColors.gold : InkColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(6),
                  ),
                );
              }),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                child: VibesButton(
                  label: isLast ? 'ابدأ رحلتك' : 'التالي',
                  onPressed: () {
                    if (isLast) {
                      _finish();
                    } else {
                      _controller.nextPage(
                        duration: VibesMotion.slow,
                        curve: VibesMotion.curve,
                      );
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
