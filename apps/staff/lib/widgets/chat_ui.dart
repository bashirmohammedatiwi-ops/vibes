import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/session.dart';
import '../core/theme.dart';
import '../core/net_image.dart';

class ContactAvatar extends StatelessWidget {
  const ContactAvatar({super.key, required this.name, this.phone, this.size = 52, this.unread = 0});

  final String name;
  final String? phone;
  final double size;
  final int unread;

  Color _colorFor(String seed) {
    final palette = [placeInk, placeBrass, placeShiftEvening, placeSuccess, placeShiftMorning];
    final code = (name.isNotEmpty ? name.codeUnitAt(0) : (phone?.codeUnitAt(0) ?? 0)) % palette.length;
    return palette[code];
  }

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '؟';
    if (parts.length == 1) return parts.first.characters.first;
    return '${parts.first.characters.first}${parts.last.characters.first}';
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(name + (phone ?? ''));
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: size / 2,
          backgroundColor: color.withValues(alpha: 0.18),
          child: Text(_initials, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: size * 0.34)),
        ),
        if (unread > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: placeSuccess, borderRadius: BorderRadius.circular(10)),
              child: Text(unread > 99 ? '99+' : '$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ),
      ],
    );
  }
}

class ChatListTile extends StatelessWidget {
  const ChatListTile({
    super.key,
    required this.name,
    required this.phone,
    required this.preview,
    required this.time,
    required this.unread,
    this.subtitle,
    this.urgent = false,
    required this.onTap,
  });

  final String name;
  final String? phone;
  final String preview;
  final String? time;
  final int unread;
  final String? subtitle;
  final bool urgent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bold = unread > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, thickness: 1, color: placeLine.withValues(alpha: 0.9)),
        Material(
      color: urgent ? placeDanger.withValues(alpha: 0.04) : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              ContactAvatar(name: name, phone: phone, unread: unread),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w700, fontSize: 16, color: placeInk),
                          ),
                        ),
                        if (time != null)
                          Text(time!, style: TextStyle(fontSize: 12, color: bold ? placeSuccess : placeInk2, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
                      ],
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: placeBrass, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      preview.isEmpty ? 'ابدأ المحادثة' : preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: placeInk2, fontWeight: bold ? FontWeight.w600 : FontWeight.w400, height: 1.25),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
      ],
    );
  }
}

class ThreadSeparator extends StatelessWidget {
  const ThreadSeparator({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
      child: Row(
        children: [
          Expanded(child: Divider(color: placeInk2.withValues(alpha: 0.35))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: placeInk2)),
          ),
          Expanded(child: Divider(color: placeInk2.withValues(alpha: 0.35))),
        ],
      ),
    );
  }
}

class DateSeparator extends StatelessWidget {
  const DateSeparator({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: placeInk.withValues(alpha: 0.06), blurRadius: 8)]),
          child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: placeInk2)),
        ),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.mine, this.onRetry});

  final Map<String, dynamic> message;
  final bool mine;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final kind = message['kind']?.toString() ?? 'TEXT';
    final body = message['body']?.toString() ?? '';
    final imageUrl = message['imageUrl']?.toString();
    final created = message['createdAt']?.toString();
    final time = created != null ? DateFormat('HH:mm').format(DateTime.parse(created).toLocal()) : '';
    final isSystem = kind == 'SYSTEM';
    final pending = message['pending'] == true;
    final failed = message['failed'] == true;

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
        child: Center(child: Text(body, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: placeInk2.withValues(alpha: 0.85)))),
      );
    }

    final bg = failed
        ? const Color(0xFFFEE2E2)
        : (mine ? const Color(0xFFD9FDD3) : Colors.white);
    final align = mine ? Alignment.centerLeft : Alignment.centerRight;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
      bottomLeft: Radius.circular(mine ? 4 : 14),
      bottomRight: Radius.circular(mine ? 14 : 4),
    );

    return Align(
      alignment: align,
      child: GestureDetector(
        onTap: failed && onRetry != null ? onRetry : null,
        child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.only(bottom: 4, left: 8, right: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          boxShadow: [BoxShadow(color: placeInk.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (kind == 'IMAGE' && imageUrl != null && imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: staffNetworkImage(imageUrl, height: 180, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
              ),
            if (body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Align(alignment: Alignment.centerRight, child: Text(body, style: const TextStyle(fontSize: 15, height: 1.35, color: placeInk))),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pending) const Padding(padding: EdgeInsets.only(left: 4), child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))),
                if (failed) const Icon(Icons.error_outline, size: 14, color: placeDanger),
                Text(time, style: TextStyle(fontSize: 10, color: placeInk2.withValues(alpha: pending ? 0.5 : 0.75))),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.enabled = true,
    this.onQuickReply,
    this.onAttach,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;
  final ValueChanged<String>? onQuickReply;
  final VoidCallback? onAttach;

  static const quickReplies = [
    'مرحباً، كيف يمكنني مساعدتك؟',
    'تم تأكيد حجزك ✅',
    'نحتاج صورة إثبات الدفع',
    'سأتابع معك خلال دقائق',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: placePaper,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onQuickReply != null)
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  children: [
                    for (final q in quickReplies)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ActionChip(
                          label: Text(q, style: const TextStyle(fontSize: 12)),
                          onPressed: enabled ? () => onQuickReply!(q) : null,
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: placeLine),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  if (onAttach != null)
                    IconButton(
                      onPressed: enabled ? onAttach : null,
                      icon: const Icon(Icons.add_circle_outline, color: placeBrass, size: 28),
                    ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: placeLine)),
                      child: TextField(
                        controller: controller,
                        enabled: enabled,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'رسالة',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: enabled ? (_) => onSend() : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Material(
                    color: enabled ? placeSuccess : placeInk2,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: enabled ? onSend : null,
                      customBorder: const CircleBorder(),
                      child: const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.send_rounded, color: Colors.white, size: 22)),
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

bool messageFromMe(Map<String, dynamic> message) {
  final senderId = message['senderId']?.toString() ?? message['sender']?['id']?.toString();
  return senderId == Session.me['id']?.toString();
}

String formatChatListTime(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.parse(iso).toLocal();
  final now = DateTime.now();
  if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
    return DateFormat('HH:mm').format(dt);
  }
  if (now.difference(dt).inDays < 7) {
    return DateFormat('EEEE', 'ar').format(dt);
  }
  return DateFormat('d/M').format(dt);
}

String dateSeparatorLabel(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  if (day == today) return 'اليوم';
  if (day == today.subtract(const Duration(days: 1))) return 'أمس';
  return DateFormat('d MMMM yyyy', 'ar').format(dt);
}
