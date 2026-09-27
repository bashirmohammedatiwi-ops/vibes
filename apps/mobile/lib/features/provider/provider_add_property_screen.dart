import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_widgets.dart';
import 'provider_data.dart';

const _iraqCenters = <String, (double, double)>{
  'بغداد': (33.3152, 44.3661),
  'البصرة': (30.5085, 47.7804),
  'أربيل': (36.1911, 44.0092),
  'الموصل': (36.3489, 43.1577),
  'النجف': (31.9996, 44.3396),
  'كربلاء': (32.6163, 44.0249),
  'السليمانية': (35.5571, 45.4350),
  'كركوك': (35.4681, 44.3922),
  'الأنبار': (33.4250, 43.3000),
  'ذي قار': (31.0525, 46.2572),
  'واسط': (32.5000, 45.8333),
  'ديالى': (33.7733, 45.1494),
  'بابل': (32.4680, 44.4260),
  'صلاح الدين': (34.6000, 43.6800),
  'ميسان': (31.8360, 47.1440),
  'المثنى': (31.3160, 45.2800),
  'القادسية': (31.9890, 44.9250),
  'دهوك': (36.8670, 42.9880),
};

class ProviderAddPropertyScreen extends ConsumerStatefulWidget {
  const ProviderAddPropertyScreen({super.key});

  @override
  ConsumerState<ProviderAddPropertyScreen> createState() =>
      _ProviderAddPropertyScreenState();
}

class _ProviderAddPropertyScreenState
    extends ConsumerState<ProviderAddPropertyScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _capacity = TextEditingController(text: '20');
  final _price = TextEditingController();
  String _type = 'FARM';
  String? _cityId;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _address.dispose();
    _capacity.dispose();
    _price.dispose();
    super.dispose();
  }

  (double, double) _coordsFor(CityOption? city) {
    if (city == null) return (33.3152, 44.3661);
    return _iraqCenters[city.nameAr] ??
        _iraqCenters[city.provinceName] ??
        (33.3152, 44.3661);
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final price = num.tryParse(_price.text.trim()) ?? 0;
    if (name.isEmpty || _cityId == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أكمل الاسم والمدينة والسعر')),
      );
      return;
    }

    final cities = ref.read(locationsProvider).value ?? [];
    CityOption? city;
    for (final item in cities) {
      if (item.id == _cityId) city = item;
    }
    final coords = _coordsFor(city);

    setState(() => _saving = true);
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/api/properties',
            body: {
              'type': _type,
              'name': name,
              'description': _description.text.trim(),
              'cityId': _cityId,
              'address': _address.text.trim().isEmpty
                  ? null
                  : _address.text.trim(),
              'latitude': coords.$1,
              'longitude': coords.$2,
              'capacity': int.tryParse(_capacity.text.trim()) ?? 0,
              'pricePerDay': price,
            },
          );
      ref.invalidate(providerPropertiesProvider);
      ref.invalidate(providerOverviewProvider);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('أُرسل المكان للمراجعة')));
      context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(maisonError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cities = ref.watch(locationsProvider);

    return Scaffold(
      body: MaisonWash(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            MaisonPageHeader(title: 'إضافة مكان', onBack: () => context.pop()),
            Text(
              'أدخل الاسم والمدينة والسعر. فريق VIBEES يزور المكان ويصوره بعد الموافقة — لا حاجة لرفع صور من هنا.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: VibesTheme.textTertiaryOf(context),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            FolioPanel(
              shadows: Vibes.card,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader('النوع'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          const [
                            ('FARM', 'مزرعة'),
                            ('HALL', 'قاعة'),
                            ('DECORATION', 'تزيين'),
                          ].map((item) {
                            final active = _type == item.$1;
                            return MaisonChip(
                              label: item.$2,
                              active: active,
                              onTap: () => setState(() => _type = item.$1),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 18),
                    MaisonField(
                      label: 'اسم المكان',
                      controller: _name,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    MaisonField(
                      label: 'وصف مختصر',
                      controller: _description,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    cities.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: ShimmerBox(height: 56, radius: VibesRadius.lg),
                      ),
                      error: (error, _) => Text(maisonError(error)),
                      data: (list) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المدينة',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Vibes.inkSecondary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 40,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                for (final city in list)
                                  Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      end: 8,
                                    ),
                                    child: MaisonChip(
                                      label: city.label,
                                      active: _cityId == city.id,
                                      onTap: () =>
                                          setState(() => _cityId = city.id),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    MaisonField(
                      label: 'العنوان التفصيلي',
                      controller: _address,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: MaisonField(
                            label: 'السعة',
                            controller: _capacity,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: MaisonField(
                            label: 'سعر اليوم (د.ع)',
                            controller: _price,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    VibesButton(
                      label: 'إرسال للمراجعة',
                      icon: Icons.send_rounded,
                      loading: _saving,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
