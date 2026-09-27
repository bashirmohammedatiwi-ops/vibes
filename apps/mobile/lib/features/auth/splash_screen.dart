import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import 'auth_controller.dart';

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
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final auth = ref.read(authControllerProvider);
    if (!auth.ready) {
      await Future.delayed(const Duration(milliseconds: 600));
    }

    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final onboarded = prefs.getBool('onboarded') ?? false;

    final state = ref.read(authControllerProvider);
    if (!state.loggedIn) {
      context.go(onboarded ? '/home' : '/onboarding');
    } else if (state.isProvider) {
      context.go('/provider');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MaisonNightWash(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 80 || constraints.maxHeight < 80) {
              return const SizedBox.shrink();
            }
            return SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 28),
                  const MaisonKicker(
                    'ضيافة العراق',
                    light: true,
                    color: Vibes.tealBright,
                  ),
                  const Spacer(),
                  const VibesLogo.lockup(height: 168)
                      .animate()
                      .scale(
                        begin: const Offset(.88, .88),
                        curve: Curves.easeOutCubic,
                        duration: 560.ms,
                      )
                      .fadeIn(duration: 420.ms),
                  const SizedBox(height: 22),
                  const ArcFlourish(width: 48, color: Vibes.tealBright),
                  const SizedBox(height: 16),
                  Text(
                    'احجز مكان مناسبتك',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Vibes.canvas.withValues(alpha: .82),
                      fontWeight: FontWeight.w700,
                    ),
                  ).animate().fadeIn(delay: 280.ms),
                  const Spacer(),
                  const Center(
                    child: ThreadProgress(width: 110),
                  ).animate().fadeIn(delay: 500.ms),
                  const SizedBox(height: 36),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
