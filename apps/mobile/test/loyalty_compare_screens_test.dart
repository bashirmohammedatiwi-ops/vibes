import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibes/core/i18n/i18n.dart';
import 'package:vibes/core/theme/app_theme.dart';
import 'package:vibes/core/theme/world_theme.dart';
import 'package:vibes/features/compare/compare_feature.dart';
import 'package:vibes/features/loyalty/loyalty_data.dart';
import 'package:vibes/features/loyalty/loyalty_screen.dart';
import 'package:vibes/features/loyalty/loyalty_widgets.dart';
import 'package:vibes/features/home/home_sections.dart';
import 'package:vibes/shared/data/property_providers.dart';
import 'package:vibes/shared/models/models.dart';

Property _place(String id, num price, int capacity, double rating) =>
    Property.fromJson({
      'id': id,
      'name': 'مكان $id',
      'type': 'FARM',
      'pricePerDay': price,
      'capacity': capacity,
      'ratingAvg': rating,
      'ratingCount': 4,
      'latitude': 33.3,
      'longitude': 44.4,
    });

LoyaltyProgram _program(String type, int stamps, int rewards) => LoyaltyProgram(
  type: type,
  enabled: true,
  required: 5,
  percent: 25,
  stamps: stamps,
  remaining: 5 - stamps,
  rewardsAvailable: rewards,
  inProgress: 1,
  lifetimeRewards: 1,
  lifetimeSaved: 250000,
  stampHistory: [
    for (var i = 0; i < stamps; i++)
      LoyaltyStamp(bookingId: '$i', placeName: 'مكان', date: DateTime(2026, 10, 1)),
  ],
  rewardHistory: [
    LoyaltyStamp(
      bookingId: 'r',
      placeName: 'مكان',
      date: DateTime(2026, 9, 1),
      discount: 250000,
    ),
  ],
);

Widget _app(Widget child, List<Override> overrides) {
  final theme = Appearance.isDark ? VibesTheme.dark() : VibesTheme.light();
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: applyWorld(theme, WorldPalette.farm),
      locale: Locale(I18n.locale),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  tearDown(() {
    I18n.locale = 'ar';
    Appearance.isDark = false;
  });

  for (final locale in ['ar', 'en']) {
    for (final dark in [false, true]) {
      final mode = '$locale ${dark ? 'dark' : 'light'}';

      testWidgets('loyalty card, in progress and ready: $mode', (tester) async {
        I18n.locale = locale;
        Appearance.isDark = dark;
        await tester.binding.setSurfaceSize(const Size(360, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _app(const LoyaltyScreen(), [
            loyaltyProvider.overrideWith(
              (ref) async => LoyaltyStatus(
                enabled: true,
                programs: [
                  _program('FARM', 5, 1),
                  _program('HALL', 2, 0),
                  _program('DECORATION', 0, 0),
                ],
              ),
            ),
          ]),
        );
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
        expect(find.textContaining('%'), findsWidgets);
      });

      testWidgets('compare two places: $mode', (tester) async {
        I18n.locale = locale;
        Appearance.isDark = dark;
        await tester.binding.setSurfaceSize(const Size(360, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final a = _place('a', 500000, 100, 4.5);
        final b = _place('b', 700000, 300, 4.9);
        await tester.pumpWidget(
          _app(const CompareScreen(), [
            compareSelectionProvider.overrideWith((ref) {
              final c = CompareSelectionController();
              c.toggle(a);
              c.toggle(b);
              return c;
            }),
            propertyDetailProvider.overrideWith(
              (ref, id) async => id == 'a' ? a : b,
            ),
          ]),
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        expect(find.text('مكان a'), findsWidgets);
      });

      testWidgets('booking offer states: $mode', (tester) async {
        I18n.locale = locale;
        Appearance.isDark = dark;
        await tester.pumpWidget(
          _app(
            Column(
              children: [
                LoyaltyBookingOffer(
                  offer: const {
                    'eligible': true,
                    'percent': 25,
                    'discount': 250000,
                    'required': 5,
                    'stamps': 5,
                    'remaining': 0,
                  },
                  applied: true,
                  section: HomeSection.farm,
                  onChanged: (_) {},
                ),
                LoyaltyBookingOffer(
                  offer: const {
                    'eligible': false,
                    'percent': 25,
                    'discount': 0,
                    'required': 5,
                    'stamps': 3,
                    'remaining': 2,
                  },
                  applied: false,
                  section: HomeSection.hall,
                  onChanged: (_) {},
                ),
              ],
            ),
            const [],
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
