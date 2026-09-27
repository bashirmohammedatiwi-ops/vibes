import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../features/auth/auth_controller.dart';
import '../models/models.dart';

final notificationsProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final data = await client.get('/api/notifications', queryParameters: {
    'pageSize': 50,
  });
  final items = data is Map<String, dynamic> ? data['items'] : data;
  return (items as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .toList() ??
      const [];
});

final conversationsProvider =
    FutureProvider<List<ConversationSummary>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final data = await client.get('/api/conversations');
  return (data as List<dynamic>)
      .whereType<Map<String, dynamic>>()
      .map(ConversationSummary.fromJson)
      .toList();
});

final conversationTitleProvider =
    Provider.family<String, String>((ref, id) {
  final fromList = ref.watch(conversationsProvider).valueOrNull;
  final match = fromList?.where((c) => c.id == id);
  if (match != null && match.isNotEmpty && match.first.title.isNotEmpty) {
    return match.first.title;
  }
  return 'المحادثة';
});

final chatMessagesProvider =
    FutureProvider.family<List<ChatMessage>, String>((ref, id) async {
  final client = ref.watch(apiClientProvider);
  final data = await client.get('/api/conversations/$id/messages');
  return (data as List<dynamic>)
      .whereType<Map<String, dynamic>>()
      .map(ChatMessage.fromJson)
      .toList();
});

final offersProvider = FutureProvider<List<PriceOfferItem>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final data = await client.get('/api/offers');
  return (data as List<dynamic>)
      .whereType<Map<String, dynamic>>()
      .map(PriceOfferItem.fromJson)
      .toList();
});

final collectionsProvider =
    FutureProvider<List<SavedCollection>>((ref) async {
  if (!ref.watch(authControllerProvider).loggedIn) return const [];
  final client = ref.watch(apiClientProvider);
  final data = await client.get('/api/collections');
  return (data as List<dynamic>)
      .whereType<Map<String, dynamic>>()
      .map(SavedCollection.fromJson)
      .toList();
});

final experiencesProvider =
    FutureProvider<List<SocialExperience>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final data = await client.get('/api/social/feed', queryParameters: {
    'pageSize': 30,
  });
  final items = data is Map<String, dynamic> ? data['items'] : data;
  return (items as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map(SocialExperience.fromJson)
          .toList() ??
      const [];
});

final followStatusProvider =
    FutureProvider.family<({bool following, int followers}), String>(
        (ref, providerId) async {
  ref.watch(authControllerProvider);
  final client = ref.watch(apiClientProvider);
  final data = await client.get('/api/follows/$providerId');
  final map = data as Map<String, dynamic>;
  return (
    following: map['following'] == true,
    followers: (map['followers'] as num?)?.toInt() ?? 0,
  );
});

final conversationsUnreadProvider = FutureProvider<int>((ref) async {
  try {
    final data = await ref.watch(apiClientProvider).get('/api/conversations/unread');
    if (data is Map<String, dynamic>) {
      return (data['unread'] as num?)?.toInt() ?? 0;
    }
  } catch (_) {}
  return 0;
});

final notificationsUnreadProvider = FutureProvider<int>((ref) async {
  try {
    final data = await ref.watch(apiClientProvider).get('/api/notifications/unread');
    if (data is Map<String, dynamic>) {
      return (data['unread'] as num?)?.toInt() ?? 0;
    }
  } catch (_) {}
  return 0;
});

final followingExperiencesProvider =
    FutureProvider<List<SocialExperience>>((ref) async {
  if (!ref.watch(authControllerProvider).loggedIn) return const [];
  final client = ref.watch(apiClientProvider);
  final data = await client.get('/api/social/feed/following', queryParameters: {
    'pageSize': 30,
  });
  final items = data is Map<String, dynamic> ? data['items'] : data;
  return (items as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map(SocialExperience.fromJson)
          .toList() ??
      const [];
});

final bookingRequestsProvider =
    FutureProvider<({List<Map<String, dynamic>> cancellations, List<Map<String, dynamic>> refunds})>(
        (ref) async {
  final data =
      await ref.watch(apiClientProvider).get('/api/booking-requests') as Map<String, dynamic>;
  return (
    cancellations: (data['cancellations'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(),
    refunds: (data['refunds'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(),
  );
});

final publicCouponsProvider = FutureProvider<List<PublicCoupon>>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/api/coupons');
  return (data as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map(PublicCoupon.fromJson)
          .toList() ??
      const [];
});

final followingProvidersProvider =
    FutureProvider<List<FollowedProvider>>((ref) async {
  if (!ref.watch(authControllerProvider).loggedIn) return const [];
  try {
    final data = await ref.watch(apiClientProvider).get('/api/follows');
    return (data as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(FollowedProvider.fromJson)
            .toList() ??
        const [];
  } catch (_) {
    return const [];
  }
});

final publicCollectionsProvider =
    FutureProvider<List<SavedCollection>>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/api/collections/public');
  return (data as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map(SavedCollection.fromJson)
          .toList() ??
      const [];
});
