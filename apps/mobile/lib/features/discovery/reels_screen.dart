import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/world_theme.dart';
import '../../core/utils/vibes_net_image.dart';
import '../../shared/data/property_providers.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/maison_chrome.dart';
import '../../shared/widgets/vibes_graphics.dart';
import '../../shared/widgets/vibes_widgets.dart';
import '../../shared/widgets/world_ui.dart';
import '../auth/auth_controller.dart';
import '../home/home_sections.dart';
import '../social/experiences_screen.dart';

/// ═══════════════════════════════════════════════════════════
/// الاستكشاف — ريلز عمودية ملء الشاشة بمحرّك تشغيل مركزي:
///   • مجمّع مشغّلات بنافذة ثلاث صفحات (السابقة/الحالية/التالية) —
///     ذاكرة ثابتة مهما طالت القائمة، والتالية تُحمَّل بعد جاهزية
///     الحالية فلا تتنافسان على الشبكة.
///   • لا يعمل إلا فيديو واحد: التبديل يوقف السابق فوراً، والتمرير
///     السريع لا يبدأ تحميل الصفحات العابرة (تأجيل قصير حتى الاستقرار).
///   • جودة فورية: MP4 ثابت 720p بدل HLS الذي يبدأ 240p، وغلاف حاد.
///   • الصوت مفعّل افتراضياً، والتفضيل محفوظ بين الجلسات.
///   • يتوقف تلقائياً عند مغادرة الشاشة (تبويب آخر، صفحة مكان،
///     خلفية التطبيق) ويستأنف عند العودة.
/// ═══════════════════════════════════════════════════════════

enum _ExploreTab { tours, experiences }

/// حالة الصوت العالمية — مفعّل افتراضياً ومحفوظ بين الجلسات.
class ReelsAudio {
  ReelsAudio._();

  static final muted = ValueNotifier<bool>(false);
  static bool _loaded = false;
  static const _key = 'reels_muted';

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      muted.value = prefs.getBool(_key) ?? false;
    } catch (_) {}
  }

  static Future<void> toggle() async {
    muted.value = !muted.value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, muted.value);
    } catch (_) {}
  }
}

// ═══════════════════════════════════════════════════════════
// محرّك التشغيل
// ═══════════════════════════════════════════════════════════

/// مشغّل ريل واحد — يجرّب مصادر التشغيل بالترتيب حتى ينجح أحدها.
class _ReelSlot {
  _ReelSlot(this.media);

  final MediaItem media;
  final controller = ValueNotifier<VideoPlayerController?>(null);
  final failed = ValueNotifier<bool>(false);
  final _ready = Completer<void>();

  bool _disposed = false;
  bool _starting = false;
  bool _wantPlay = false;

  /// أوقفه المستخدم بنقرة — لا يُستأنف تلقائياً حتى يغادر الصفحة.
  bool userPaused = false;

  Future<void> get ready => _ready.future;
  bool get isReady => controller.value?.value.isInitialized ?? false;

  Future<void> start() async {
    if (_starting || controller.value != null || _disposed || failed.value)
      return;
    _starting = true;
    for (final url in media.playbackSources) {
      final c = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      try {
        await c.initialize().timeout(const Duration(seconds: 15));
        if (_disposed) {
          await c.dispose();
          return;
        }
        await c.setLooping(true);
        await c.setVolume(ReelsAudio.muted.value ? 0 : 1);
        controller.value = c;
        _starting = false;
        if (_wantPlay && !userPaused) await c.play();
        if (!_ready.isCompleted) _ready.complete();
        return;
      } catch (_) {
        await c.dispose();
        if (_disposed) return;
      }
    }
    _starting = false;
    if (_disposed) return;
    failed.value = true;
    if (!_ready.isCompleted) _ready.complete();
  }

  void setPlaying(bool play) {
    _wantPlay = play;
    final c = controller.value;
    if (c == null || !c.value.isInitialized) return;
    if (play && !userPaused) {
      if (!c.value.isPlaying) c.play();
    } else if (c.value.isPlaying) {
      c.pause();
    }
  }

  /// يعود للبداية عند مغادرة الصفحة — مشاهدة جديدة عند الرجوع.
  void rewind() {
    userPaused = false;
    final c = controller.value;
    if (c != null &&
        c.value.isInitialized &&
        c.value.position > Duration.zero) {
      c.seekTo(Duration.zero);
    }
  }

