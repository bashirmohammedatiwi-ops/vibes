import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
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
  String? _type;

  static const _baghdad = LatLng(33.3152, 44.3661);

  @override
  Widget build(BuildContext context) {
    final properties = ref.watch(propertiesProvider(null));

    return Scaffold(
      body: MaisonWash(
        child: Column(
          children: [
            MaisonPageHeader(
              title: 'الخريطة',
              kicker: 'اكتشف جغرافياً',
              trailing: SizedBox(
                width: 148,
                child: MaisonSegmented(
                  labels: const ['خريطة', 'قائمة'],
                  index: _showMap ? 0 : 1,
                  onChanged: (i) => setState(() => _showMap = i == 0),
                ),
              ),
            ),
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
                children: [
                  for (final item in const [
                    (null, 'كل الأماكن'),
                    ('FARM', 'مزارع'),
                    ('HALL', 'قاعات'),
                    ('DECORATION', 'تزيين'),
                  ])
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: MaisonChip(
                        label: item.$2,
                        active: _type == item.$1,
                        onTap: () => setState(() {
                          _type = item.$1;
                          _selectedId = null;
                        }),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: properties.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(20),
                  child: ShimmerBox(height: 520, radius: VibesRadius.md),
                ),
                error: (e, _) => ErrorCanvas(
                  message: maisonError(e),
                  onRetry: () => ref.invalidate(propertiesProvider(null)),
                ),
                data: (list) {
                  final filtered = _type == null
                      ? list
                      : list
                            .where((p) => p.type.name.toUpperCase() == _type)
                            .toList();
                  final mappable = filtered
                      .where((p) => p.latitude != null && p.longitude != null)
                      .toList();
                  final selected = mappable
                      .where((p) => p.id == _selectedId)
                      .firstOrNull;

                  if (_showMap) {
                    return Column(
                      children: [
                        Expanded(
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: mappable.isNotEmpty
                                  ? LatLng(
                                      mappable.first.latitude!,
                                      mappable.first.longitude!,
                                    )
                                  : _baghdad,
                              initialZoom: 10,
                              onTap: (_, __) =>
                                  setState(() => _selectedId = null),
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
                                        point: LatLng(
                                          p.latitude!,
                                          p.longitude!,
                                        ),
                                        width: 76,
                                        height: 58,
                                        child: GestureDetector(
                                          onTap: () => setState(
                                            () => _selectedId = p.id,
                                          ),
                                          child: DiamondPin(
                                            price: _shortPrice(p.pricePerDay),
                                            selected: _selectedId == p.id,
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
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    10,
                                    16,
                                    12,
                                  ),
                                  child:
                                      PropertyCard(
                                            property: selected,
                                            compact: true,
                                          )
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
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: PropertyCard(property: filtered[i]),
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

  String _shortPrice(num v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}م';
    if (v >= 1000) return '${(v / 1000).round()}k';
    return '$v';
  }
}
