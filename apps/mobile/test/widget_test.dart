import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vibes/shared/widgets/vibes_widgets.dart';
import 'package:vibes/shared/models/models.dart';

void main() {
  testWidgets('PriceText ينسق الأرقام بفواصل ذهبية', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: PriceText(250000))),
      ),
    );
    expect(find.text('250,000'), findsOneWidget);
    expect(find.text('د.ع'), findsOneWidget);
  });

  test('format السعر', () {
    expect(PriceText.format(999), '999');
    expect(PriceText.format(1000), '1,000');
    expect(PriceText.format(250000), '250,000');
    expect(PriceText.format(1234567), '1,234,567');
  });

  test('تحويل Property من JSON بتحويل دفاعي', () {
    final property = Property.fromJson({
      'id': 'p1',
      'name': 'مزرعة النخيل',
      'type': 'FARM',
      'pricePerDay': '250000', // نص من الـ API
      'capacity': 80,
      'bookingMode': 'HYBRID',
      'city': {
        'nameAr': 'بغداد',
        'province': {'nameAr': 'بغداد'},
      },
      'amenityLinks': [
        {
          'amenity': {
            'id': 'a1',
            'nameAr': 'مسبح',
            'icon': '🏊',
            'category': 'ترفيه',
          }
        }
      ],
      'media': [
        {'id': 'm1', 'url': 'https://x/1.jpg', 'type': 'IMAGE'},
        {'id': 'm2', 'url': 'https://x/v.mp4', 'type': 'VIDEO',
         'aspectRatio': '9:16', 'posterUrl': 'https://x/p.jpg'},
      ],
    });

    expect(property.pricePerDay, 250000);
    expect(property.type, PropertyType.farm);
    expect(property.supportsShifts, isTrue);
    expect(property.amenities.first.nameAr, 'مسبح');
    expect(property.coverUrl, 'https://x/1.jpg');
    expect(property.firstVideo?.isVertical, isTrue);
    expect(property.shiftLabels.morning, contains('08:00'));
  });

  test('تحويل Booking وحالاته', () {
    final booking = Booking.fromJson({
      'id': 'b1',
      'propertyId': 'p1',
      'startDate': '2026-09-14T00:00:00.000Z',
      'endDate': '2026-09-16T00:00:00.000Z',
      'shift': 'MORNING',
      'guests': 30,
      'status': 'AWAITING_PAYMENT',
      'totalPrice': '360000',
      'discountAmount': 40000,
      'payment': {'id': 'pay1', 'status': 'PENDING'},
      'user': {'name': 'علي', 'phone': '9647700000003'},
    });

    expect(booking.status, BookingStatus.awaitingPayment);
    expect(booking.shift, ShiftType.morning);
    expect(booking.nights, 2);
    expect(booking.totalPrice, 360000);
    expect(booking.userPhone, '9647700000003');
    expect(booking.payment?.isPaid, isFalse);
  });
}