  void applyVolume(bool muted) => controller.value?.setVolume(muted ? 0 : 1);

  void dispose() {
    _disposed = true;
    final c = controller.value;
    controller.value = null;
    c?.dispose();
    controller.dispose();
    failed.dispose();
    if (!_ready.isCompleted) _ready.complete();
  }
}

/// مجمّع المشغّلات — نافذة حول الصفحة الحالية، وتحرير ما عداها.
class _ReelPool extends ChangeNotifier {
  final _slots = <String, _ReelSlot>{};

  _ReelSlot? peek(String id) => _slots[id];

  _ReelSlot _slotFor(MediaItem m) {
    final existing = _slots[m.id];
    if (existing != null) return existing;
    final slot = _ReelSlot(m);
    _slots[m.id] = slot;
    notifyListeners();
    return slot;
  }

  bool isReady(MediaItem m) => _slots[m.id]?.isReady ?? false;

  void sync(List<ReelItem> items, int index, {required bool active}) {
    if (items.isEmpty) return;
    index = index.clamp(0, items.length - 1);
    final keep = <String>{
      for (var i = index - 1; i <= index + 1; i++)
        if (i >= 0 && i < items.length && items[i].media.isVideo)
          items[i].media.id,
    };
    var evicted = false;
    for (final id in _slots.keys.toList()) {
      if (keep.contains(id)) continue;
      final slot = _slots.remove(id)!;
      slot.setPlaying(false);
      evicted = true;
      // التحرير بعد الإطار — بعد أن تتوقف الواجهة عن الاستماع له
      WidgetsBinding.instance.addPostFrameCallback((_) => slot.dispose());
      WidgetsBinding.instance.ensureVisualUpdate();
    }
    if (evicted) notifyListeners();

    final current = items[index];
    _ReelSlot? currentSlot;
    if (current.media.isVideo) {
      currentSlot = _slotFor(current.media);
      currentSlot.setPlaying(active);
      currentSlot.start();
    }
    for (final i in [index - 1, index + 1]) {
      if (i < 0 || i >= items.length || !items[i].media.isVideo) continue;
      final s = _slotFor(items[i].media);
      s.setPlaying(false);
      s.rewind();
    }
    // التالية تُحمَّل بعد جاهزية الحالية — لا تتنافس معها على الشبكة
    if (index + 1 < items.length && items[index + 1].media.isVideo) {
      final next = _slots[items[index + 1].media.id];
      final wait = currentSlot?.ready ?? Future<void>.value();
      wait.then((_) => next?.start());
    }
  }

  void pauseAll() {
    for (final s in _slots.values) {
      s.setPlaying(false);
    }
  }

  void applyVolume(bool muted) {
    for (final s in _slots.values) {
      s.applyVolume(muted);
    }
  }

