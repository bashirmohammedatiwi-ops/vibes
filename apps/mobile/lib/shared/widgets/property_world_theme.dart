import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/world_theme.dart';
import '../data/property_providers.dart';

/// يلبس صفحة المكان ومسار حجزه ثوب عالم المكان نفسه:
/// قاعة تفتح بالياقوت حتى لو كان المستخدم في عالم المزارع، والعكس.
/// يقرأ المكان من نفس الكاش الذي تستخدمه الصفحة (بلا طلب إضافي).
class PropertyWorldTheme extends ConsumerWidget {
  const PropertyWorldTheme({
    super.key,
    required this.propertyId,
    required this.child,
  });

  final String propertyId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final property = ref.watch(propertyDetailProvider(propertyId)).valueOrNull;
    if (property == null) return child;
    final palette = WorldPalette.forType(property.type.name);
    if (palette.world == context.world.world) return child;
    return AnimatedTheme(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
      data: applyWorld(Theme.of(context), palette),
      child: child,
    );
  }
}
