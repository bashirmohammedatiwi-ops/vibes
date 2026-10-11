import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/net_image.dart';
import '../core/session.dart';
import '../core/theme.dart';
import 'kit.dart';

/// ═══════════════════════════════════════════════════════════
/// مكوّنات المحادثة: صورة الزبون، صف المحادثة في القائمة، فواصل التاريخ
/// والخيوط، فقاعة الرسالة، وصندوق الكتابة.
/// ═══════════════════════════════════════════════════════════

const _avatarPalette = [placeNavyHigh, placeBrass, placeShiftEvening, placeSuccess, placeShiftMorning, placeInfo];

/// صورة رمزية للزبون بالأحرف الأولى ولون ثابت لكل اسم/رقم.
class ContactAvatar extends StatelessWidget {
  const ContactAvatar({super.key, required this.name, this.phone, this.size = 52, this.unread = 0});

  final String name;
  final String? phone;
  final double size;
  final int unread;

  Color get _color {
    final seed = '${name.trim()}${phone ?? ''}';
    if (seed.isEmpty) return placeNavyHigh;
    var h = 0;
    for (final c in seed.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _avatarPalette[h % _avatarPalette.length];
  }

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '؟';
    if (parts.length == 1) return parts.first.characters.first;
    return '${parts.first.characters.first}${parts.last.characters.first}';
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: .12),
              border: Border.all(color: color.withValues(alpha: .18)),
            ),
            child: Text(
              _initials,
              style: TextStyle(fontFamily: 'Cairo', color: color, fontWeight: FontWeight.w900, fontSize: size * .34, height: 1.2),
            ),
          ),
          if (unread > 0)
            PositionedDirectional(
              end: -4,
              top: -4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: CountBadge(unread, color: placeSuccess),
              ),
            ),
        ],
      ),
    );
  }
}

/// صف محادثة في قائمة الوارد (بطاقة واحدة لكل زبون).
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
    this.previewIcon,
    this.threads = 0,
    this.closed = false,
  });

  final String name;
  final String? phone;
  final String preview;
  final String? time;
  final int unread;

  /// اسم المكان/العقار المرتبط بآخر محادثة.
  final String? subtitle;
  final bool urgent;
  final VoidCallback onTap;

  /// أيقونة قبل المعاينة (مثلاً صورة).
  final IconData? previewIcon;

  /// عدد المحادثات المجمّعة لهذا الزبون.
  final int threads;
  final bool closed;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unread > 0;
    final r = BorderRadius.circular(StaffRadius.lg);
    final border = urgent
        ? placeDanger.withValues(alpha: .35)
        : (hasUnread ? placeGold.withValues(alpha: .45) : placeLine);
    final chips = <Widget>[
      if (urgent) const StatusChip('عاجلة', color: placeDanger, dense: true),
      if (subtitle != null && subtitle!.isNotEmpty) _PlaceTag(subtitle!),
      if (threads > 1) _MetaTag(icon: Icons.layers_outlined, label: '$threads محادثات'),
      if (closed) const StatusChip('مغلقة', color: placeInk3, dense: true),
    ];

    return Material(
      color: urgent ? const Color(0xFFFFFBFB) : Colors.white,
      borderRadius: r,
      child: InkWell(
        borderRadius: r,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Ink(
          decoration: BoxDecoration(borderRadius: r, border: Border.all(color: border)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ContactAvatar(name: name, phone: phone, size: 50),
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
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: hasUnread ? FontWeight.w900 : FontWeight.w800,
                                fontSize: 15.5,
                                color: placeInk,
                                height: 1.3,
                              ),
                            ),
                          ),
                          if (time != null && time!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              time!,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: hasUnread ? placeSuccess : placeInk3,
                                fontWeight: hasUnread ? FontWeight.w900 : FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (previewIcon != null) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Icon(previewIcon, size: 16, color: placeInk3),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              preview.isEmpty ? 'ابدأ المحادثة' : preview,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13.5,
                                color: hasUnread ? placeInk : placeInk2,
                                fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                                fontStyle: preview.isEmpty ? FontStyle.italic : FontStyle.normal,
                                height: 1.4,
                              ),
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: CountBadge(unread, color: placeSuccess),
                            ),
                          ],
                        ],
                      ),
                      if (chips.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 6, children: chips),
                      ],
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
}

