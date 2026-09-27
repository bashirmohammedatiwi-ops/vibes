import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
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
      'https://images.unsplash.com/photo-1519972064555-542444e71b54?w=1080&q=80',
      'مزارع فاخرة',
      'اكتشف أجمل المزارع بإطلالات خلابة ومسابح وجلسات عائلية — واحجز شفتك المفضل بنبضات قليلة',
    ),
    (
      'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=1080&q=80',
      'قاعات أحلامك',
      'قاعات أعراس وقاعات مناسبات بأرقى التجهيزات — شاهد الجولات والفيديوهات قبل أن تحجز',
    ),
    (
      'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=1080&q=80',
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
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      backgroundColor: Vibes.canvas,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: _pages.length,
            itemBuilder: (context, i) {
              final (image, title, body) = _pages[i];
              return Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: image,
                    fit: BoxFit.cover,
                    fadeInDuration: VibesMotion.slow,
                    errorWidget: (_, __, ___) =>
                        Container(color: VibesDark.canvas),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [.08, .48, 1],
                        colors: [
                          Colors.black.withValues(alpha: .18),
                          Colors.black.withValues(alpha: .42),
                          VibesDark.canvas,
                        ],
                      ),
                    ),
                  ),
                  Stack(
                    children: [
                      const PositionedDirectional(
                        top: 74,
                        end: 26,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: .16,
                            child: CrestSeal(
                              size: 112,
                              color: Vibes.tealBright,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 0, 28, 168),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: ShapeDecoration(
                                color: Colors.white.withValues(alpha: .12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    topRight: Radius.circular(2),
                                    bottomRight: Radius.circular(8),
                                    bottomLeft: Radius.circular(8),
                                  ),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: .24),
                                  ),
                                ),
                              ),
                              child: const MaisonKicker(
                                'ضيافة العراق',
                                light: true,
                                color: Vibes.tealBright,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                                  title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 38,
                                        color: Colors.white,
                                        height: 1.12,
                                      ),
                                )
                                .animate(key: ValueKey('t$i'))
                                .fadeIn(delay: 80.ms),
                            const SizedBox(height: 10),
                            const ArcFlourish(
                              width: 48,
                              color: Vibes.tealBright,
                            ),
                            const SizedBox(height: 14),
                            Text(
                                  body,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: .82,
                                        ),
                                        height: 1.8,
                                      ),
                                )
                                .animate(key: ValueKey('b$i'))
                                .fadeIn(delay: 180.ms),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          SafeArea(
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextButton(
                  onPressed: _finish,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: .12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(2),
                        bottomRight: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                      ),
                    ),
                  ),
                  child: const Text('تخطي'),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xE60F2138), VibesDark.canvas],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(height: 3, color: Vibes.teal),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 18, 28, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(_pages.length, (i) {
                              final active = i == _page;
                              return AnimatedContainer(
                                duration: VibesMotion.fast,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                width: active ? 26 : 10,
                                height: 2,
                                color: active
                                    ? Vibes.tealBright
                                    : Colors.white.withValues(alpha: .35),
                              );
                            }),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
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
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
