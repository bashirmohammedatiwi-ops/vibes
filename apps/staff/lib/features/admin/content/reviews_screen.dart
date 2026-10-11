import 'package:flutter/material.dart';

import '../../../core/api.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../widgets/form_kit.dart';
import '../../../widgets/kit.dart';
import '../../../widgets/ui.dart';
import 'content_common.dart';

/// إشراف التقييمات: فلترة (ظاهر/مخفي، أدنى تقييم)، بحث، إخفاء/إظهار مع ملاحظة، حذف، وإجراءات جماعية.
/// كل العمليات تتطلب `reviews.moderate`.
class AdminReviewsScreen extends StatefulWidget {
  const AdminReviewsScreen({super.key});

  @override
  State<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends State<AdminReviewsScreen> {
  static const _pageSize = 25;

  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  String _visible = 'ALL';
  String _minRating = 'ALL';
  String _q = '';
  int _seq = 0;
  final Set<String> _busy = {};
  final Set<String> _selected = {};
  bool _bulkBusy = false;

  bool get _canModerate => Session.can('reviews.moderate');
  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _path(int page) {
    final params = <String>[
      'page=$page',
      'pageSize=$_pageSize',
      if (_visible != 'ALL') 'visible=$_visible',
      if (_minRating != 'ALL') 'minRating=$_minRating',
      if (_q.isNotEmpty) 'q=${Uri.encodeQueryComponent(_q)}',
    ];
    return '/api/admin/reviews?${params.join('&')}';
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
      _selected.removeWhere((id) => !_rows.any((r) => '${r['id']}' == id));
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

  Future<void> _setVisibility(Map<String, dynamic> row, bool visible) async {
    String? note;
    if (!visible) {
      note = await promptText(context, title: 'سبب الإخفاء (اختياري)', hint: 'ملاحظة داخلية تظهر للفريق فقط');
      if (note == null || !mounted) return;
    }
    final id = '${row['id']}';
    final prevVisible = row['isVisible'] == true;
    final prevNote = row['adminNote'];
    setState(() {
      row['isVisible'] = visible;
      if (note != null && note.isNotEmpty) row['adminNote'] = note;
      _busy.add(id);
    });
    try {
      await Api.send(
        '/api/admin/reviews/$id/visibility',
        method: 'PATCH',
        body: {'isVisible': visible, if (note != null && note.isNotEmpty) 'adminNote': note},
      );
      if (mounted) showToast(context, visible ? 'أصبح التقييم ظاهراً' : 'تم إخفاء التقييم');
      if (_visible != 'ALL' && mounted) {
        setState(() => _rows.remove(row));
      }
    } catch (e) {
      row['isVisible'] = prevVisible;
      row['adminNote'] = prevNote;
      if (mounted) showToast(context, '$e', error: true);
    }
    if (mounted) setState(() => _busy.remove(id));
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final ok = await confirmDialog(
      context,
      title: 'حذف التقييم؟',
      message: 'سيُحذف تقييم ${personLabel(row['user'])} نهائياً ويُعاد حساب تقييم المكان.',
      confirmLabel: 'حذف',
      danger: true,
    );
    if (!ok || !mounted) return;
    strongTap();
    final index = _rows.indexOf(row);
    setState(() {
      _rows.remove(row);
      _total = (_total - 1).clamp(0, 1 << 30);
    });
    try {
      await Api.send('/api/admin/reviews/${row['id']}', method: 'DELETE');
      if (mounted) showToast(context, 'تم حذف التقييم');
    } catch (e) {
      if (mounted) {
        setState(() {
          _rows.insert(index.clamp(0, _rows.length), row);
          _total += 1;
        });
        showToast(context, '$e', error: true);
      }
    }
  }

  Future<void> _bulk(String action) async {
    final count = _selected.length;
    final label = switch (action) {
      'show' => 'إظهار',
      'hide' => 'إخفاء',
      _ => 'حذف',
    };
    final ok = await confirmDialog(
      context,
      title: '$label $count تقييم؟',
      message: action == 'delete' ? 'سيُحذف كل التقييمات المحددة نهائياً.' : 'سيُطبّق الإجراء على كل التقييمات المحددة.',
      confirmLabel: label,
      danger: action != 'show',
    );
    if (!ok || !mounted) return;
    setState(() => _bulkBusy = true);
    try {
      final res = await Api.map('/api/admin/reviews/bulk', method: 'POST', body: {'ids': _selected.toList(), 'action': action});
      final updated = asInt(res['updated']);
      final failed = asInt(res['failed']);
      if (mounted) {
        showToast(context, failed > 0 ? 'تم $label $updated — فشل $failed' : 'تم $label $updated تقييم', error: failed > 0 && updated == 0);
        _selected.clear();
        await _load(silent: true);
      }
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
    if (mounted) setState(() => _bulkBusy = false);
  }

  void _toggleSelect(String id) {
    lightTap();
    setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));
  }

  @override
  Widget build(BuildContext context) {
    final hasMore = _page < _totalPages;
    final filtered = _q.isNotEmpty || _visible != 'ALL' || _minRating != 'ALL';
    final state = contentStateSliver(
      loading: _loading,
      error: _error,
      isEmpty: _rows.isEmpty,
      onRetry: _load,
      emptyIcon: Icons.star_outline_rounded,
      emptyTitle: filtered ? 'لا تقييمات في هذا الفلتر' : 'لا توجد تقييمات بعد',
      skeletonHeight: 150,
    );
    final allSelected = _selected.length == _rows.length;
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting) setState(_selected.clear);
      },
      child: ContentEditorScaffold(
        bar: _selecting ? _bulkBar() : null,
        child: ContentAutoLoad(
          hasMore: hasMore && !_loading && _error == null,
          loading: _loadingMore,
          onLoadMore: _loadMore,
          child: StaffPage(
            title: _selecting ? '${_selected.length} محدد' : 'التقييمات',
            subtitle: _selecting ? 'اختر إجراءً من الشريط السفلي' : (_loading ? 'جارٍ التحميل…' : '$_total تقييم'),
            onRefresh: () => _load(silent: true),
            leading: _selecting
                ? IconButton(tooltip: 'إلغاء التحديد', icon: const Icon(Icons.close_rounded), onPressed: () => setState(_selected.clear))
                : null,
            actions: [
              if (_selecting)
                TextButton(
                  onPressed: () => setState(() {
                    if (allSelected) {
                      _selected.clear();
                    } else {
                      _selected.addAll(_rows.map((r) => '${r['id']}'));
                    }
                  }),
                  child: Text(allSelected ? 'إلغاء الكل' : 'تحديد الكل'),
                ),
            ],
            bottom: ContentToolbar(
              height: kContentToolbarHeight,
              children: [
                ContentSearchField(
                  hint: 'بحث في التعليق، الزبون، الهاتف أو المكان',
                  onChanged: (v) {
                    _q = v;
                    _load(silent: _rows.isNotEmpty);
                  },
                ),
                ContentChips<String>(
                  selected: _visible,
                  options: const [
                    ContentChip('ALL', 'كل التقييمات'),
                    ContentChip('true', 'ظاهرة', icon: Icons.visibility_outlined),
                    ContentChip('false', 'مخفية', icon: Icons.visibility_off_outlined),
                  ],
                  onSelected: (v) {
                    setState(() => _visible = v);
                    _load();
                  },
                ),
              ],
            ),
            slivers: [
              if (!_canModerate)
                const SliverToBoxAdapter(child: ReadOnlyNotice(message: 'تحتاج صلاحية «إدارة التقييمات والمنشورات» لعرض هذه الشاشة.')),
              SliverToBoxAdapter(
                child: ContentChips<String>(
                  selected: _minRating,
                  options: [
                    for (final r in const ['ALL', '5', '4', '3', '2'])
                      ContentChip(
                        r,
                        r == 'ALL'
                            ? 'أي تقييم'
                            : r == '5'
                            ? '5 فقط'
                            : '$r فأكثر',
                        icon: r == 'ALL' ? null : Icons.star_rounded,
                      ),
                  ],
                  onSelected: (r) {
                    setState(() => _minRating = r);
                    _load();
                  },
                ),
              ),
              if (!_loading && _error == null && _rows.isNotEmpty && !_selecting && _canModerate)
                const SliverToBoxAdapter(child: ContentHint('اضغط مطولاً على تقييم لتحديد عدة تقييمات', icon: Icons.touch_app_outlined)),
              if (state != null)
                state
              else ...[
                SliverList.builder(
                  itemCount: _rows.length,
                  itemBuilder: (context, i) {
                    final row = _rows[i];
                    final id = '${row['id']}';
                    return Padding(
                      key: ValueKey(id),
                      padding: const EdgeInsets.fromLTRB(StaffSpace.page, 0, StaffSpace.page, 10),
                      child: _ReviewCard(
                        row: row,
                        busy: _busy.contains(id),
                        selecting: _selecting,
                        selected: _selected.contains(id),
                        onSelect: () => _toggleSelect(id),
                        onVisibility: (v) => _setVisibility(row, v),
                        onDelete: () => _delete(row),
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
        ),
      ),
    );
  }

  Widget _bulkBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: placeLine)),
      ),
      child: _bulkBusy
          ? const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator(color: placeGold)),
            )
          : Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _bulk('show'),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('إظهار'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _bulk('hide'),
                    icon: const Icon(Icons.visibility_off_outlined, size: 18),
                    label: const Text('إخفاء'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: placeDanger),
                    onPressed: () => _bulk('delete'),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('حذف'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.row,
    required this.busy,
    required this.selecting,
    required this.selected,
    required this.onSelect,
    required this.onVisibility,
    required this.onDelete,
  });

