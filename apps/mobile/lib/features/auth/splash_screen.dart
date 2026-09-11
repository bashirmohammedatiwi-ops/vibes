import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import 'auth_controller.dart';

/// شاشة الانطلاق — شعار ذهبي يتنفس ثم توجيه الجلسة
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    final auth = ref.read(authControllerProvider);
    if (!auth.ready) {
      // انتظار استرجاع الجلسة لحظة إضافية
      await Future.delayed(const Duration(milliseconds: 600));
    }

    final prefs = await SharedPreferences.getInstance();
    final onboarded = prefs.getBool('onboarded') ?? false;
    if (!mounted) return;

    final state = ref.read(authControllerProvider);
    if (!state.loggedIn) {
      context.go(onboarded ? '/login' : '/onboarding');
    } else if (state.isProvider) {
      context.go('/provider');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InkColors.canvas,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // العلامة — دائرة ذهبية متوهجة تتنفس
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: GoldColors.gradient,
                boxShadow: [
                  BoxShadow(
                    color: GoldColors.gold.withValues(alpha: .35),
                    blurRadius: 42,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: GoldColors.onGold,
                size: 44,
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: .96, end: 1.03, duration: 1400.ms)
                .fadeIn(duration: 400.ms),
            const SizedBox(height: 22),
            ShaderMask(
              shaderCallback: (b) => GoldColors.textGradient.createShader(b),
              child: Text(
                'VIBES',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      color: Colors.white,
                    ),
              ),
            ).animate().fadeIn(delay: 250.ms, duration: 600.ms),
            const SizedBox(height: 8),
            Text(
              'مزارع · قاعات · تزيين',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: InkColors.textTertiary,
                    letterSpacing: 2,
                  ),
            ).animate().fadeIn(delay: 500.ms, duration: 600.ms),
            const SizedBox(height: 44),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                valueColor: AlwaysStoppedAnimation(GoldColors.gold),
              ),
            ).animate().fadeIn(delay: 700.ms),
          ],
        ),
      ),
    );
  }
}
