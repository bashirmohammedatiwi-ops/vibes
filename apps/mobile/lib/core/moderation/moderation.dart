import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/auth_controller.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../network/api_client.dart';

/// ═══════════════════════════════════════════════════════════
/// الإبلاغ والحظر — متطلب Apple 1.2 وسياسة Google للمحتوى.
/// • الإبلاغ يُرسل للسيرفر (يصل للدعم فوراً ويُراجع خلال 24 ساعة).
/// • الحظر يُخفي كل محتوى المستخدم عندك فوراً (منشورات، تعليقات، تقييمات،
///   محادثات) ويُبلغ الفريق أيضاً.
/// ═══════════════════════════════════════════════════════════

class ModerationState {
  const ModerationState({this.blockedUsers = const {}, this.hidden = const {}});

  /// معرّفات المستخدمين المحظورين.
  final Set<String> blockedUsers;

  /// عناصر أخفيتها بعد الإبلاغ: "TYPE:id".
  final Set<String> hidden;

  bool isBlocked(String? userId) =>
      userId != null && blockedUsers.contains(userId);
  bool isHidden(String type, String? id) =>
      id != null && hidden.contains('$type:$id');

  /// إخفاء عنصر إن كان مُبلغاً عنه أو كان صاحبه محظوراً.
  bool shouldHide(String type, String? id, {String? userId}) =>
      isHidden(type, id) || isBlocked(userId);
}

class ModerationController extends StateNotifier<ModerationState> {
  ModerationController() : super(const ModerationState()) {
    _load();
  }

  static const _kBlocked = 'moderation.blocked';
  static const _kHidden = 'moderation.hidden';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = ModerationState(
      blockedUsers: (p.getStringList(_kBlocked) ?? const []).toSet(),
      hidden: (p.getStringList(_kHidden) ?? const []).toSet(),
    );
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kBlocked, state.blockedUsers.toList());
    await p.setStringList(_kHidden, state.hidden.toList());
  }

  Future<void> hide(String type, String id) async {
    state = ModerationState(
      blockedUsers: state.blockedUsers,
      hidden: {...state.hidden, '$type:$id'},
    );
    await _save();
  }

  Future<void> block(String userId) async {
    state = ModerationState(
      blockedUsers: {...state.blockedUsers, userId},
      hidden: state.hidden,
    );
    await _save();
  }

  Future<void> unblock(String userId) async {
    state = ModerationState(
      blockedUsers: {...state.blockedUsers}..remove(userId),
      hidden: state.hidden,
    );
    await _save();
  }
}

final moderationProvider =
    StateNotifierProvider<ModerationController, ModerationState>(
      (ref) => ModerationController(),
    );

const _reasons = [
  'محتوى مسيء أو كراهية',
  'محتوى جنسي أو غير لائق',
  'تحرّش أو إزعاج',
  'احتيال أو معلومات مضللة',
  'رسائل مزعجة (سبام)',
  'سبب آخر',
];

/// قائمة «⋯» موحّدة: إبلاغ / حظر المستخدم. [type]: POST, COMMENT, REVIEW,
/// MESSAGE, CONVERSATION, USER, COLLECTION. تُرجع true إن أُخفي المحتوى.
Future<bool> showModerationSheet(
  BuildContext context,
  WidgetRef ref, {
  required String type,
  required String targetId,
  String? userId,
  String? userName,
  bool allowBlock = true,
}) async {
  final auth = ref.read(authControllerProvider);
  if (auth.user == null) {
    final ok = await context.push<bool>('/login');
    if (ok != true || !context.mounted) return false;
  }
  if (auth.user != null && userId != null && auth.user!.id == userId) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('هذا محتواك')));
    return false;
  }
  if (!context.mounted) return false;

  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: Color(0xFFC2402F)),
            title: const Text(
              'إبلاغ عن محتوى غير لائق',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: const Text(
              'يراجعه فريق VIBES خلال 24 ساعة',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            onTap: () => Navigator.pop(ctx, 'report'),
          ),
          if (allowBlock && userId != null)
            ListTile(
              leading: const Icon(
                Icons.block_rounded,
                color: Color(0xFFC2402F),
              ),
              title: Text(
                userName == null || userName.isEmpty
                    ? 'حظر هذا المستخدم'
                    : 'حظر $userName',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: const Text(
                'لن ترى محتواه أو رسائله بعد الآن',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              onTap: () => Navigator.pop(ctx, 'block'),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return false;

  String? reason;
  if (action == 'report') {
    reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'ما المشكلة؟',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            for (final r in _reasons)
              ListTile(
                title: Text(
                  r,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () => Navigator.pop(ctx, r),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (reason == null || !context.mounted) return false;
  } else {
    final ok = await showMaisonConfirm(
      context: context,
      title: 'حظر المستخدم؟',
      message: 'سيختفي محتواه ورسائله عندك، وسيُبلغ فريق VIBES لمراجعة حسابه.',
      confirmLabel: 'حظر',
      destructive: true,
    );
    if (!ok || !context.mounted) return false;
  }

  final mod = ref.read(moderationProvider.notifier);
  try {
    await ref
        .read(apiClientProvider)
        .post(
          '/api/reports',
          body: {
            'targetType': action == 'block' && type == 'USER' ? 'USER' : type,
            'targetId': targetId,
            if (reason != null) 'reason': reason,
            if (userId != null) 'reportedUserId': userId,
            if (action == 'block') 'block': true,
          },
        );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(maisonError(e))));
    }
    if (action == 'report') return false;
  }
  await mod.hide(type, targetId);
  if (action == 'block' && userId != null) await mod.block(userId);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          action == 'block'
              ? 'تم الحظر — لن ترى محتوى هذا المستخدم'
              : 'شكراً — وصل بلاغك وأخفينا المحتوى عنك',
        ),
      ),
    );
  }
  return true;
}