  final Map<String, dynamic> row;
  final bool busy;
  final bool selecting;
  final bool selected;
  final VoidCallback onSelect;
  final ValueChanged<bool> onVisibility;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final visible = row['isVisible'] == true;
    final rating = asInt(row['rating']);
    final comment = row['comment']?.toString() ?? '';
    final note = row['adminNote']?.toString() ?? '';
    final user = asMap(row['user']);
    final property = asMap(row['property']);
    final phone = user['phone']?.toString() ?? '';
    final name = personLabel(user);
    final ratingColor = rating >= 4 ? placeSuccess : (rating == 3 ? placeShiftMorning : placeDanger);

    return ContentRowCard(
      selected: selected,
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 8, 6),
      onTap: selecting ? onSelect : null,
      onLongPress: onSelect,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (selecting)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Icon(
                    selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: selected ? placeBrass : placeInk3,
                  ),
                ),
              Avatar(name, size: 40),
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
                    Row(
                      children: [
                        if (phone.isNotEmpty && phone != name) ...[
                          Text(
                            phone,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(fontFamily: 'Montserrat', fontSize: 11.5, fontWeight: FontWeight.w600, color: placeInk2),
                          ),
                          const Text(' · ', style: TextStyle(color: placeInk3)),
                        ],
                        Flexible(
                          child: Text(
                            relativeAr(row['createdAt']),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: placeInk3, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: ratingColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(StaffRadius.sm)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, size: 16, color: ratingColor),
                    const SizedBox(width: 3),
                    Text(
                      '$rating',
                      style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, color: ratingColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(
              5,
              (i) => Icon(i < rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 16, color: placeGold),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            comment.isEmpty ? 'بدون تعليق' : comment,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13.5,
              height: 1.55,
              fontWeight: FontWeight.w600,
              color: comment.isEmpty ? placeInk3 : placeInk,
              fontStyle: comment.isEmpty ? FontStyle.italic : null,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(visible ? 'ظاهر' : 'مخفي', color: visible ? placeSuccess : placeInk3, dense: true),
              if (property.isNotEmpty) ContentMeta(icon: Icons.place_outlined, text: property['name']?.toString() ?? ''),
            ],
          ),
          if (note.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: placePaper, borderRadius: BorderRadius.circular(StaffRadius.sm)),
              child: Text(
                'ملاحظة الإدارة: $note',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: placeInk2, fontWeight: FontWeight.w600),
              ),
            ),
          if (!selecting)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (busy)
                  const InlineBusy()
                else
                  TextButton.icon(
                    onPressed: () => onVisibility(!visible),
                    icon: Icon(visible ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                    label: Text(visible ? 'إخفاء' : 'إظهار'),
                  ),
                const SizedBox(width: 4),
                CardAction(icon: Icons.delete_outline_rounded, tooltip: 'حذف', onTap: busy ? null : onDelete, color: placeDanger),
              ],
            )
          else
            const SizedBox(height: 6),
        ],
      ),
    );
  }
}
