import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/world_theme.dart';
import 'vibes_graphics.dart';

/// ═══════════════════════════════════════════════════════════
/// الاتجاهات — يفتح موقع المكان في تطبيق الخرائط الذي يفضّله الزبون
/// (Google Maps، Waze، خرائط Apple، أو أي تطبيق مثبّت)، أو ينسخ
/// الإحداثيات، أو يشارك رابط الموقع.
/// ═══════════════════════════════════════════════════════════

String placeMapLink(double lat, double lng) =>
    'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

Future<void> showDirectionsSheet(
  BuildContext context, {
  required double lat,
  required double lng,
  required String name,
}) {
  HapticFeedback.selectionClick();
  final theme = Theme.of(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => Theme(
      data: theme,
      child: _DirectionsSheet(lat: lat, lng: lng, name: name),
    ),
  );
}

class _DirectionsSheet extends StatelessWidget {
  const _DirectionsSheet({
    required this.lat,
    required this.lng,
    required this.name,
  });

  final double lat;
  final double lng;
  final String name;

  Future<void> _open(BuildContext context, String url) async {
    Navigator.of(context).pop();
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) throw Exception();
    } catch (_) {
      // احتياط: افتح رابط Google Maps في المتصفح
      await launchUrl(
        Uri.parse(placeMapLink(lat, lng)),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final ios = Platform.isIOS;
    final label = Uri.encodeComponent(name);

    final apps = <_App>[
      if (ios)
        _App(
          'خرائط Apple'.tr,
          'الاتجاهات بالسيارة'.tr,
          Icons.map_rounded,
          const Color(0xFF34C759),
          'https://maps.apple.com/?daddr=$lat,$lng&dirflg=d',
        ),
      _App(
        'Google Maps',
        'المسار والوقت المتوقع'.tr,
        Icons.location_on_rounded,
        const Color(0xFF4285F4),
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
      ),
      _App(
        'Waze',
        'ملاحة وتنبيهات الطريق'.tr,
        Icons.navigation_rounded,
        const Color(0xFF33CCFF),
        'https://waze.com/ul?ll=$lat,$lng&navigate=yes',
      ),
      if (!ios)
        _App(
          'تطبيقات أخرى'.tr,
          'اختر أي تطبيق خرائط مثبّت'.tr,
          Icons.apps_rounded,
          themed(const Color(0xFF7C3AED), const Color(0xFFA78BFA)),
          'geo:$lat,$lng?q=$lat,$lng($label)',
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Vibes.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 18 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: themed(const Color(0xFFDDDFE3), VibesDark.hairlineStrong),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: p.fill,
                  shape: BoxShape.circle,
                  boxShadow: p.glowShadow,
                ),
                child: Icon(
                  Icons.directions_rounded,
                  color: p.onAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الاتجاهات إلى المكان'.tr,
                      style: TextStyle(
                        fontFamily: VibesFont.ui,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Vibes.ink,
                      ),
                    ),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: VibesFont.ui,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Vibes.inkTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final app in apps)
            _AppRow(app: app, onTap: () => _open(context, app.url)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _SmallAction(
                  icon: Icons.ios_share_rounded,
                  label: 'مشاركة الموقع'.tr,
                  onTap: () {
                    Navigator.of(context).pop();
                    Share.share('$name\n${placeMapLink(lat, lng)}');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SmallAction(
                  icon: Icons.copy_rounded,
                  label: 'نسخ الإحداثيات'.tr,
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(
                        text:
                            '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                      ),
                    );
                    HapticFeedback.selectionClick();
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('نُسخت الإحداثيات'.tr),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _App {
  const _App(this.title, this.subtitle, this.icon, this.color, this.url);

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String url;
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.app, required this.onTap});

  final _App app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PressScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: themed(const Color(0xFFF6F7F9), VibesDark.surfaceMuted),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: app.color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(app.icon, color: app.color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.title,
                      style: TextStyle(
                        fontFamily: VibesFont.ui,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Vibes.ink,
                      ),
                    ),
                    Text(
                      app.subtitle,
                      style: TextStyle(
                        fontFamily: VibesFont.ui,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Vibes.inkTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: Vibes.inkTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    return PressScale(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Vibes.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.accent.withValues(alpha: .3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: p.accentDeep),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: VibesFont.ui,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: p.accentDeep,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
