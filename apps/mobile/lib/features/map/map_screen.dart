import 'dart:ui' as ui show Path;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/property_card.dart';
import '../../shared/widgets/vibes_widgets.dart';

/// ═══════════════════════════════════════════════════════════
/// الخريطة — علامات ذهبية بعرض السعر + بطاقة مصغرة + قائمة/خريطة
/// ═══════════════════════════════════════════════════════════

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  bool _showMap = true;
  String? _selectedId;

  static const _baghdad = LatLng(33.3152, 44.3661);

  @override
  Widget build(BuildContext context) {
    final properties = ref.watch(propertiesProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: const Text('الأماكن على الخريطة'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: GestureDetector(
              onTap: () => setState(() => _showMap = !_showMap),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: VibesTheme.surfaceOf(context),
                  borderRadius: BorderRadius.circular(VibesRadius.pill),
                  border: Border.all(color: VibesTheme.hairlineOf(context)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showMap ? Icons.list_rounded : Icons.map_outlined,
                      size: 16,
                      color: GoldColors.gold,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _showMap ? 'قائمة' : 'خريطة',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: properties.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: GoldColors.gold),
        ),
        error: (e, _) => ErrorCanvas(
          message: e.toString(),
          onRetry: () => ref.invalidate(propertiesProvider(null)),
        ),
        data: (list) {
          final mappable = list
              .where((p) => p.latitude != null && p.longitude != null)
              .toList();
          final selected =
              mappable.where((p) => p.id == _selectedId).firstOrNull;

          if (_showMap) {
            return Column(
              children: [
                Expanded(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: mappable.isNotEmpty
                          ? LatLng(mappable.first.latitude!,
                              mappable.first.longitude!)
                          : _baghdad,
                      initialZoom: 10,
                      onTap: (_, __) => setState(() => _selectedId = null),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.vibes.vibes',
                      ),
                      MarkerLayer(
                        markers: mappable
                            .map(
                              (p) => Marker(
                                point: LatLng(p.latitude!, p.longitude!),
                                width: 60,
                                height: 52,
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedId = p.id),
                                  child: _GoldPin(
                                    selected: p.id == _selectedId,
                                    label: _shortPrice(p.pricePerDay),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: VibesMotion.base,
                  curve: VibesMotion.curve,
                  alignment: Alignment.topCenter,
                  child: selected != null
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                          child: PropertyCard(property: selected, compact: true)
                              .animate()
                              .slideY(begin: .08, end: 0)
                              .fadeIn(),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            );
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            itemCount: list.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PropertyCard(property: list[i]),
            ),
          );
        },
      ),
    );
  }

  String _shortPrice(num v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}م';
    if (v >= 1000) return '${(v / 1000).round()}k';
    return '$v';
  }
}

class _GoldPin extends StatelessWidget {
  const _GoldPin({required this.selected, required this.label});

  final bool selected;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: GoldColors.gradient,
            borderRadius: BorderRadius.circular(VibesRadius.pill),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: selected ? Colors.white : Colors.white38,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.home_work_rounded,
                  size: 12, color: GoldColors.onGold),
              const SizedBox(width: 3),
              Text(
                label,
                style: const TextStyle(
                  color: GoldColors.onGold,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        CustomPaint(
          size: const Size(10, 6),
          painter: _PinTriangle(),
        ),
      ],
    );
  }
}

class _PinTriangle extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = GoldColors.goldDeep;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
