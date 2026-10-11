import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/kit.dart';
import 'content_common.dart';
import '../../../core/net_image.dart';

String socialStatusLabel(String? s) => switch (s) {
  'PUBLISHED' => 'منشور',
  'HIDDEN' => 'مخفي',
  'REPORTED' => 'مُبلَّغ عنه',
  _ => s ?? '—',
};

Color socialStatusColor(String? s) => switch (s) {
  'PUBLISHED' => placeSuccess,
  'HIDDEN' => placeInk2,
  'REPORTED' => placeDanger,
  _ => placeInk2,
};

IconData socialStatusIcon(String? s) => switch (s) {
  'PUBLISHED' => Icons.public_rounded,
  'HIDDEN' => Icons.visibility_off_outlined,
  'REPORTED' => Icons.flag_outlined,
  _ => Icons.help_outline_rounded,
};

bool _isVideo(String url) {
  final u = url.toLowerCase().split('?').first;
  return u.endsWith('.mp4') || u.endsWith('.mov') || u.endsWith('.m3u8') || u.endsWith('.webm');
}

List<String> _mediaOf(Map<String, dynamic> post) {
  final raw = post['mediaUrls'];
  if (raw is! List) return const [];
  return raw.map((e) => e is Map ? '${e['url'] ?? ''}' : '$e').where((e) => e.isNotEmpty).toList();
}

/// إشراف منشورات التجارب (Social): فلترة بالحالة، بحث، نشر/إخفاء.
/// تتطلب `reviews.moderate`.
class AdminSocialScreen extends StatefulWidget {
  const AdminSocialScreen({super.key});

  @override
  State<AdminSocialScreen> createState() => _AdminSocialScreenState();
}

class _AdminSocialScreenState extends State<AdminSocialScreen> {
  static const _pageSize = 20;

  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  String _status = 'ALL';
  String _q = '';
  int _seq = 0;
  final Set<String> _busy = {};

  bool get _canModerate => Session.can('reviews.moderate');

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _path(int page) {
    final params = <String>[
      'page=$page',
      'pageSize=$_pageSize',
      if (_status != 'ALL') 'status=$_status',
      if (_q.isNotEmpty) 'q=${Uri.encodeQueryComponent(_q)}',
    ];
    return '/api/admin/social?${params.join('&')}';
  }

