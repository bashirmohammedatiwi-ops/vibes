import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../i18n/i18n.dart';
import 'package:flutter/services.dart';

import '../../features/property/place_experience_ui.dart';

/// طبقة انتقال كاملة بين وضع الضيف وبوابة المالك.
Future<void> showModeTransition(
  BuildContext context, {
  required bool toProvider,
}) async {
  HapticFeedback.mediumImpact();
  final navigator = Navigator.of(context, rootNavigator: true);
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (ctx, anim1, anim2) {
      return _ModeTransitionCard(toProvider: toProvider, animation: anim1);
    },
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
  await Future<void>.delayed(const Duration(milliseconds: 520));
  if (navigator.mounted) {
    navigator.pop();
  }
}

class _ModeTransitionCard extends StatelessWidget {
  const _ModeTransitionCard({
    required this.toProvider,
    required this.animation,
  });

  final bool toProvider;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final title = toProvider ? 'بوابة المالك'.tr : 'تطبيق أجواء'.tr;
    final subtitle = toProvider
        ? 'إدارة الحجوزات والتقويم والأرباح'.tr
        : 'تصفح واحجز كضيف'.tr;
    final accent = toProvider ? placeBrass : placeInk;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 280,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
          decoration: BoxDecoration(
            color: toProvider
                ? themed(placeInk, VibesDark.surfaceMuted)
                : Vibes.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: toProvider ? placeBrass.withValues(alpha: .45) : placeLine,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .22),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  return Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: toProvider ? .2 : .12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      toProvider
                          ? Icons.space_dashboard_rounded
                          : Icons.explore_rounded,
                      color: toProvider ? placeBrass : placeInk,
                      size: 28,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: toProvider ? Colors.white : placeInk,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: toProvider
                      ? Colors.white.withValues(alpha: .78)
                      : placeInk2,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: toProvider
                      ? Colors.white.withValues(alpha: .12)
                      : placeLine,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
