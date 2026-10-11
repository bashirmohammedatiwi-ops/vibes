import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_mode/app_mode_controller.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/property/place_experience_ui.dart';

/// شريط عائم للتبديل بين تطبيق الضيف وبوابة المالك.
class ExperienceModeSwitcherBar extends ConsumerWidget {
  const ExperienceModeSwitcherBar({super.key, required this.inProviderPortal});

  /// `true` داخل [ProviderShell] — الزر يعرض العودة لتطبيق الضيف.
  final bool inProviderPortal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (!auth.isProvider) return const SizedBox.shrink();

    final mode = ref.watch(appModeProvider);
    final showGuestExit =
        inProviderPortal && mode == AppExperienceMode.provider;
    final showPortalEntry =
        !inProviderPortal && mode == AppExperienceMode.guest;

    if (!showGuestExit && !showPortalEntry) {
      return const SizedBox.shrink();
    }

    final toProvider = showPortalEntry;
    final label = toProvider ? 'بوابة المالك' : 'تطبيق VIBES';
    final icon = toProvider
        ? Icons.space_dashboard_rounded
        : Icons.explore_rounded;
    final bg = toProvider ? placeInk : Colors.white;
    final fg = toProvider ? Colors.white : placeInk;
    final border = toProvider ? placeBrass.withValues(alpha: .5) : placeLine;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: bg,
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            if (toProvider) {
              switchToProviderPortal(context, ref);
            } else {
              final path = GoRouterState.of(context).uri.path;
              ref.read(appModeProvider.notifier).rememberGuestPath(path);
              switchToGuestExperience(context, ref);
            }
          },
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: toProvider ? placeBrass : placeInk),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: fg,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.swap_horiz_rounded,
                  size: 16,
                  color: toProvider
                      ? Colors.white.withValues(alpha: .7)
                      : placeInk2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