  @override
  void dispose() {
    for (final s in _slots.values) {
      s.dispose();
    }
    _slots.clear();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════
// الشاشة
// ═══════════════════════════════════════════════════════════

class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({super.key});

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen>
    with WidgetsBindingObserver {
  final _page = PageController();
  final _pool = _ReelPool();

  int _index = 0;
  _ExploreTab _tab = _ExploreTab.tours;
  HomeSection? _world;

  bool _routeVisible = true;
  bool _appResumed = true;
  Timer? _settle;
  GoRouter? _router;

  List<ReelItem> _items = const [];
  String _itemsSig = '';

  bool get _active => _routeVisible && _appResumed && _tab == _ExploreTab.tours;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ReelsAudio.load();
    ReelsAudio.muted.addListener(_onMuteChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (router != null && router != _router) {
      _router?.routerDelegate.removeListener(_onRouteChanged);
      _router = router;
      router.routerDelegate.addListener(_onRouteChanged);
      _onRouteChanged();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ReelsAudio.muted.removeListener(_onMuteChanged);
    _router?.routerDelegate.removeListener(_onRouteChanged);
    _settle?.cancel();
    _pool.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (resumed == _appResumed) return;
    _appResumed = resumed;
    _syncNow();
  }

  /// الشاشة ظاهرة فقط حين يكون أعلى مسار هو الاستكشاف نفسه —
  /// تبويب آخر أو صفحة مكان مدفوعة فوقها توقف التشغيل.
  void _onRouteChanged() {
    var location = '/explore';
    try {
      final config = _router!.routerDelegate.currentConfiguration;
      if (config.isNotEmpty) location = config.last.matchedLocation;
    } catch (_) {}
    final visible = location.startsWith('/explore');
    if (visible == _routeVisible) return;
    _routeVisible = visible;
    _syncNow();
  }

  void _onMuteChanged() {
    _pool.applyVolume(ReelsAudio.muted.value);
    if (mounted) setState(() {});
  }

  void _syncNow() {
    _settle?.cancel();
    if (!mounted) return;
    if (!_active) {
      _pool.pauseAll();
      return;
    }
    _pool.sync(_items, _index, active: true);
  }

  void _onPageChanged(int i) {
    setState(() => _index = i);
    _pool.pauseAll();
    _settle?.cancel();
    // صفحة جاهزة مسبقاً تبدأ فوراً؛ غيرها ينتظر استقرار التمرير
    // فلا نحمّل الصفحات التي يعبرها التمرير السريع.
    if (_items.isNotEmpty && _pool.isReady(_items[i].media)) {
      _syncNow();
    } else {
      _settle = Timer(const Duration(milliseconds: 180), _syncNow);
    }
    if (i + 3 >= _items.length) {
      ref.read(reelsProvider.notifier).loadMore();
    }
  }

  void _onWorldChanged(HomeSection? world) {
    if (world == _world) return;
    HapticFeedback.selectionClick();
    _pool.pauseAll();
    setState(() {
      _world = world;
      _index = 0;
    });
    if (_page.hasClients) _page.jumpToPage(0);
  }

  void _onTabChanged(_ExploreTab tab) {
    if (tab == _tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = tab);
    _syncNow();
    if (tab == _ExploreTab.tours) {
      // العودة لنفس الريل الذي كنت عليه
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_page.hasClients && (_page.page?.round() ?? 0) != _index) {
          _page.jumpToPage(_index);
        }
      });
    }
  }

  List<ReelItem> _filter(List<ReelItem> list) {
    if (_world == null) return list;
    return list
        .where((r) => r.property.type.name.toUpperCase() == _world!.typeFilter)
        .toList();
  }