class _PlaceTag extends StatelessWidget {
  const _PlaceTag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: placeGoldSoft, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.home_work_outlined, size: 13, color: placeBrass),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w800, color: placeBrass),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  const _MetaTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: placeLineSoft, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: placeInk2),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w800, color: placeInk2)),
        ],
      ),
    );
  }
}

/// فاصل عند الانتقال بين محادثات الزبون (مكان مختلف / دعم).
class ThreadSeparator extends StatelessWidget {
  const ThreadSeparator({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: StaffSpace.page),
      child: Row(
        children: [
          const Expanded(child: Divider(color: placeLine)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: placeGoldSoft,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: placeGold.withValues(alpha: .35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.forum_outlined, size: 13, color: placeBrass),
                const SizedBox(width: 5),
                Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.w800, color: placeBrass)),
              ],
            ),
          ),
          const Expanded(child: Divider(color: placeLine)),
        ],
      ),
    );
  }
}

/// شارة اليوم بين الرسائل.
class DateSeparator extends StatelessWidget {
  const DateSeparator({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: placeLine),
          ),
          child: Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w800, color: placeInk2)),
        ),
      ),
    );
  }
}

/// فقاعة رسالة. رسائل الموظفين على طرف، والزبون على الطرف المقابل.
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
    final createdAt = created != null ? DateTime.tryParse(created)?.toLocal() : null;
    final time = createdAt != null ? DateFormat('HH:mm').format(createdAt) : '';
    final pending = message['pending'] == true;
    final failed = message['failed'] == true;

    if (kind == 'SYSTEM') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 32),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: placeLineSoft, borderRadius: BorderRadius.circular(StaffRadius.sm)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: placeInk3),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600, color: placeInk2, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // رسالة من موظف آخر تظهر بجانب رسائلي مع اسم المرسل.
    final sender = message['sender'];
    final senderRole = sender is Map ? sender['role']?.toString() : null;
    final otherStaff = !mine && (senderRole == 'STAFF' || senderRole == 'ADMIN');
    final staffSide = mine || otherStaff;
    final senderName = otherStaff && sender is Map ? (sender['name']?.toString() ?? 'موظف') : null;

    final Color bg;
    final Color fg;
    if (failed) {
      bg = const Color(0xFFFEECEC);
      fg = placeInk;
    } else if (mine) {
      bg = placeNavy;
      fg = Colors.white;
    } else if (otherStaff) {
      bg = const Color(0xFFE8EDF5);
      fg = placeInk;
    } else {
      bg = Colors.white;
      fg = placeInk;
    }
    final metaColor = mine && !failed ? Colors.white.withValues(alpha: .65) : placeInk3;

    const big = Radius.circular(18);
    const tail = Radius.circular(6);
    final radius = BorderRadiusDirectional.only(
      topStart: big,
      topEnd: big,
      bottomStart: staffSide ? big : tail,
      bottomEnd: staffSide ? tail : big,
    );
    final hasImage = kind == 'IMAGE' && imageUrl != null && imageUrl.isNotEmpty;
    final Border? border = failed
        ? Border.all(color: placeDanger.withValues(alpha: .4))
        : (!staffSide ? Border.all(color: placeLine) : null);

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
      padding: hasImage ? const EdgeInsets.all(4) : const EdgeInsets.fromLTRB(12, 8, 12, 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: border,
        boxShadow: const [BoxShadow(color: Color(0x080F1B2D), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (senderName != null)
            Padding(
              padding: EdgeInsets.fromLTRB(hasImage ? 8 : 0, hasImage ? 4 : 0, hasImage ? 8 : 0, 2),
              child: Text(senderName, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.w900, color: placeBrass)),
            ),
          if (hasImage)
            GestureDetector(
              onTap: () => _openImage(context, imageUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: staffNetworkImage(
                  imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 120,
                    color: placeLineSoft,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined, color: placeInk3, size: 32),
                  ),
                ),
              ),
            ),
          if (body.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(hasImage ? 8 : 0, hasImage ? 6 : 0, hasImage ? 8 : 0, 2),
              child: Text(body, style: TextStyle(fontFamily: 'Cairo', fontSize: 15, height: 1.5, color: fg, fontWeight: FontWeight.w500)),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(hasImage ? 8 : 0, 0, hasImage ? 8 : 0, hasImage ? 4 : 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(time, style: TextStyle(fontFamily: 'Montserrat', fontSize: 10.5, fontWeight: FontWeight.w600, color: metaColor)),
                if (mine) ...[
                  const SizedBox(width: 4),
                  if (pending)
                    Icon(Icons.schedule_rounded, size: 13, color: metaColor)
                  else if (failed)
                    const Icon(Icons.error_rounded, size: 14, color: placeDanger)
                  else
                    Icon(Icons.done_rounded, size: 14, color: metaColor),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 12, right: 12),
      child: Column(
        crossAxisAlignment: staffSide ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(onTap: failed && onRetry != null ? onRetry : null, child: bubble),
          if (failed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: InkWell(
                onTap: onRetry,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, size: 15, color: placeDanger),
                      SizedBox(width: 4),
                      Text('لم تُرسل — اضغط لإعادة المحاولة', style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.w800, color: placeDanger)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openImage(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            systemOverlayStyle: SystemUiOverlayStyle.light,
          ),
          body: Center(
            child: InteractiveViewer(
              maxScale: 5,
              child: staffNetworkImage(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// صندوق الكتابة: ردود سريعة، إرفاق صورة، حقل متعدد الأسطر، وزر إرسال.
class ChatComposer extends StatefulWidget {
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
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  bool _showQuick = false;

  OutlineInputBorder _pill([BorderSide side = BorderSide.none]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: side);

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: placeLine)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: widget.onQuickReply != null && _showQuick
                  ? SizedBox(
                      height: 54,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
                        itemCount: ChatComposer.quickReplies.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final q = ChatComposer.quickReplies[i];
                          return ActionChip(
                            avatar: const Icon(Icons.bolt_rounded, size: 16, color: placeBrass),
                            label: Text(q, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.w700)),
                            onPressed: enabled
                                ? () {
                                    HapticFeedback.selectionClick();
                                    widget.onQuickReply!(q);
                                  }
                                : null,
                            backgroundColor: placeGoldSoft,
                            side: BorderSide(color: placeGold.withValues(alpha: .35)),
                          );
                        },
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.onAttach != null)
                    _ComposerIcon(
                      icon: Icons.image_outlined,
                      tooltip: 'إرسال صورة',
                      onTap: enabled ? widget.onAttach : null,
                    ),
                  if (widget.onQuickReply != null)
                    _ComposerIcon(
                      icon: _showQuick ? Icons.bolt_rounded : Icons.bolt_outlined,
                      tooltip: 'ردود سريعة',
                      active: _showQuick,
                      onTap: enabled ? () => setState(() => _showQuick = !_showQuick) : null,
                    ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      enabled: enabled,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, color: placeInk, height: 1.4),
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالة…',
                        filled: true,
                        fillColor: placePaper,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        border: _pill(),
                        enabledBorder: _pill(),
                        disabledBorder: _pill(),
                        focusedBorder: _pill(BorderSide(color: placeGold.withValues(alpha: .6))),
                      ),
                      onSubmitted: enabled ? (_) => widget.onSend() : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.controller,
                    builder: (context, value, _) {
                      final ready = enabled && value.text.trim().isNotEmpty;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: ready ? placeNavyFill : null,
                          color: ready ? null : placeLine,
                        ),
                        child: Material(
                          type: MaterialType.transparency,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: enabled ? widget.onSend : null,
                            child: Tooltip(
                              message: 'إرسال',
                              child: Icon(Icons.send_rounded, color: ready ? Colors.white : placeInk3, size: 22),
                            ),
                          ),
                        ),
                      );
                    },
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

class _ComposerIcon extends StatelessWidget {
  const _ComposerIcon({required this.icon, required this.tooltip, this.onTap, this.active = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 48),
      style: IconButton.styleFrom(backgroundColor: active ? placeGoldSoft : null),
      icon: Icon(icon, color: active ? placeBrass : placeInk2, size: 25),
    );
  }
}

bool messageFromMe(Map<String, dynamic> message) {
  final senderId = message['senderId']?.toString() ?? message['sender']?['id']?.toString();
  return senderId == Session.me['id']?.toString();
}

String formatChatListTime(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return '';
  final dt = parsed.toLocal();
  final now = DateTime.now();
  if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
    return DateFormat('HH:mm').format(dt);
  }
  final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
  if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
    return 'أمس';
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