  Future<void> _load({bool silent = false}) async {
    final seq = ++_seq;
    if (!silent) setState(() => _loading = true);
    try {
      final data = await Api.map(_path(1));
      if (seq != _seq) return;
      _rows = asMapList(data['items']);
      _page = 1;
      _totalPages = asInt(data['totalPages'], 1);
      _total = asInt(data['total']);
      _error = null;
    } catch (e) {
      if (seq != _seq) return;
      if (silent && _rows.isNotEmpty) {
        if (mounted) showToast(context, '$e', error: true);
      } else {
        _rows = [];
        _error = '$e';
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _totalPages) return;
    setState(() => _loadingMore = true);
    final seq = _seq;
    try {
      final data = await Api.map(_path(_page + 1));
      if (seq == _seq) {
        _rows.addAll(asMapList(data['items']));
        _page += 1;
        _totalPages = asInt(data['totalPages'], _totalPages);
      }
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _moderate(Map<String, dynamic> row, String status) async {
    if (status == 'HIDDEN') {
      final ok = await confirmDialog(
        context,
        title: 'إخفاء المنشور؟',
        message: 'لن يظهر المنشور للزبائن حتى يُعاد نشره.',
        confirmLabel: 'إخفاء',
        danger: true,
      );
      if (!ok || !mounted) return;
    }
    final id = '${row['id']}';
    final prev = row['status'];
    setState(() {
      row['status'] = status;
      _busy.add(id);
    });
    try {
      await Api.send('/api/admin/social/$id', method: 'PATCH', body: {'status': status});
      if (mounted) {
        showToast(
          context,
          status == 'PUBLISHED'
              ? 'تم نشر المنشور'
              : status == 'HIDDEN'
              ? 'تم إخفاء المنشور'
              : 'تم وضعه كمُبلَّغ عنه',
        );
        if (_status != 'ALL' && _status != status) setState(() => _rows.remove(row));
      }
    } catch (e) {
      row['status'] = prev;
      if (mounted) showToast(context, '$e', error: true);
    }
    if (mounted) setState(() => _busy.remove(id));
  }

  Future<void> _open(Map<String, dynamic> row) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SocialPostDetailScreen(
          postId: '${row['id']}',
          onStatusChanged: (s) {
            if (mounted) setState(() => row['status'] = s);
          },
        ),
      ),
    );
    if (mounted && _status != 'ALL' && row['status'] != _status) {
      setState(() => _rows.remove(row));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMore = _page < _totalPages;
    final state = contentStateSliver(
      loading: _loading,
      error: _error,
      isEmpty: _rows.isEmpty,
      onRetry: _load,
      emptyIcon: _status == 'REPORTED' ? Icons.verified_outlined : Icons.photo_library_outlined,
      emptyTitle: _status == 'REPORTED' ? 'لا بلاغات — كل شيء نظيف' : 'لا منشورات في هذا الفلتر',
      skeletonHeight: 150,
    );
    return ContentAutoLoad(
      hasMore: hasMore && !_loading && _error == null,
      loading: _loadingMore,
      onLoadMore: _loadMore,
      child: StaffPage(
        title: 'منشورات التجارب',
        subtitle: _loading ? 'جارٍ التحميل…' : '$_total منشور',
        onRefresh: () => _load(silent: true),
        bottom: ContentToolbar(
          height: kContentToolbarHeight,
          children: [
            ContentSearchField(
              hint: 'بحث في الوصف، الزبون أو المكان',
              onChanged: (v) {
                _q = v;
                _load(silent: _rows.isNotEmpty);
              },
            ),
            ContentChips<String>(
              selected: _status,
              options: [
                for (final s in const ['ALL', 'REPORTED', 'PUBLISHED', 'HIDDEN'])
                  ContentChip(s, s == 'ALL' ? 'الكل' : socialStatusLabel(s), icon: s == 'ALL' ? null : socialStatusIcon(s)),
              ],
              onSelected: (v) {
                setState(() => _status = v);
                _load();
              },
            ),
          ],
        ),
        slivers: [
          if (!_canModerate)
            const SliverToBoxAdapter(child: ReadOnlyNotice(message: 'تحتاج صلاحية «إدارة التقييمات والمنشورات» لإدارة المنشورات.')),
          if (state != null)
            state
          else ...[
            SliverList.builder(
              itemCount: _rows.length,
              itemBuilder: (context, i) {
                final row = _rows[i];
                return Padding(
                  key: ValueKey(row['id']),
                  padding: const EdgeInsets.fromLTRB(StaffSpace.page, 0, StaffSpace.page, 10),
                  child: _PostCard(
                    row: row,
                    canModerate: _canModerate,
                    busy: _busy.contains('${row['id']}'),
                    onOpen: () => _open(row),
                    onModerate: (s) => _moderate(row, s),
                  ),
                );
              },
            ),
            SliverToBoxAdapter(
              child: LoadMoreFooter(hasMore: hasMore, loading: _loadingMore, onLoadMore: _loadMore, total: _total),
            ),
          ],
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.row, required this.canModerate, required this.busy, required this.onOpen, required this.onModerate});

  final Map<String, dynamic> row;
  final bool canModerate;
  final bool busy;
  final VoidCallback onOpen;
  final ValueChanged<String> onModerate;

  @override
  Widget build(BuildContext context) {
    final status = row['status']?.toString();
    final media = _mediaOf(row);
    final caption = row['caption']?.toString() ?? '';
    final counts = asMap(row['_count']);
    final reports = asInt(counts['reports']);
    final likes = asInt(row['likesCount'], asInt(counts['likes']));
    final comments = asInt(row['commentsCount'], asInt(counts['comments']));
    final property = asMap(row['property']);
    final cover = media.isEmpty ? null : media.first;

    return ContentRowCard(
      onTap: onOpen,
      borderColor: status == 'REPORTED' ? placeDanger.withValues(alpha: 0.4) : placeLine,
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (cover != null && _isVideo(cover))
                      Container(
                        decoration: BoxDecoration(color: placeInk, borderRadius: BorderRadius.circular(StaffRadius.md)),
                        child: const Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 34),
                      )
                    else
                      NetImage(url: resolveMediaUrl(cover), radius: StaffRadius.md, icon: Icons.photo_outlined),
                    if (media.length > 1)
                      PositionedDirectional(
                        top: 5,
                        end: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            '+${media.length - 1}',
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            property['name']?.toString() ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 14.5, color: placeInk),
                          ),
                        ),
                        const SizedBox(width: 6),
                        StatusChip(socialStatusLabel(status), color: socialStatusColor(status), dense: true),
                      ],
                    ),
                    Text(
                      '${personLabel(row['user'])} · ${relativeAr(row['createdAt'])}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      caption.isEmpty ? 'بدون وصف' : caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, height: 1.45, color: caption.isEmpty ? placeInk3 : placeInk),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _Count(icon: Icons.favorite_border_rounded, value: likes),
              _Count(icon: Icons.mode_comment_outlined, value: comments),
              if (reports > 0) _Count(icon: Icons.flag_outlined, value: reports, color: placeDanger),
              const Spacer(),
              if (canModerate)
                busy
                    ? const InlineBusy()
                    : status == 'PUBLISHED'
                    ? TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: placeDanger),
                        onPressed: () => onModerate('HIDDEN'),
                        icon: const Icon(Icons.visibility_off_outlined, size: 18),
                        label: const Text('إخفاء'),
                      )
                    : TextButton.icon(
                        onPressed: () => onModerate('PUBLISHED'),
                        icon: const Icon(Icons.public_rounded, size: 18),
                        label: const Text('نشر'),
                      ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.icon, required this.value, this.color = placeInk2});

  final IconData icon;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color == placeInk2 ? placeInk3 : color),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: TextStyle(fontFamily: 'Montserrat', fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

/// تفاصيل منشور: الوسائط، الوصف، التعليقات والبلاغات، وأزرار الإشراف.
class SocialPostDetailScreen extends StatefulWidget {
  const SocialPostDetailScreen({super.key, required this.postId, this.onStatusChanged});

  final String postId;
  final ValueChanged<String>? onStatusChanged;

  @override
  State<SocialPostDetailScreen> createState() => _SocialPostDetailScreenState();
}

class _SocialPostDetailScreenState extends State<SocialPostDetailScreen> {
  Map<String, dynamic>? _post;
  bool _loading = true;
  String? _error;
  bool _busy = false;
  int _mediaIndex = 0;

  bool get _canModerate => Session.can('reviews.moderate');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.map('/api/admin/social/${widget.postId}');
      _post = data;
      _error = null;
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _moderate(String status) async {
    final post = _post;
    if (post == null) return;
    if (status == 'HIDDEN') {
      final ok = await confirmDialog(
        context,
        title: 'إخفاء المنشور؟',
        message: 'لن يظهر المنشور للزبائن حتى يُعاد نشره.',
        confirmLabel: 'إخفاء',
        danger: true,
      );
      if (!ok || !mounted) return;
    }
    final prev = post['status'];
    setState(() {
      post['status'] = status;
      _busy = true;
    });
    try {
      await Api.send('/api/admin/social/${widget.postId}', method: 'PATCH', body: {'status': status});
      widget.onStatusChanged?.call(status);
      if (mounted) {
        showToast(
          context,
          status == 'PUBLISHED'
              ? 'تم نشر المنشور'
              : status == 'HIDDEN'
              ? 'تم إخفاء المنشور'
              : 'تم وضعه كمُبلَّغ عنه',
        );
      }
    } catch (e) {
      post['status'] = prev;
      if (mounted) showToast(context, '$e', error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _openMedia(String url) async {
    final resolved = resolveMediaUrl(url);
    if (resolved == null) return;
    if (_isVideo(resolved)) {
      final ok = await launchUrl(Uri.parse(resolved), mode: LaunchMode.externalApplication);
      if (!ok && mounted) showToast(context, 'تعذّر فتح الفيديو', error: true);
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
          body: Center(
            child: InteractiveViewer(maxScale: 5, child: staffNetworkImage(resolved, fit: BoxFit.contain)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final status = post?['status']?.toString();
    final counts = asMap(post?['_count']);
    return ContentEditorScaffold(
      bar: post != null && _canModerate ? _actions(status) : null,
      child: StaffPage(
        title: asMap(post?['property'])['name']?.toString() ?? 'المنشور',
        subtitle: post == null ? null : '${socialStatusLabel(status)} · ${relativeAr(post['createdAt'])}',
        onRefresh: post == null ? null : _load,
        slivers: _loading
            ? [
                const SliverToBoxAdapter(
                  child: Pad(top: 8, child: AspectRatio(aspectRatio: 1, child: SkeletonBox())),
                ),
                const SkeletonSliver(count: 3, height: 96),
              ]
            : _error != null || post == null
            ? [
                SliverToBoxAdapter(
                  child: ContentErrorView(
                    error: _error,
                    onRetry: () {
                      setState(() => _loading = true);
                      _load();
                    },
                  ),
                ),
              ]
            : [
                SliverToBoxAdapter(child: _mediaGallery(_mediaOf(post))),
                SliverToBoxAdapter(child: _header(post)),
                SliverToBoxAdapter(
                  child: _listSection(
                    title: 'البلاغات',
                    icon: Icons.flag_outlined,
                    emptyText: 'لا بلاغات على هذا المنشور',
                    total: asInt(counts['reports']),
                    danger: true,
                    rows: [
                      for (final r in asMapList(post['reports']))
                        _line(
                          personLabel(r['user']),
                          (r['reason']?.toString() ?? '').isEmpty ? 'بدون سبب' : r['reason'].toString(),
                          r['createdAt'],
                          danger: true,
                        ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: _listSection(
                    title: 'التعليقات',
                    icon: Icons.mode_comment_outlined,
                    emptyText: 'لا تعليقات',
                    total: asInt(counts['comments']),
                    rows: [
                      for (final c in asMapList(post['comments']))
                        _line(personLabel(c['user']), c['body']?.toString() ?? '', c['createdAt']),
                    ],
                  ),
                ),
              ],
      ),
    );
  }

  Widget _mediaGallery(List<String> media) {
    if (media.isEmpty) {
      return const Pad(
        top: 8,
        child: StaffCard(
          child: SizedBox(
            height: 96,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.hide_image_outlined, color: placeInk3),
                  SizedBox(height: 4),
                  Text(
                    'منشور بدون وسائط',
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: placeInk2),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Pad(
      top: 8,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: PageView.builder(
              itemCount: media.length,
              onPageChanged: (i) => setState(() => _mediaIndex = i),
              itemBuilder: (context, i) {
                final url = media[i];
                return GestureDetector(
                  onTap: () => _openMedia(url),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _isVideo(url)
                        ? Container(
                            decoration: BoxDecoration(color: placeInk, borderRadius: BorderRadius.circular(StaffRadius.lg)),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 56),
                                SizedBox(height: 6),
                                Text(
                                  'فيديو — اضغط للتشغيل',
                                  style: TextStyle(fontFamily: 'Cairo', color: Colors.white70),
                                ),
                              ],
                            ),
                          )
                        : NetImage(url: resolveMediaUrl(url), radius: StaffRadius.lg),
                  ),
                );
              },
            ),
          ),
          if (media.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < media.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _mediaIndex ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(color: i == _mediaIndex ? placeGold : placeLine, borderRadius: BorderRadius.circular(6)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _header(Map<String, dynamic> post) {
    final status = post['status']?.toString();
    final caption = post['caption']?.toString() ?? '';
    final user = asMap(post['user']);
    final name = personLabel(user);
    final phone = user['phone']?.toString() ?? '';
    final counts = asMap(post['_count']);
    final reports = asInt(counts['reports']);
    return Pad(
      child: StaffCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Avatar(name, size: 42),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 14.5, color: placeInk),
                      ),
                      if (phone.isNotEmpty && phone != name)
                        Text(
                          phone,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(fontFamily: 'Montserrat', fontSize: 11.5, fontWeight: FontWeight.w600, color: placeInk2),
                        ),
                    ],
                  ),
                ),
                StatusChip(socialStatusLabel(status), color: socialStatusColor(status)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              caption.isEmpty ? 'بدون وصف' : caption,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                height: 1.6,
                fontWeight: FontWeight.w600,
                color: caption.isEmpty ? placeInk3 : placeInk,
              ),
            ),
            const Divider(height: 22),
            Row(
              children: [
                _Count(icon: Icons.favorite_border_rounded, value: asInt(post['likesCount'], asInt(counts['likes']))),
                _Count(icon: Icons.mode_comment_outlined, value: asInt(post['commentsCount'], asInt(counts['comments']))),
                _Count(icon: Icons.flag_outlined, value: reports, color: reports > 0 ? placeDanger : placeInk2),
                const Spacer(),
                Text(
                  formatStamp(post['createdAt']),
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: placeInk3, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _listSection({
    required String title,
    required IconData icon,
    required String emptyText,
    required int total,
    required List<Widget> rows,
    bool danger = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title, subtitle: total > rows.length ? 'آخر ${rows.length} من $total' : null, count: danger ? total : null),
        Pad(
          bottom: 0,
          child: rows.isEmpty
              ? StaffCard(
                  child: Row(
                    children: [
                      IconBox(icon: icon, color: danger ? placeSuccess : placeInk3, size: 34),
                      const SizedBox(width: 10),
                      Text(
                        emptyText,
                        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: placeInk2),
                      ),
                    ],
                  ),
                )
              : TileGroup(children: rows),
        ),
      ],
    );
  }

  Widget _line(String who, String text, dynamic at, {bool danger = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(who, size: 40, color: danger ? placeDanger : placeNavyHigh),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        who,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 13.5, color: placeInk),
                      ),
                    ),
                    Text(
                      relativeAr(at),
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: placeInk3, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: danger ? placeDanger : placeInk2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(String? status) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: placeLine)),
      ),
      child: _busy
          ? const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator(color: placeGold)),
            )
          : Row(
              children: [
                if (status != 'REPORTED') ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _moderate('REPORTED'),
                      icon: const Icon(Icons.flag_outlined, size: 18),
                      label: const Text('للمراجعة'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (status != 'HIDDEN') ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: placeDanger),
                      onPressed: () => _moderate('HIDDEN'),
                      icon: const Icon(Icons.visibility_off_outlined, size: 18),
                      label: const Text('إخفاء'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (status != 'PUBLISHED')
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _moderate('PUBLISHED'),
                      icon: const Icon(Icons.public_rounded, size: 18),
                      label: const Text('نشر'),
                    ),
                  ),
              ],
            ),
    );
  }
}
