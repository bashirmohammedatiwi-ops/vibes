import 'package:flutter/material.dart';

import 'theme.dart';

Color shiftColor(String? raw) => switch (raw) {
      'MORNING' => placeShiftMorning,
      'EVENING' => placeShiftEvening,
      _ => placeShiftFull,
    };

String shiftLabel(String? raw) => switch (raw) {
      'MORNING' => 'شفت صباحي',
      'EVENING' => 'شفت مسائي',
      _ => 'يوم كامل',
    };

String shiftBadgeChar(String? raw) => switch (raw) {
      'MORNING' => 'ص',
      'EVENING' => 'م',
      _ => 'ك',
    };

String bookingStatusAr(String? raw) => switch (raw) {
      'PENDING' => 'بانتظار التأكيد',
      'AWAITING_PAYMENT' => 'بانتظار الدفع',
      'CONFIRMED' => 'مؤكد',
      'COMPLETED' => 'مكتمل',
      'CANCELLED' => 'ملغى',
      _ => raw ?? '',
    };

String presenceLabel(String? raw) => switch (raw) {
      'AVAILABLE' => 'متاح',
      'RINGING' => 'رنين',
      'IN_CALL' => 'في مكالمة',
      'WRAP_UP' => 'تغليف',
      'AWAY' => 'استراحة',
      _ => 'غير متصل',
    };

Color presenceColor(String? raw) => switch (raw) {
      'AVAILABLE' => placeSuccess,
      'RINGING' => placeBrass,
      'IN_CALL' => const Color(0xFF2563EB),
      'WRAP_UP' => placeShiftEvening,
      'AWAY' => placeShiftMorning,
      _ => placeInk2,
    };
