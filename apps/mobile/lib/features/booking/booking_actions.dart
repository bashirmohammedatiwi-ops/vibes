import 'package:flutter/material.dart';
import '../../core/i18n/i18n.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/vibes_widgets.dart';
import 'booking_providers.dart';

/// ═══════════════════════════════════════════════════════════
/// إجراءات الزبون على حجزه — مكان واحد تستخدمه بطاقة الحجز
/// وصفحة التفاصيل والمحادثة:
///  • إلغاء مباشر قبل التأكيد وقبل رفع إثبات دفع.
///  • طلب إلغاء واسترداد بعد التأكيد أو بعد رفع إثبات الدفع.
/// كل إجراء يمرّ برسالة تأكيد أولاً.
/// ═══════════════════════════════════════════════════════════

/// دفع الزبون (أو رفع إيصالاً) فالإلغاء يحتاج مراجعة لاسترداد المبلغ.
bool bookingHasPayment(Booking b) =>
    b.payment?.isPaid == true || b.payment?.proofUrl != null;

/// إلغاء فوري: الحجز لم يُؤكَّد ولم يُدفع شيء بعد.
bool canCancelDirectly(Booking b) =>
    (b.status == BookingStatus.pending ||
        b.status == BookingStatus.awaitingPayment) &&
    !bookingHasPayment(b);

/// طلب إلغاء واسترداد: بعد التأكيد، أو بعد الدفع وقبل التأكيد.
bool canRequestRefund(Booking b) =>
    b.cancellationStatus != 'PENDING' &&
    (b.status == BookingStatus.confirmed ||
        ((b.status == BookingStatus.pending ||
                b.status == BookingStatus.awaitingPayment) &&
            bookingHasPayment(b)));

/// طلب إلغاء مُرسل وينتظر المراجعة.
bool refundRequestPending(Booking b) => b.cancellationStatus == 'PENDING';

int _daysUntil(DateTime start) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return DateTime(start.year, start.month, start.day).difference(today).inDays;
}

/// الاسترداد المتوقع وفق السياسة: كامل قبل 7 أيام، نصف بين 3 و6 أيام.
num expectedRefund(Booking b) {
  final days = _daysUntil(b.startDate);
  final rate = days >= 7
      ? 1.0
      : days >= 3
      ? 0.5
      : 0.0;
  return (b.totalPrice * rate).round();
}

void _refresh(WidgetRef ref, Booking b) {
  ref.invalidate(myBookingsProvider);
  ref.invalidate(bookingDetailProvider(b.id));
}

void _toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );
}

/// إلغاء حجز لم يُؤكَّد بعد — بعد رسالة تأكيد. يعيد true عند النجاح.
Future<bool> cancelBookingFlow(
  BuildContext context,
  WidgetRef ref,
  Booking b,
) async {
  final ok = await showMaisonConfirm(
    context: context,
    title: 'إلغاء الحجز؟'.tr,
    message:
        '{name} — سيُلغى طلبك ويعود الموعد متاحاً لغيرك. لا يمكن التراجع عن هذا.' // i18n-ok
            .trArgs({'name': b.propertyName ?? 'المكان'.tr}),
    confirmLabel: 'نعم، ألغِ الحجز'.tr,
    cancelLabel: 'تراجع'.tr,
    destructive: true,
  );
  if (!ok || !context.mounted) return false;
  HapticFeedback.mediumImpact();
  try {
    await ref.read(apiClientProvider).post('/api/bookings/${b.id}/cancel');
    _refresh(ref, b);
    if (context.mounted) _toast(context, 'تم إلغاء الحجز'.tr);
    return true;
  } catch (e) {
    if (context.mounted) _toast(context, maisonError(e));
    return false;
  }
}

/// طلب إلغاء واسترداد — بعد التأكيد أو بعد الدفع. يعيد true عند الإرسال.
Future<bool> requestRefundFlow(
  BuildContext context,
  WidgetRef ref,
  Booking b,
) async {
  final expected = expectedRefund(b);
  final reason = await showMaisonPrompt(
    context: context,
    title: 'طلب إلغاء واسترداد'.tr,
    message: expected > 0
        ? 'الاسترداد المتوقع: {amount} د.ع — كامل قبل 7 أيام من الموعد، ونصف بين 3 و6 أيام. يراجع الفريق طلبك ويبلغك بالنتيجة.' // i18n-ok
              .trArgs({'amount': PriceText.format(expected)})
        : 'وفق سياسة الإلغاء لا يُسترد مبلغ لموعد أقرب من 3 أيام، ويمكنك إرسال الطلب للمراجعة.' // i18n-ok
              .tr,
    hint: 'سبب الإلغاء (اختياري)'.tr,
    confirmLabel: 'إرسال الطلب'.tr,
    cancelLabel: 'تراجع'.tr,
  );
  if (reason == null || !context.mounted) return false;
  HapticFeedback.mediumImpact();
  try {
    await ref
        .read(apiClientProvider)
        .post(
          '/api/cancellations',
          body: {'bookingId': b.id, 'reason': reason},
        );
    _refresh(ref, b);
    if (context.mounted) {
      _toast(context, 'أُرسل طلب الإلغاء — سنبلغك بالنتيجة'.tr);
    }
    return true;
  } catch (e) {
    if (context.mounted) _toast(context, maisonError(e));
    return false;
  }
}
