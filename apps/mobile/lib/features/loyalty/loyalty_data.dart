import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../features/auth/auth_controller.dart';
import '../home/home_sections.dart';

class LoyaltyStamp {
  const LoyaltyStamp({
    required this.bookingId,
    required this.placeName,
    required this.date,
    this.discount = 0,
  });

  factory LoyaltyStamp.fromJson(Map<String, dynamic> json) => LoyaltyStamp(
    bookingId: json['bookingId'] as String? ?? '',
    placeName: json['placeName'] as String? ?? '',
    date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    discount: json['discount'] as num? ?? 0,
  );

  final String bookingId;
  final String placeName;
  final DateTime date;
  final num discount;
}

/// بطاقة ولاء واحدة: لكل نوع عدّاده المستقل.
class LoyaltyProgram {
  const LoyaltyProgram({
    required this.type,
    required this.enabled,
    required this.required,
    required this.percent,
    required this.stamps,
    required this.remaining,
    required this.rewardsAvailable,
    required this.inProgress,
    required this.lifetimeRewards,
    required this.lifetimeSaved,
    required this.stampHistory,
    required this.rewardHistory,
  });

  factory LoyaltyProgram.fromJson(Map<String, dynamic> json) {
    List<LoyaltyStamp> list(String key) => (json[key] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(LoyaltyStamp.fromJson)
        .toList();
    return LoyaltyProgram(
      type: json['type'] as String? ?? 'FARM',
      enabled: json['enabled'] as bool? ?? false,
      required: (json['required'] as num? ?? 5).toInt(),
      percent: (json['percent'] as num? ?? 25).toInt(),
      stamps: (json['stamps'] as num? ?? 0).toInt(),
      remaining: (json['remaining'] as num? ?? 5).toInt(),
      rewardsAvailable: (json['rewardsAvailable'] as num? ?? 0).toInt(),
      inProgress: (json['inProgress'] as num? ?? 0).toInt(),
      lifetimeRewards: (json['lifetimeRewards'] as num? ?? 0).toInt(),
      lifetimeSaved: json['lifetimeSaved'] as num? ?? 0,
      stampHistory: list('stampHistory'),
      rewardHistory: list('rewardHistory'),
    );
  }

  final String type;
  final bool enabled;
  final int required;
  final int percent;
  final int stamps;
  final int remaining;
  final int rewardsAvailable;
  final int inProgress;
  final int lifetimeRewards;
  final num lifetimeSaved;
  final List<LoyaltyStamp> stampHistory;
  final List<LoyaltyStamp> rewardHistory;

  bool get rewardReady => rewardsAvailable > 0;
  HomeSection get section => sectionForType(type);
}

class LoyaltyStatus {
  const LoyaltyStatus({required this.enabled, required this.programs});

  final bool enabled;
  final List<LoyaltyProgram> programs;

  LoyaltyProgram? forType(String type) {
    for (final p in programs) {
      if (p.type == type.toUpperCase()) return p;
    }
    return null;
  }

  int get rewardsReady =>
      programs.where((p) => p.enabled && p.rewardReady).length;
}

final loyaltyProvider = FutureProvider<LoyaltyStatus?>((ref) async {
  if (!ref.watch(authControllerProvider).loggedIn) return null;
  final data = await ref.watch(apiClientProvider).get('/api/loyalty/me');
  if (data is! Map<String, dynamic>) return null;
  return LoyaltyStatus(
    enabled: data['enabled'] as bool? ?? false,
    programs: (data['programs'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(LoyaltyProgram.fromJson)
        .toList(),
  );
});