  /// تحديث القائمة الحالية — ومزامنة المشغّلات إن تغيّرت.
  void _adoptItems(List<ReelItem> items) {
    final sig =
        '${items.length}:${items.isEmpty ? '' : items.first.media.id}:${_world?.name}';
    _items = items;
    if (sig == _itemsSig) return;
    _itemsSig = sig;
    if (_index >= items.length) _index = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncNow());
  }

  @override
  Widget build(BuildContext context) {
    final onTours = _tab == _ExploreTab.tours;
    final chrome = _FloatingChrome(
      tab: _tab,
      world: _world,
      onTabChanged: _onTabChanged,
      onWorldChanged: _onWorldChanged,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayFor(darkBackground: onTours),
      child: Scaffold(
        backgroundColor: onTours ? Colors.black : context.world.canvas,
        body: onTours
            ? ref
                  .watch(reelsProvider)
                  .when(
                    loading: () =>
                        Stack(children: [const _ReelsSkeleton(), chrome]),
                    error: (e, _) => Stack(
                      children: [
                        ErrorCanvas(
                          message:
                              e.toString().contains('الاتصال') // i18n-ok
                              ? 'لا اتصال بالإنترنت — تحقق من الشبكة'.tr
                              : maisonError(e),
                          onRetry: () =>
                              ref.read(reelsProvider.notifier).refresh(),
                        ),
                        chrome,
                      ],
                    ),
                    data: (list) {
                      final items = _filter(list);
                      _adoptItems(items);
                      if (items.isEmpty) {
                        return Stack(
                          children: [
                            _NoReels(
                              world: _world,
                              onShowAll: () => _onWorldChanged(null),
                            ),
                            chrome,
                          ],
                        );
                      }
                      return Stack(
                        children: [
                          NotificationListener<ScrollEndNotification>(
                            onNotification: (_) {
                              _syncNow();
                              return false;
                            },
                            child: PageView.builder(
                              key: ValueKey(_world),
                              controller: _page,
                              scrollDirection: Axis.vertical,
                              allowImplicitScrolling: true,
                              itemCount: items.length,
                              onPageChanged: _onPageChanged,
                              itemBuilder: (context, i) => _ReelPage(
                                key: ValueKey(items[i].media.id),
                                item: items[i],
                                pool: _pool,
                                isCurrent: i == _index,
                              ),
                            ),
                          ),
                          chrome,
                        ],
                      );
                    },
                  )
            : Stack(
                children: [
                  const SafeArea(
                    top: false,
                    child: ExperiencesScreen(embedded: true),
                  ),
                  chrome,
                ],
              ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// الرأس العائم — بلا ضبابية (تكلفة إطار كاملة فوق الفيديو)
// ═══════════════════════════════════════════════════════════

class _FloatingChrome extends StatelessWidget {
  const _FloatingChrome({
    required this.tab,
    required this.world,
    required this.onTabChanged,
    required this.onWorldChanged,
  });

  final _ExploreTab tab;
  final HomeSection? world;
  final ValueChanged<_ExploreTab> onTabChanged;
  final ValueChanged<HomeSection?> onWorldChanged;

  @override
  Widget build(BuildContext context) {
    final onTours = tab == _ExploreTab.tours;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: onTours
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: .55),
                      Colors.transparent,
                    ],
                  )
                : null,
            color: onTours ? null : context.world.canvas,
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _ChromeIcon(
                        icon: Icons.close_rounded,
                        onDark: onTours,
                        onTap: () => context.canPop()
                            ? context.pop()
                            : context.go('/home'),
                      ),
                      Expanded(
                        child: _Tabs(
                          tab: tab,
                          onDark: onTours,
                          onChanged: onTabChanged,
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                  if (onTours) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.zero,
                        children: [
                          _WorldChip(
                            label: 'الكل'.tr,
                            selected: world == null,
                            onTap: () => onWorldChanged(null),
                          ),
                          for (final section in HomeSection.values) ...[
                            const SizedBox(width: 8),
                            _WorldChip(
                              label: section.label,
                              icon: section.icon,
                              palette: section.palette,
                              selected: world == section,
                              onTap: () => onWorldChanged(section),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChromeIcon extends StatelessWidget {
  const _ChromeIcon({
    required this.icon,
    required this.onTap,
    this.onDark = true,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: onDark ? Colors.black.withValues(alpha: .28) : Vibes.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: onDark
                ? Colors.white.withValues(alpha: .22)
                : context.world.accent.withValues(alpha: .16),
          ),
        ),
        child: Icon(icon, size: 20, color: onDark ? Colors.white : Vibes.ink),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.tab,
    required this.onChanged,
    required this.onDark,
  });

  final _ExploreTab tab;
  final ValueChanged<_ExploreTab> onChanged;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final p = context.world;
    Widget item(_ExploreTab t, String label) {
      final active = tab == t;
      final on = onDark ? Colors.white : p.accentDeep;
      final off = onDark
          ? Colors.white.withValues(alpha: .6)
          : Vibes.inkTertiary;
      return GestureDetector(
        onTap: () => onChanged(t),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 16,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                  color: active ? on : off,
                  shadows: onDark
                      ? const [Shadow(color: Color(0x66000000), blurRadius: 8)]
                      : null,
                ),
                child: Text(label),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                height: 3,
                width: active ? 26 : 0,
                decoration: BoxDecoration(
                  color: onDark ? Colors.white : p.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        item(_ExploreTab.tours, 'جولات'.tr),
        item(_ExploreTab.experiences, 'تجارب'.tr),
      ],
    );
  }
}

class _WorldChip extends StatelessWidget {
  const _WorldChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.palette,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VibesCategory? icon;
  final WorldPalette? palette;

  @override
  Widget build(BuildContext context) {
    // الشريحة المختارة بيضاء فوق الفيديو في المظهرين، فحبرها داكن ليلاً
    final fg = selected
        ? (Appearance.isDark
              ? (palette?.night ?? VibesDark.canvas)
              : (palette?.accentDeep ?? Vibes.ink))
        : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.black.withValues(alpha: .28),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withValues(alpha: selected ? 1 : .22),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              VibesCategoryIcon(category: icon!, size: 14, color: fg),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: VibesFont.ui,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: fg,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReelsSkeleton extends StatelessWidget {
  const _ReelsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// صفحة الريل
// ═══════════════════════════════════════════════════════════

class _ReelPage extends ConsumerStatefulWidget {
  const _ReelPage({
    super.key,
    required this.item,
    required this.pool,
    required this.isCurrent,
  });

  final ReelItem item;
  final _ReelPool pool;
  final bool isCurrent;

  @override
  ConsumerState<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends ConsumerState<_ReelPage> {
  int _heartPulse = 0;
  int _flash = 0;
  bool _holding = false;

  _ReelSlot? get _slot => widget.pool.peek(widget.item.media.id);

  void _togglePlay() {
    final slot = _slot;
    final c = slot?.controller.value;
    if (slot == null || c == null || !c.value.isInitialized) return;
    HapticFeedback.selectionClick();
    if (c.value.isPlaying) {
      slot.userPaused = true;
      c.pause();
    } else {
      slot.userPaused = false;
      c.play();
    }
    setState(() => _flash++);
  }

  void _hold(bool down) {
    final c = _slot?.controller.value;
    if (c == null || !c.value.isInitialized || _slot!.userPaused) return;
    _holding = down;
    down ? c.pause() : c.play();
    setState(() {});
  }

  Future<void> _like() async {
    setState(() => _heartPulse++);
    HapticFeedback.lightImpact();
    final property = widget.item.property;
    if (!ref.read(authControllerProvider).loggedIn) return;
    final favs = ref.read(favoritesProvider).valueOrNull ?? const [];
    if (!favs.any((p) => p.id == property.id)) {
      ref.read(favoritesProvider.notifier).toggle(property);
    }
  }

  @override
  Widget build(BuildContext context) {
    final property = widget.item.property;
    final media = widget.item.media;
    final palette = WorldPalette.forType(property.type.name);
    final poster = media.sharpPosterUrl ?? property.coverUrl;

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // الغلاف الحاد — يبقى تحت الفيديو فلا يظهر سواد أبداً
          if (poster != null && poster.isNotEmpty)
            VibesNetImage(url: poster, fit: BoxFit.cover)
          else
            DecoratedBox(
              decoration: BoxDecoration(gradient: palette.nightfall),
            ),

          // الفيديو
          ListenableBuilder(
            listenable: widget.pool,
            builder: (context, _) {
              final slot = _slot;
              if (slot == null) return const SizedBox.shrink();
              return ValueListenableBuilder<VideoPlayerController?>(
                valueListenable: slot.controller,
                builder: (context, c, _) {
                  if (c == null) return const SizedBox.shrink();
                  return _VideoLayer(controller: c);
                },
              );
            },
          ),

          const _Shade(),

          // اللمس: نقرة تشغيل/إيقاف، مزدوجة إعجاب، ضغط مطوّل إيقاف مؤقت
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _togglePlay,
              onDoubleTap: _like,
              onLongPressStart: (_) => _hold(true),
              onLongPressEnd: (_) => _hold(false),
            ),
          ),
          Center(child: HeartBurst(trigger: _heartPulse, size: 120)),

          // حالة التشغيل في المنتصف: مؤشر تحميل أو أيقونة إيقاف
          Center(
            child: IgnorePointer(
              child: ListenableBuilder(
                listenable: widget.pool,
                builder: (context, _) {
                  final slot = _slot;
                  if (slot == null) return const SizedBox.shrink();
                  return ValueListenableBuilder<VideoPlayerController?>(
                    valueListenable: slot.controller,
                    builder: (context, c, _) => _CenterState(
                      controller: c,
                      userPaused: slot.userPaused,
                      active: widget.isCurrent,
                      flash: _flash,
                    ),
                  );
                },
              ),
            ),
          ),

          // المعلومات والإجراءات وشريط التقدم
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _holding ? 0 : 1,
            child: _ReelOverlay(
              property: property,
              palette: palette,
              progress: ListenableBuilder(
                listenable: widget.pool,
                builder: (context, _) {
                  final slot = _slot;
                  if (slot == null) return const _SeekBar(controller: null);
                  return ValueListenableBuilder<VideoPlayerController?>(
                    valueListenable: slot.controller,
                    builder: (context, c, _) =>
                        _SeekBar(controller: c, color: palette.accentLight),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// طبقة الفيديو — تملأ الشاشة وتظهر بتلاشٍ ناعم فوق الغلاف.
class _VideoLayer extends StatelessWidget {
  const _VideoLayer({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.size;
    if (!controller.value.isInitialized || size.width == 0)
      return const SizedBox.shrink();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}

class _CenterState extends StatelessWidget {
  const _CenterState({
    required this.controller,
    required this.userPaused,
    required this.active,
    required this.flash,
  });

  final VideoPlayerController? controller;
  final bool userPaused;
  final bool active;
  final int flash;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (!active) return const SizedBox.shrink();
    if (c == null) return const _Spinner();
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: c,
      builder: (context, v, _) {
        if (v.isBuffering && !userPaused) return const _Spinner();
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: userPaused ? 1 : 0,
          child: Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .42),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: .28)),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
        );
      },
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .35),
        shape: BoxShape.circle,
      ),
      child: const CircularProgressIndicator(
        strokeWidth: 2.4,
        color: Colors.white,
      ),
    );
  }
}

/// شريط تقدم رفيع قابل للسحب للتقديم والترجيع.
class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.controller, this.color = Colors.white});

  final VideoPlayerController? controller;
  final Color color;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _drag;

  void _seekTo(double localX, double width) {
    final c = widget.controller;
    if (c == null || !c.value.isInitialized || width <= 0) return;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    var f = (localX / width).clamp(0.0, 1.0);
    if (rtl) f = 1 - f;
    setState(() => _drag = f);
    c.seekTo(c.value.duration * f);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return LayoutBuilder(
      builder: (context, box) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) =>
              _seekTo(d.localPosition.dx, box.maxWidth),
          onHorizontalDragUpdate: (d) =>
              _seekTo(d.localPosition.dx, box.maxWidth),
          onHorizontalDragEnd: (_) => setState(() => _drag = null),
          onTapDown: (d) => _seekTo(d.localPosition.dx, box.maxWidth),
          onTapUp: (_) => setState(() => _drag = null),
          child: SizedBox(
            height: 22,
            child: Center(
              child: c == null
                  ? _bar(0, false)
                  : ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: c,
                      builder: (context, v, _) {
                        final ms = v.duration.inMilliseconds;
                        final f =
                            _drag ??
                            (ms > 0 ? v.position.inMilliseconds / ms : 0.0);
                        return _bar(f.clamp(0.0, 1.0), _drag != null);
                      },
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _bar(double f, bool dragging) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: dragging ? 6 : 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: f,
          minHeight: dragging ? 6 : 3,
          backgroundColor: Colors.white.withValues(alpha: .25),
          valueColor: AlwaysStoppedAnimation(widget.color),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// التراكب — معلومات المكان وزرّا الحجز، وإجراءات جانبية
// ═══════════════════════════════════════════════════════════

class _ReelOverlay extends ConsumerWidget {
  const _ReelOverlay({
    required this.property,
    required this.palette,
    this.progress,
  });

  final Property property;
  final WorldPalette palette;
  final Widget? progress;

  num get _fromPrice {
    final prices = <num>[
      property.pricePerDay,
      if (property.priceMorningShift != null) property.priceMorningShift!,
      if (property.priceEveningShift != null) property.priceEveningShift!,
    ].where((v) => v > 0).toList()..sort();
    return prices.isEmpty ? property.pricePerDay : prices.first;
  }

  Future<void> _toggleFav(BuildContext context, WidgetRef ref) async {
    if (!ref.read(authControllerProvider).loggedIn) {
      final ok = await context.push<bool>('/login');
      if (ok != true || !context.mounted) return;
      if (!ref.read(authControllerProvider).loggedIn) return;
    }
    HapticFeedback.lightImpact();
    ref.read(favoritesProvider.notifier).toggle(property);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = (ref.watch(favoritesProvider).valueOrNull ?? const []).any(
      (p) => p.id == property.id,
    );
    final meta = [
      property.cityName ?? property.provinceName ?? '',
      if (property.capacity > 0) 'حتى {n} ضيف'.trN(property.capacity),
    ].where((s) => s.isNotEmpty).join(' · ');
    final unit = property.type == PropertyType.decoration
        ? 'للخدمة'.tr
        : property.supportsShifts
        ? 'للفترة'.tr
        : 'لليوم'.tr;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 16, 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: palette.fill,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              property.typeLabelAr.tr,
                              style: TextStyle(
                                fontFamily: VibesFont.ui,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                color: palette.onAccent,
                                height: 1.3,
                              ),
                            ),
                          ),
                          if (property.ratingCount > 0)
                            _Glass(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 13,
                                    color: Color(0xFFF5B301),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    property.ratingAvg.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontFamily: VibesFont.ui,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => context.push('/property/${property.id}'),
                        child: Text(
                          property.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: VibesFont.ui,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.2,
                            shadows: [
                              Shadow(color: Color(0x88000000), blurRadius: 12),
                            ],
                          ),
                        ),
                      ),
                      if (meta.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(
                                Icons.place_rounded,
                                size: 13,
                                color: palette.accentLight,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  meta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: VibesFont.ui,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: .85),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            'يبدأ من '.tr,
                            style: TextStyle(
                              fontFamily: VibesFont.ui,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: .7),
                            ),
                          ),
                          Text(
                            formatIqdShort(_fromPrice),
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'د.ع {unit}'.trArgs({'unit': unit}),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: VibesFont.ui,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: .7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // ── الإجراءات الجانبية ──
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SideAction(
                      icon: saved
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      label: saved ? 'محفوظ'.tr : 'حفظ'.tr,
                      tint: saved ? const Color(0xFFFF4D6D) : Colors.white,
                      onTap: () => _toggleFav(context, ref),
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: ReelsAudio.muted,
                      builder: (context, muted, _) => _SideAction(
                        icon: muted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        label: muted ? 'صامت'.tr : 'الصوت'.tr,
                        tint: Colors.white,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ReelsAudio.toggle();
                        },
                      ),
                    ),
                    _SideAction(
                      icon: Icons.ios_share_rounded,
                      label: 'مشاركة'.tr,
                      tint: Colors.white,
                      onTap: () => Share.share(property.name),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: PressScale(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      context.push('/book/${property.id}');
                    },
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: themed(Colors.white, palette.accentLight),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: palette.glow.withValues(alpha: .45),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_available_rounded,
                            size: 19,
                            color: themed(palette.accentDeep, palette.night),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'احجز الآن'.tr,
                            style: TextStyle(
                              fontFamily: VibesFont.ui,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              color: themed(palette.accentDeep, palette.night),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: WorldGhostButton(
                    label: 'تفاصيل المكان'.tr,
                    icon: Icons.info_outline_rounded,
                    height: 50,
                    onDark: true,
                    onTap: () => context.push('/property/${property.id}'),
                  ),
                ),
              ],
            ),
            ?progress,
          ],
        ),
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .32),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .2)),
      ),
      child: child,
    );
  }
}

