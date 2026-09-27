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
import '../../shared/widgets/vibes_widgets.dart';
import 'call_screen.dart';
import '../../core/utils/vibes_net_image.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId, this.incomingCallId});

  final String conversationId;
  final String? incomingCallId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
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
      _poll = Timer.periodic(const Duration(seconds: 12), (_) {
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(maisonError(e))));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(maisonError(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
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

    return Scaffold(
      body: MaisonWash(
        child: Column(
          children: [
            MaisonPageHeader(
              title: ref.watch(
                conversationTitleProvider(widget.conversationId),
              ),
              kicker: thread?.stage ?? 'محادثة خاصة',
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
            if (thread != null && thread.kind != 'SUPPORT' && thread.title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: FolioPanel(
                  railColor: Vibes.teal,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (thread.cityName != null && thread.cityName!.isNotEmpty)
                                Text(
                                  thread.cityName!,
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                          onPressed: () => joinCall(
                            ref,
                            context,
                            widget.incomingCallId!,
                          ),
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
                      subtitle: 'اكتب سؤالك للمالك أو لفريق VIBEES',
                    );
                  }
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final m = list[list.length - 1 - i];
                      if (m.isSystem || m.kind == 'CALL') {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            m.body,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: VibesTheme.textTertiaryOf(context),
                                ),
                          ),
                        );
                      }
                      final mine = m.senderId != null && m.senderId == myId;
                      return Align(
                        alignment: mine
                            ? AlignmentDirectional.centerStart
                            : AlignmentDirectional.centerEnd,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                          ),
                          decoration: ShapeDecoration(
                            color: mine
                                ? VibesTheme.actionOf(context)
                                : VibesTheme.surfaceOf(context),
                            shape: RoundedRectangleBorder(
                              borderRadius: Folio.radius,
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
                              if (m.imageUrl != null && m.imageUrl!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: ClipPath(
                                    clipper: const ShapeBorderClipper(
                                      shape: Folio.shape,
                                    ),
                                    child: VibesNetImage(
                                      url: m.imageUrl!,
                                      width: 220,
                                      height: 160,
                                    ),
                                  ),
                                ),
                              if (m.body.isNotEmpty)
                                Text(
                                  m.body,
                                  style: TextStyle(
                                    color: mine
                                        ? VibesTheme.onActionOf(context)
                                        : VibesTheme.textPrimaryOf(context),
                                    height: 1.45,
                                  ),
                                ),
                            ],
                          ),
                        ),
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
                  const SizedBox(
                    height: 3,
                    width: double.infinity,
                    child: ColoredBox(color: Vibes.teal),
                  ),
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
                            child: FolioPanel(
                              color: VibesTheme.canvasOf(context),
                              borderColor: VibesTheme.hairlineOf(context),
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
                          FolioPanel(
                            color: VibesTheme.actionOf(context),
                            borderColor: Colors.transparent,
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
