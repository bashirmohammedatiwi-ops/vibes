import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _iqd = NumberFormat('#,###', 'ar');

String formatIqd(dynamic value) {
  if (value == null) return '—';
  final n = value is num ? value.toDouble() : double.tryParse('$value');
  if (n == null) return '$value';
  return '${_iqd.format(n.round())} د.ع';
}

String paymentStatusAr(String? raw) => switch (raw) {
      'PENDING' => 'بانتظار التحقق',
      'PAID' => 'مدفوع',
      'FAILED' => 'فشل',
      'REFUNDED' => 'مسترد',
      _ => raw ?? '—',
    };

Color paymentStatusColor(String? raw) {
  return switch (raw) {
    'PAID' => const Color(0xFF0D9488),
    'PENDING' => const Color(0xFFD97706),
    'FAILED' => const Color(0xFFDC2626),
    _ => const Color(0xFF5A6678),
  };
}