class _SideAction extends StatelessWidget {
  const _SideAction({
    required this.icon,
    required this.label,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PressScale(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .3),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: .2)),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (c, a) =>
                    ScaleTransition(scale: a, child: c),
                child: Icon(icon, key: ValueKey(icon), size: 23, color: tint),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: VibesFont.ui,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                shadows: [Shadow(color: Color(0x99000000), blurRadius: 6)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ظل علوي خفيف وسفلي أعمق يحمل المعلومات فوق الفيديو.
class _Shade extends StatelessWidget {
  const _Shade();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, .18, .5, 1],
            colors: [
              Color(0x55000000),
              Colors.transparent,
              Colors.transparent,
              Color(0xE0000000),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// لا فيديوهات — الاستكشاف يعرض الجولات العمودية فقط
// ═══════════════════════════════════════════════════════════

class _NoReels extends StatelessWidget {
  const _NoReels({required this.world, required this.onShowAll});

  final HomeSection? world;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final p = world?.palette ?? context.world;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: p.nightfall),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .22),
                  ),
                ),
                child: const Icon(
                  Icons.videocam_outlined,
                  size: 36,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                world == null ? 'لا جولات فيديو بعد'.tr : world!.noReelsTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'تظهر هنا الأماكن التي نشرت جولة فيديو عمودية — نضيف جولات جديدة باستمرار' // i18n-ok
                    .tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: VibesFont.ui,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: .75),
                  height: 1.6,
                ),
              ),
              if (world != null) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: 200,
                  child: WorldButton(
                    label: 'كل الجولات'.tr,
                    icon: Icons.play_circle_rounded,
                    palette: p,
                    onTap: onShowAll,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
