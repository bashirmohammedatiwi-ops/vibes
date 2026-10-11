import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/auth_controller.dart';
import '../../shared/data/marketplace_providers.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/maison_shapes.dart';
import '../../shared/widgets/vibes_graphics.dart';
import '../../shared/widgets/vibes_widgets.dart';
import 'call_screen.dart';
import '../booking/booking_actions.dart';
import '../booking/booking_providers.dart';
import '../../core/theme/world_theme.dart';
import '../../core/utils/vibes_net_image.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    this.incomingCallId,
    this.payHintBookingId,
  });

  final String conversationId;
  final String? incomingCallId;

  /// معرف حجز جديد لم يُدفع — يعرض لوحة إرشاد إثبات الدفع أعلى المحادثة
  final String? payHintBookingId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  bool _payHintDismissed = false;
  Timer? _poll;
  StreamSubscription<dynamic>? _sse;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startLive();
      ref.invalidate(conversationsUnreadProvider);
      ref.invalidate(conversationsProvider);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _sse?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startLive() async {
    final streamed = await _listenSse();
    if (!streamed && mounted) {
      _poll = Timer.periodic(const Duration(seconds: 2), (_) {
        if (isAppResumed) _pullNew();
      });
    }
  }

  Future<bool> _listenSse() async {
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.dio.get<ResponseBody>(
        '/api/conversations/${widget.conversationId}/stream',
        options: Options(
          responseType: ResponseType.stream,
          headers: const {'Accept': 'text/event-stream'},
          receiveTimeout: const Duration(minutes: 30),
        ),
      );
      final stream = res.data?.stream;
      if (stream == null) return false;
      _sse = stream.listen(
        (chunk) {
          final text = String.fromCharCodes(chunk);
          if (text.contains('"type":"ping"') || text.trim().isEmpty) return;
          if (text.contains('data:') && isAppResumed) {
            _pullNew();
          }
        },
        onError: (_) {
          _poll ??= Timer.periodic(const Duration(seconds: 4), (t) {
            if (isAppResumed) _pullNew();
          });
        },
        onDone: () {
          _poll ??= Timer.periodic(const Duration(seconds: 4), (t) {
            if (isAppResumed) _pullNew();
          });
        },
        cancelOnError: true,
      );
      // احتياطي سريع — SSE قد يتأخر عبر الشبكة
      _poll = Timer.periodic(const Duration(seconds: 3), (_) {
        if (isAppResumed) _pullNew();
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _pullNew() async {
    try {
      final current =
          ref.read(chatMessagesProvider(widget.conversationId)).valueOrNull ??
          const [];
      final last = current.isEmpty ? null : current.last.createdAt;
      final data = await ref
          .read(apiClientProvider)
          .get(
            '/api/conversations/${widget.conversationId}/messages',
            queryParameters: {
              if (last != null) 'after': last.toUtc().toIso8601String(),
              'pageSize': 30,
            },
          );
      final incoming = (data as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map((row) => row['id'] as String?)
          .whereType<String>();
      final known = current.map((m) => m.id).toSet();
      if (last == null || incoming.any((id) => !known.contains(id))) {
        ref.invalidate(chatMessagesProvider(widget.conversationId));
      }
    } catch (_) {}
  }

  Future<void> _sendImage() async {
    if (_sending) return;
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (photo == null) return;
    setState(() => _sending = true);
    try {
      final bytes = await photo.readAsBytes();
      final name = photo.name.isEmpty ? 'chat.jpg' : photo.name;
      await ref
          .read(apiClientProvider)
          .upload(
            '/api/conversations/${widget.conversationId}/messages/image',
            fieldName: 'file',
            file: MultipartFile.fromBytes(bytes, filename: name),
            fields: {
              if (_controller.text.trim().isNotEmpty)
                'body': _controller.text.trim(),
            },
          );
      _controller.clear();
      ref.invalidate(chatMessagesProvider(widget.conversationId));
      ref.invalidate(conversationsProvider);
    } catch (e) {
      if (!mounted) return;
      showVibesToast(context, maisonError(e), type: VibesToastType.danger);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/api/conversations/${widget.conversationId}/messages',
            body: {'body': text},
          );
      _controller.clear();
      ref.invalidate(chatMessagesProvider(widget.conversationId));
      ref.invalidate(conversationsProvider);
    } catch (e) {
      if (!mounted) return;
      showVibesToast(context, maisonError(e), type: VibesToastType.danger);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// إغلاق تنبيه الدفع لا يلغي الحجز — نوضّح ذلك ونعرض الخيارات.
  Future<void> _confirmHidePayHint() async {
    final bookingId = widget.payHintBookingId;
    if (bookingId == null) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PayHintSheet(),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'hide':
        setState(() => _payHintDismissed = true);
      case 'view':
        context.push('/booking/$bookingId');
      case 'cancel':
        try {
          final booking = await ref.read(
            bookingDetailProvider(bookingId).future,
          );
          if (!mounted) return;
          if (!canCancelDirectly(booking)) {
            context.push('/booking/$bookingId');
            return;
          }
          final done = await cancelBookingFlow(context, ref, booking);
          if (done && mounted) setState(() => _payHintDismissed = true);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(maisonError(e))));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider(widget.conversationId));
    final myId = ref.watch(authControllerProvider).user?.id;
    final thread = ref
        .watch(conversationsProvider)
        .valueOrNull
        ?.where((c) => c.id == widget.conversationId)
        .firstOrNull;
    final bookingId = thread?.bookingId;

    // «متصل الآن» — رسالة حديثة من الطرف الآخر خلال آخر 90 ثانية.
    final lastAt = thread?.updatedAt;
    final fromPeer =
        thread != null &&
        thread.lastMessageSenderId != null &&
        thread.lastMessageSenderId != myId;
    final peerActive =
        lastAt != null &&
        fromPeer &&
        DateTime.now().difference(lastAt).inSeconds < 90;

    return Scaffold(
      body: MaisonWash(
        child: Column(
          children: [
            MaisonPageHeader(
              title: ref.watch(
                conversationTitleProvider(widget.conversationId),
              ),
              kicker: peerActive
                  ? 'متصل الآن'
                  : (thread?.stage ?? 'محادثة خاصة'),
              onBack: () => context.pop(),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'اتصل',
                    onPressed: () => startCall(
                      ref,
                      context,
                      conversationId: widget.conversationId,
                    ),
                    icon: const Icon(Icons.call_outlined),
                  ),
                  if (bookingId != null && bookingId.isNotEmpty)
                    IconButton(
                      tooltip: 'الحجز',
                      onPressed: () => context.push('/booking/$bookingId'),
                      icon: const Icon(Icons.receipt_long_outlined),
                    ),
                ],
              ),
            ),
            if (thread != null &&
                thread.kind != 'SUPPORT' &&
                thread.title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SurfaceListCard(
                  accent: Vibes.teal,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              thread.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            if (thread.cityName != null &&
                                thread.cityName!.isNotEmpty)
                              Text(
                                thread.cityName!,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: VibesTheme.textTertiaryOf(context),
                                    ),
                              ),
                          ],
                        ),
                      ),
                      if (thread.pricePerDay != null)
                        PriceText(thread.pricePerDay!, compact: true),
                    ],
                  ),
                ),
              ),
            if (widget.payHintBookingId != null && !_payHintDismissed)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SurfaceListCard(
                  accent: Vibes.teal,
                  highlighted: true,
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Vibes.tealMint,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: Vibes.honeyDeep,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'وصل طلبك للفريق',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'أرفق إثبات الدفع بالصورة (📎) هنا ليؤكد الفريق حجزك فوراً',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: VibesTheme.textTertiaryOf(context),
                                    height: 1.5,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'إخفاء',
                        visualDensity: VisualDensity.compact,
                        onPressed: _confirmHidePayHint,
                        icon: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: VibesTheme.textTertiaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (widget.incomingCallId != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: FolioPanel(
                  railColor: Vibes.teal,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                    child: Row(
                      children: [
                        const Expanded(child: Text('مكالمة واردة')),
                        TextButton(
                          onPressed: () =>
                              joinCall(ref, context, widget.incomingCallId!),
                          child: const Text('انضمام'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: messages.when(
                loading: () => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: const [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ShimmerBox(width: 220, height: 56, radius: 12),
                    ),
                    SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: ShimmerBox(width: 180, height: 48, radius: 12),
                    ),
                    SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ShimmerBox(width: 160, height: 48, radius: 12),
                    ),
                  ],
                ),
                error: (e, _) => ErrorCanvas(
                  message: maisonError(e),
                  onRetry: () => ref.invalidate(
                    chatMessagesProvider(widget.conversationId),
                  ),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const EmptyCanvas(
                      icon: Icons.chat_outlined,
                      title: 'ابدأ المحادثة',
                      subtitle: 'اكتب سؤالك للمالك أو لفريق VIBES',
                    );
                  }
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final index = list.length - 1 - i;
                      final m = list[index];
                      final created = m.createdAt ?? DateTime.now();
                      // فاصل يوم بين رسائل يومين مختلفين
                      final prev = index > 0 ? list[index - 1] : null;
                      final newDay =
                          prev == null ||
                          !_sameDay(prev.createdAt ?? created, created);

                      Widget bubble;
                      if (m.isSystem) {
                        bubble = _SystemNote(text: m.body);
                      } else if (m.kind == 'CALL') {
                        bubble = _CallChip(
                          body: m.body,
                          outgoing: m.senderId == myId,
                        );
                      } else {
                        final mine = m.senderId != null && m.senderId == myId;
                        bubble = _MessageBubble(message: m, mine: mine);
                      }

                      return Column(
                        children: [
                          if (newDay && i > 0) _DayDivider(date: created),
                          bubble,
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: VibesTheme.surfaceOf(context).withValues(alpha: .96),
                boxShadow: [
                  BoxShadow(
                    color: Vibes.coral.withValues(alpha: .08),
                    blurRadius: 16,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _sending ? null : _sendImage,
                            icon: const Icon(Icons.image_outlined),
                          ),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: VibesTheme.canvasOf(context),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: VibesTheme.hairlineOf(context),
                                ),
                              ),
                              child: TextField(
                                controller: _controller,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _send(),
                                decoration: const InputDecoration(
                                  hintText: 'اكتب رسالة...',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: VibesTheme.actionOf(context),
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: IconButton(
                                onPressed: _sending ? null : _send,
                                icon: _sending
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        Icons.send_rounded,
                                        color: VibesTheme.onActionOf(context),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _timeLabel(DateTime d) {
  final now = DateTime.now();
  if (_sameDay(d, now)) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (_sameDay(d, yesterday)) return 'أمس';
  return '${d.day}/${d.month}';
}

/// فقاعة رسالة — طابع زمني خفيف داخلها يظهر متى كُتبت
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine});

  final dynamic message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final m = message;
    return Align(
      alignment: mine
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: ShapeDecoration(
          color: mine
              ? VibesTheme.actionOf(context)
              : VibesTheme.surfaceOf(context),
          shadows: [
            BoxShadow(
              color: const Color(0x0F0F2138),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(4),
              topRight: const Radius.circular(14),
              bottomLeft: const Radius.circular(14),
              bottomRight: const Radius.circular(14),
            ),
            side: BorderSide(
              color: mine
                  ? const Color(0x99C89844)
                  : VibesTheme.hairlineOf(context),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m.imageUrl != null && (m.imageUrl as String).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipPath(
                  clipper: const ShapeBorderClipper(shape: Folio.shape),
                  child: VibesNetImage(
                    url: m.imageUrl as String,
                    width: 220,
                    height: 160,
                  ),
                ),
              ),
            if ((m.body as String).isNotEmpty)
              Text(
                m.body as String,
                style: TextStyle(
                  color: mine
                      ? VibesTheme.onActionOf(context)
                      : VibesTheme.textPrimaryOf(context),
                  height: 1.45,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              _timeLabel(m.createdAt as DateTime),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: mine
                    ? VibesTheme.onActionOf(context).withValues(alpha: .55)
                    : VibesTheme.textTertiaryOf(context),
                fontSize: 10,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// رقاقة مكالمة — اتجاه + نص الحالة بأسلوب سجل المكالمات
class _CallChip extends StatelessWidget {
  const _CallChip({required this.body, required this.outgoing});

  final String body;
  final bool outgoing;

  @override
  Widget build(BuildContext context) {
    final missed = body.contains('لم يُرد') || body.contains('مرفوضة');
    final color = missed
        ? SemanticColors.danger
        : outgoing
        ? Vibes.honeyDeep
        : Vibes.coral;
    return Align(
      alignment: AlignmentDirectional.center,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: ShapeDecoration(
          color: color.withValues(alpha: .08),
          shape: RoundedRectangleBorder(
            borderRadius: Folio.compact,
            side: BorderSide(color: color.withValues(alpha: .25)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              outgoing ? Icons.north_west_rounded : Icons.south_east_rounded,
              size: 13,
              color: color,
            ),
            const SizedBox(width: 6),
            Icon(
              missed ? Icons.call_end_rounded : Icons.call_rounded,
              size: 13,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              body,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// فاصل يوم — خط شعري مع التاريخ وسطه
class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final label = _sameDay(date, now)
        ? 'اليوم'
        : _sameDay(date, now.subtract(const Duration(days: 1)))
        ? 'أمس'
        : '${date.day}/${date.month}${date.year != now.year ? '/${date.year}' : ''}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Container(height: 1, color: VibesTheme.hairlineOf(context)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: VibesTheme.textTertiaryOf(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Container(height: 1, color: VibesTheme.hairlineOf(context)),
          ),
        ],
      ),
    );
  }
}

/// ملاحظة نظام — أحداث الافتتاح والربط
class _SystemNote extends StatelessWidget {
  const _SystemNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: VibesTheme.textTertiaryOf(context),
          ),
        ),
      ),
    );
  }
}

class _PayHintSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.world;
    Widget option(
      String value,
      IconData icon,
      String title,
      String sub, {
      Color? color,
    }) {
      final c = color ?? p.accentDeep;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: const Color(0xFFF6F7F9),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.pop(context, value),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, color: c, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: color ?? Vibes.ink,
                          ),
                        ),
                        Text(
                          sub,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Vibes.inkTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDFE3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: p.fill,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_available_rounded,
                color: p.onAccent,
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'حجزك محفوظ',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Vibes.ink,
            ),
          ),
          const Text(
            'طلبك بانتظار التأكيد وتجده دائماً في «حجوزاتي». إخفاء هذا التنبيه لا يلغي الحجز.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Vibes.inkTertiary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          option(
            'view',
            Icons.receipt_long_rounded,
            'عرض الحجز',
            'التفاصيل والدفع وحالة التأكيد',
          ),
          option(
            'hide',
            Icons.visibility_off_rounded,
            'إخفاء التنبيه فقط',
            'يبقى حجزك كما هو',
          ),
          option(
            'cancel',
            Icons.event_busy_rounded,
            'إلغاء الحجز',
            'سنطلب تأكيدك قبل الإلغاء',
            color: const Color(0xFFDC2626),
          ),
        ],
      ),
    );
  }
}
