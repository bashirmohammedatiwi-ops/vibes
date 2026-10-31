import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../core/constants/map_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/i18n/i18n.dart';
import '../../core/utils/vibes_net_image.dart';

/// علامة على الخريطة — بيانات فقط (GPU-native).
class VibesMapMarker {
  const VibesMapMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.label,
    this.imageUrl,
    this.accent,
    this.accentLight,
    this.selected = false,
    this.photoPin = false,
  });

  final String id;
  final double latitude;
  final double longitude;

  /// نص تحت الدبوس (السعر المختصر عادةً).
  final String? label;
  final String? imageUrl;
  final Color? accent;

  /// اللون الفاتح لتدرّج حلقة الدبوس.
  final Color? accentLight;
  final bool selected;

  /// دوائر صور — افتراضياً عند وجود [imageUrl].
  final bool photoPin;
}

/// صبغة الخريطة — تلوّن اليابسة والماء والمساحات الخضراء بجوّ العالم.
class VibesMapTint {
  const VibesMapTint({
    required this.land,
    required this.water,
    required this.green,
    required this.building,
  });

  final Color land;
  final Color water;
  final Color green;
  final Color building;

  @override
  bool operator ==(Object other) =>
      other is VibesMapTint &&
      other.land == land &&
      other.water == water &&
      other.green == green &&
      other.building == building;

  @override
  int get hashCode => Object.hash(land, water, green, building);
}

/// تحكم خارجي بالكاميرا — تكبير، موقع، تركيز على مكان.
class VibesMapController {
  _VibesMapViewState? _state;

  void _attach(_VibesMapViewState state) => _state = state;

  void _detach(_VibesMapViewState state) {
    if (_state == state) _state = null;
  }

  Future<void> flyToLatLng(
    double lat,
    double lng, {
    double zoom = MapConstants.detailZoom,
  }) async {
    await _state?._flyToLatLng(lat, lng, zoom: zoom);
  }

  Future<void> flyToMarker(VibesMapMarker marker, {double? zoom}) async {
    await _state?._flyToLatLng(
      marker.latitude,
      marker.longitude,
      zoom: zoom ?? MapConstants.detailZoom,
    );
  }

  Future<void> zoomIn() => _state?._zoomBy(0.75) ?? Future.value();

  Future<void> zoomOut() => _state?._zoomBy(-0.75) ?? Future.value();

  Future<void> fitToMarkers() => _state?._fitToMarkers() ?? Future.value();
}

/// خريطة Mapbox أصلية:
///   • تحديث تدريجي للعلامات — لا يُعاد رسم إلا ما تغيّر.
///   • تبديل الطبقة دون إعادة بناء الخريطة.
///   • أسماء عربية وصبغة بجوّ العالم وإخفاء ضجيج المتاجر والمواصلات.
class VibesMapView extends StatefulWidget {
  const VibesMapView({
    super.key,
    this.controller,
    required this.markers,
    this.centerLat,
    this.centerLng,
    this.zoom = MapConstants.defaultZoom,
    this.height,
    this.interactive = true,
    this.selectedId,
    this.onMarkerTap,
    this.onMapTap,
    this.fitBounds = false,
    this.focusCluster = false,
    this.fitMarkers,
    this.flyToSelection = true,
    this.padding = const EdgeInsets.fromLTRB(48, 120, 48, 160),
    this.borderRadius,
    this.styleUri = MapConstants.styleUri,
    this.pitch = 0,
    this.tint,
  });

  final VibesMapController? controller;
  final List<VibesMapMarker> markers;
  final double? centerLat;
  final double? centerLng;
  final double zoom;
  final double? height;
  final bool interactive;
  final String? selectedId;
  final ValueChanged<VibesMapMarker>? onMarkerTap;
  final VoidCallback? onMapTap;
  final bool fitBounds;
  final bool focusCluster;

  /// علامات تُستخدم لحساب الزوم الأولي (مثلاً المزارع فقط).
  final List<VibesMapMarker>? fitMarkers;
  final bool flyToSelection;
  final EdgeInsets padding;
  final BorderRadius? borderRadius;
  final String styleUri;
  final double pitch;

  /// صبغة الطبقة الفاتحة — تُتجاهل للأقمار الصناعية والتضاريس.
  final VibesMapTint? tint;

  @override
  State<VibesMapView> createState() => _VibesMapViewState();
}

class _VibesMapViewState extends State<VibesMapView> {
  MapboxMap? _map;
  PointAnnotationManager? _pins;
  String? _loadedStyle;

  /// العلامات المرسومة فعلاً: المعرّف ← (التوقيع، الكائن).
  final _drawn = <String, ({String sig, PointAnnotation annotation})>{};
  final _byId = <String, VibesMapMarker>{};
  final _pinCache = <int, Uint8List>{};
  final _imageCache = <String, ui.Image>{};

  bool _syncing = false;
  bool _syncAgain = false;
  double _dpr = 3;

  /// الطبقة الفاتحة الافتراضية تصبح داكنة في الوضع الليلي؛ الأقمار
  /// الصناعية والتضاريس تبقى كما هي.
  String get _effectiveStyle =>
      Appearance.isDark && widget.styleUri == MapConstants.styleUri
      ? MapConstants.darkStyleUri
      : widget.styleUri;

  /// سطح الدبوس غير المحدد والنص فوق تعبئة الدبوس المحدد.
  Color get _pinSurface => themed(Colors.white, VibesDark.surface);
  Color get _onPinFill => themed(Colors.white, VibesDark.canvas);

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dpr = MediaQuery.devicePixelRatioOf(context).clamp(2.0, 3.5);
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant VibesMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (_map == null) return;

    if (_loadedStyle != _effectiveStyle) {
      _switchStyle();
      return;
    }
    if (oldWidget.tint != widget.tint) _applyStyleTweaks();

    // مزامنة تفاضلية — رخيصة حين لا يتغير شيء
    _scheduleSync();

    if (widget.flyToSelection &&
        widget.selectedId != null &&
        oldWidget.selectedId != widget.selectedId) {
      final m = widget.markers
          .where((x) => x.id == widget.selectedId)
          .firstOrNull;
      if (m != null) _flyToLatLng(m.latitude, m.longitude, zoom: 14.4);
    }
    if (widget.fitBounds &&
        (_idsChanged(oldWidget.markers, widget.markers) ||
            _idsChanged(
              oldWidget.fitMarkers ?? const [],
              widget.fitMarkers ?? const [],
            ))) {
      _fitToMarkers();
    }
  }

  /// تغيّر المجموعة نفسها (لا التحديد) — هو وحده ما يستدعي إعادة التأطير.
  bool _idsChanged(List<VibesMapMarker> a, List<VibesMapMarker> b) {
    if (a.length != b.length) return true;
    final sa = a.map((m) => m.id).toSet();
    return b.any((m) => !sa.contains(m.id));
  }

  // ── الكاميرا ──

  Future<void> _flyToLatLng(
    double lat,
    double lng, {
    required double zoom,
  }) async {
    final map = _map;
    if (map == null) return;
    await map.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: zoom,
        pitch: widget.pitch,
      ),
      MapAnimationOptions(duration: widget.interactive ? 650 : 0),
    );
  }

  Future<void> _zoomBy(double delta) async {
    final map = _map;
    if (map == null) return;
    final cam = await map.getCameraState();
    await map.easeTo(
      CameraOptions(
        center: cam.center,
        zoom: (cam.zoom + delta).clamp(4.5, 18),
        pitch: widget.pitch,
        bearing: cam.bearing,
      ),
      MapAnimationOptions(duration: 280),
    );
  }

  // ── الإنشاء والستايل ──

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    await Future.wait([
      map.scaleBar.updateSettings(ScaleBarSettings(enabled: false)),
      map.compass.updateSettings(CompassSettings(enabled: false)),
      map.logo.updateSettings(LogoSettings(marginBottom: 6, marginLeft: 8)),
      map.attribution.updateSettings(
        AttributionSettings(marginBottom: 4, marginRight: 6),
      ),
      if (!widget.interactive)
        map.gestures.updateSettings(
          GesturesSettings(
            scrollEnabled: false,
            pinchToZoomEnabled: false,
            rotateEnabled: false,
            pitchEnabled: false,
            doubleTapToZoomInEnabled: false,
            doubleTouchToZoomOutEnabled: false,
            quickZoomEnabled: false,
          ),
        )
      else
        map.gestures.updateSettings(
          GesturesSettings(rotateEnabled: false, pitchEnabled: false),
        ),
    ]);

    _pins = await map.annotations.createPointAnnotationManager();
    _pins!.tapEvents(onTap: _onPinTap);
    _loadedStyle = _effectiveStyle;

    await _syncMarkers();

    if ((widget.fitBounds || widget.focusCluster) &&
        widget.markers.isNotEmpty) {
      await _fitToMarkers();
    } else {
      await map.setCamera(
        CameraOptions(
          center: Point(
            coordinates: Position(
              widget.centerLng ?? MapConstants.iraqCenter.lng,
              widget.centerLat ?? MapConstants.iraqCenter.lat,
            ),
          ),
          zoom: widget.zoom,
          pitch: widget.pitch,
          bearing: 0,
        ),
      );
    }
  }

  void _onStyleLoaded(StyleLoadedEventData _) {
    _applyStyleTweaks();
  }

  /// تعريب الأسماء، إخفاء الضجيج، وصبغة العالم.
  Future<void> _applyStyleTweaks() async {
    final map = _map;
    if (map == null) return;
    final style = map.style;
    try {
      await style.localizeLabels(I18n.locale, null);
    } catch (_) {}

    Future<void> set(String layer, String prop, Object value) async {
      try {
        if (await style.styleLayerExists(layer)) {
          await style.setStyleLayerProperty(layer, prop, value);
        }
      } catch (_) {}
    }

    // ضجيج لا يخدم من يبحث عن مزرعة أو قاعة
    await Future.wait([
      for (final l in const ['poi-label', 'transit-label', 'airport-label'])
        set(l, 'visibility', 'none'),
    ]);

    if (widget.styleUri != MapConstants.styleUri) return;

    // ليل VIBES: الطبقة الداكنة بدرجات الكحلي بدل صبغة العالم الفاتحة.
    if (Appearance.isDark) {
      await Future.wait([
        set('land', 'background-color', _hex(const Color(0xFF0F1E31))),
        set('water', 'fill-color', _hex(VibesDark.canvas)),
        set('national-park', 'fill-color', _hex(const Color(0xFF12263A))),
        set('landuse', 'fill-color', _hex(const Color(0xFF12263A))),
        set('building', 'fill-color', _hex(VibesDark.surfaceMuted)),
      ]);
      return;
    }

    final tint = widget.tint;
    if (tint == null) return;
    await Future.wait([
      set('land', 'background-color', _hex(tint.land)),
      set('water', 'fill-color', _hex(tint.water)),
      set('national-park', 'fill-color', _hex(tint.green)),
      set('landuse', 'fill-color', _hex(tint.green)),
      set('building', 'fill-color', _hex(tint.building)),
    ]);
  }

  String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  /// تبديل الطبقة دون هدم الخريطة — العلامات تُعاد بعد تحميل الستايل.
  Future<void> _switchStyle() async {
    final map = _map;
    if (map == null || _loadedStyle == _effectiveStyle) return;
    _loadedStyle = _effectiveStyle;
    await map.loadStyleURI(_effectiveStyle);
    _drawn.clear();
    try {
      await _pins?.deleteAll();
    } catch (_) {}
    await _syncMarkers();
    final cam = await map.getCameraState();
    await map.easeTo(
      CameraOptions(center: cam.center, zoom: cam.zoom, pitch: widget.pitch),
      MapAnimationOptions(duration: 500),
    );
  }

  // ── العلامات ──

  void _onPinTap(PointAnnotation annotation) {
    final id = annotation.customData?['id']?.toString();
    if (id == null) return;
    final marker = _byId[id];
    if (marker != null) widget.onMarkerTap?.call(marker);
  }

  void _scheduleSync() {
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncMarkers();
  }

  bool _isSelected(VibesMapMarker m) => m.selected || m.id == widget.selectedId;

  String _sig(VibesMapMarker m) =>
      '${m.imageUrl}|${m.label}|${m.accent?.toARGB32()}|${_isSelected(m)}|${Appearance.isDark}';

  /// مزامنة تفاضلية: حذف المختفي، إضافة الجديد، وتحديث ما تغيّر توقيعه.
  Future<void> _syncMarkers() async {
    final manager = _pins;
    if (manager == null) return;
    _syncing = true;
    try {
      final desired = {for (final m in widget.markers) m.id: m};
      _byId
        ..clear()
        ..addAll(desired);

      // حذف
      for (final id
          in _drawn.keys.where((id) => !desired.containsKey(id)).toList()) {
        final entry = _drawn.remove(id)!;
        try {
          await manager.delete(entry.annotation);
        } catch (_) {}
      }

      // تحديث المتغيّر
      final changed = desired.values.where((m) {
        final d = _drawn[m.id];
        return d != null && d.sig != _sig(m);
      }).toList();
      await Future.wait(
        changed.map((m) async {
          final d = _drawn[m.id]!;
          final selected = _isSelected(m);
          final a = d.annotation
            ..image = await _pinFor(m, selected)
            ..symbolSortKey = selected ? 100000 : -m.latitude;
          try {
            await manager.update(a);
            _drawn[m.id] = (sig: _sig(m), annotation: a);
          } catch (_) {}
        }),
      );

      // إضافة الجديد — الصور تُجهَّز بالتوازي
      final fresh = desired.values
          .where((m) => !_drawn.containsKey(m.id))
          .toList();
      if (fresh.isNotEmpty) {
        final options = await Future.wait(fresh.map(_optionsFor));
        final created = await manager.createMulti(options);
        for (var i = 0; i < created.length && i < fresh.length; i++) {
          final a = created[i];
          if (a != null)
            _drawn[fresh[i].id] = (sig: _sig(fresh[i]), annotation: a);
        }
      }
    } finally {
      _syncing = false;
      if (_syncAgain && mounted) {
        _syncAgain = false;
        _syncMarkers();
      }
    }
  }

  Future<PointAnnotationOptions> _optionsFor(VibesMapMarker m) async {
    final selected = _isSelected(m);
    return PointAnnotationOptions(
      geometry: Point(coordinates: Position(m.longitude, m.latitude)),
      image: await _pinFor(m, selected),
      iconAnchor: IconAnchor.BOTTOM,
      symbolSortKey: selected ? 100000 : -m.latitude,
      customData: {'id': m.id},
    );
  }

  Future<Uint8List> _pinFor(VibesMapMarker m, bool selected) {
    final usePhoto = m.photoPin || (m.imageUrl?.isNotEmpty ?? false);
    return usePhoto
        ? _photoPin(m, selected)
        : _pillPin(m.accent ?? Vibes.teal, selected, m.label);
  }

  Future<ui.Image?> _loadPhoto(String? url) async {
    if (url == null || url.isEmpty) return null;
    final sized = sizedImageUrl(url, 320);
    final cached = _imageCache[sized];
    if (cached != null) return cached;
    try {
      final file = await VibesNetImage.cache.getSingleFile(sized);
      final bytes = await file.readAsBytes();
      final px = (64 * _dpr).round();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: px,
        targetHeight: px,
      );
      final frame = await codec.getNextFrame();
      _imageCache[sized] = frame.image;
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  /// دبوس الصورة — دائرة بحلقة متدرّجة بلون العالم، وكبسولة سعر تحتها،
  /// ونقطة تثبيت. المحدد أكبر بهالة ضوء وكبسولة ممتلئة.
  Future<Uint8List> _photoPin(VibesMapMarker m, bool selected) async {
    final accent = m.accent ?? Vibes.teal;
    final light = m.accentLight ?? Color.lerp(accent, Colors.white, .35)!;
    final key = Object.hash(
      m.id,
      m.imageUrl,
      m.label,
      selected,
      accent.toARGB32(),
      _dpr,
      4,
      Appearance.isDark,
    );
    final cached = _pinCache[key];
    if (cached != null) return cached;

    final s = _dpr;
    final d = (selected ? 60.0 : 48.0) * s; // قطر الدائرة
    final ring = (selected ? 3.6 : 3.0) * s;
    final halo = (selected ? 10.0 : 4.0) * s;
    final hasLabel = (m.label ?? '').isNotEmpty;

    final tp = TextPainter(
      text: TextSpan(
        text: m.label ?? '',
        style: TextStyle(
          fontFamily: VibesFont.ui,
          fontSize: (selected ? 12.5 : 11.5) * s,
          fontWeight: FontWeight.w900,
          color: selected ? _onPinFill : Color.lerp(accent, Vibes.ink, .35),
          height: 1.15,
        ),
      ),
      textDirection: I18n.isEn ? TextDirection.ltr : TextDirection.rtl,
    )..layout();
    final pillH = hasLabel ? tp.height + 6 * s : 0.0;
    final pillW = hasLabel ? tp.width + 16 * s : 0.0;
    final dotR = 3.4 * s;

    final w = [d + halo * 2, pillW + 6 * s].reduce((a, b) => a > b ? a : b);
    final circleTop = halo;
    final cx = w / 2;
    final cy = circleTop + d / 2;
    final pillTop = circleTop + d - 8 * s;
    final h =
        (hasLabel ? pillTop + pillH : circleTop + d) + 5 * s + dotR * 2 + 2 * s;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // هالة المحدد
    if (selected) {
      canvas.drawCircle(
        Offset(cx, cy),
        d / 2 + halo * .8,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  accent.withValues(alpha: .38),
                  accent.withValues(alpha: 0),
                ],
              ).createShader(
                Rect.fromCircle(center: Offset(cx, cy), radius: d / 2 + halo),
              ),
      );
    }

    // ظل
    canvas.drawCircle(
      Offset(cx, cy + 2.5 * s),
      d / 2,
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * s),
    );

    // الحلقة المتدرّجة
    canvas.drawCircle(
      Offset(cx, cy),
      d / 2,
      Paint()
        ..shader = SweepGradient(
          colors: [light, accent, light],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: d / 2)),
    );
    // فاصل أبيض
    canvas.drawCircle(
      Offset(cx, cy),
      d / 2 - ring,
      Paint()..color = _pinSurface,
    );

    // الصورة
    final inner = d / 2 - ring - 1.6 * s;
    final photo = await _loadPhoto(m.imageUrl);
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: inner)),
    );
    if (photo != null) {
      paintImage(
        canvas: canvas,
        rect: Rect.fromCircle(center: Offset(cx, cy), radius: inner),
        image: photo,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      );
    } else {
      canvas.drawCircle(
        Offset(cx, cy),
        inner,
        Paint()
          ..shader = LinearGradient(colors: [light, accent]).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: inner),
          ),
      );
      final glyph = TextPainter(
        text: TextSpan(
          text: '◆',
          style: TextStyle(
            fontSize: inner * .8,
            color: _onPinFill.withValues(alpha: .9),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      glyph.paint(canvas, Offset(cx - glyph.width / 2, cy - glyph.height / 2));
    }
    canvas.restore();

    // كبسولة السعر
    if (hasLabel) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, pillTop + pillH / 2),
          width: pillW,
          height: pillH,
        ),
        Radius.circular(pillH / 2),
      );
      canvas.drawRRect(
        rect.shift(Offset(0, 1.5 * s)),
        Paint()
          ..color = const Color(0x33000000)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * s),
      );
      if (selected) {
        canvas.drawRRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              colors: [light, accent],
            ).createShader(rect.outerRect),
        );
      } else {
        canvas.drawRRect(rect, Paint()..color = _pinSurface);
        canvas.drawRRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1 * s
            ..color = accent.withValues(alpha: .35),
        );
      }
      tp.paint(
        canvas,
        Offset(cx - tp.width / 2, pillTop + (pillH - tp.height) / 2),
      );
    }

    // نقطة التثبيت
    final dotY = h - dotR - 1 * s;
    canvas.drawCircle(
      Offset(cx, dotY),
      dotR + 1.4 * s,
      Paint()..color = _pinSurface,
    );
    canvas.drawCircle(Offset(cx, dotY), dotR, Paint()..color = accent);

    final image = await recorder.endRecording().toImage(w.ceil(), h.ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final data = bytes!.buffer.asUint8List();
    _pinCache[key] = data;
    return data;
  }

  /// دبوس نصّي (بلا صورة) — كبسولة بيضاء بخط لون العالم.
  Future<Uint8List> _pillPin(Color accent, bool selected, String? label) async {
    final key = Object.hash(
      accent.toARGB32(),
      selected,
      label ?? '',
      _dpr,
      4,
      Appearance.isDark,
    );
    final cached = _pinCache[key];
    if (cached != null) return cached;
    final s = _dpr;
    final text = (label ?? '').isEmpty ? '•' : label!;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: VibesFont.ui,
          fontSize: (selected ? 13 : 12) * s,
          fontWeight: FontWeight.w900,
          color: selected ? _onPinFill : Vibes.ink,
        ),
      ),
      textDirection: I18n.isEn ? TextDirection.ltr : TextDirection.rtl,
    )..layout();
    final pillW = tp.width + 22 * s;
    final pillH = tp.height + 10 * s;
    final tail = 7 * s;
    final w = pillW + 8 * s;
    final h = pillH + tail + 6 * s;
    final cx = w / 2;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH((w - pillW) / 2, 2 * s, pillW, pillH),
      Radius.circular(pillH / 2),
    );
    canvas.drawRRect(
      rect.shift(Offset(0, 2 * s)),
      Paint()
        ..color = const Color(0x38000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * s),
    );
    final fill = Paint()..color = selected ? accent : _pinSurface;
    canvas.drawRRect(rect, fill);
    if (!selected && Appearance.isDark) {
      canvas.drawRRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 * s
          ..color = VibesDark.hairlineStrong,
      );
    }
    final tailPath = Path()
      ..moveTo(cx - 6 * s, rect.bottom - 1)
      ..lineTo(cx + 6 * s, rect.bottom - 1)
      ..lineTo(cx, rect.bottom + tail)
      ..close();
    canvas.drawPath(tailPath, fill);
    tp.paint(
      canvas,
      Offset(cx - tp.width / 2, rect.top + (pillH - tp.height) / 2),
    );
    final image = await recorder.endRecording().toImage(w.ceil(), h.ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final data = bytes!.buffer.asUint8List();
    _pinCache[key] = data;
    return data;
  }

  // ── التأطير ──

  List<VibesMapMarker> get _cameraMarkers {
    final pool = (widget.fitMarkers != null && widget.fitMarkers!.isNotEmpty)
        ? widget.fitMarkers!
        : widget.markers;
    if (pool.isEmpty) return widget.markers;
    if (!widget.focusCluster || pool.length < 2) return pool;
    return _densestCluster(pool);
  }

  List<VibesMapMarker> _densestCluster(List<VibesMapMarker> markers) {
    const cell = 0.28;
    final buckets = <String, List<VibesMapMarker>>{};
    for (final marker in markers) {
      final key =
          '${(marker.latitude / cell).floor()}_${(marker.longitude / cell).floor()}';
      buckets.putIfAbsent(key, () => []).add(marker);
    }
    var best = buckets.values.first;
    for (final bucket in buckets.values) {
      if (bucket.length > best.length) best = bucket;
    }
    var lat = 0.0;
    var lng = 0.0;
    for (final marker in best) {
      lat += marker.latitude;
      lng += marker.longitude;
    }
    lat /= best.length;
    lng /= best.length;
    final cluster = markers
        .where(
          (m) =>
              (m.latitude - lat).abs() < 0.42 &&
              (m.longitude - lng).abs() < 0.42,
        )
        .toList();
    return cluster.isEmpty ? best : cluster;
  }

  Future<void> _fitToMarkers() async {
    final map = _map;
    final markers = _cameraMarkers;
    if (map == null || markers.isEmpty) return;

    if (markers.length == 1) {
      final m = markers.first;
      await map.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(m.longitude, m.latitude)),
          zoom: MapConstants.detailZoom,
          pitch: widget.pitch,
        ),
        MapAnimationOptions(duration: 650),
      );
      return;
    }

    var minLng = markers.first.longitude, maxLng = minLng;
    var minLat = markers.first.latitude, maxLat = minLat;
    for (final m in markers) {
      if (m.longitude < minLng) minLng = m.longitude;
      if (m.longitude > maxLng) maxLng = m.longitude;
      if (m.latitude < minLat) minLat = m.latitude;
      if (m.latitude > maxLat) maxLat = m.latitude;
    }

    final camera = await map.cameraForCoordinateBounds(
      CoordinateBounds(
        southwest: Point(coordinates: Position(minLng, minLat)),
        northeast: Point(coordinates: Position(maxLng, maxLat)),
        infiniteBounds: false,
      ),
      MbxEdgeInsets(
        top: widget.padding.top,
        left: widget.padding.left,
        bottom: widget.padding.bottom,
        right: widget.padding.right,
      ),
      null,
      null,
      widget.focusCluster ? 15.2 : 12,
      null,
    );
    await map.flyTo(
      camera,
      MapAnimationOptions(duration: widget.interactive ? 700 : 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final map = MapWidget(
      key: const ValueKey('vibes-map'),
      styleUri: _effectiveStyle,
      textureView: true,
      cameraOptions: CameraOptions(
        center: Point(
          coordinates: Position(
            widget.centerLng ?? MapConstants.iraqCenter.lng,
            widget.centerLat ?? MapConstants.iraqCenter.lat,
          ),
        ),
        zoom: widget.zoom,
        pitch: widget.pitch,
      ),
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: _onStyleLoaded,
      onTapListener: widget.onMapTap == null ? null : (_) => widget.onMapTap!(),
    );

    Widget framed = map;
    if (widget.borderRadius != null) {
      framed = ClipRRect(borderRadius: widget.borderRadius!, child: map);
    }
    if (widget.height != null)
      return SizedBox(height: widget.height, child: framed);
    return framed;
  }
}

/// تسخين الخريطة — widget غير مرئي يحمّل الستايل مبكراً.
class MapWarmup extends StatelessWidget {
  const MapWarmup({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(
      child: Offstage(
        child: SizedBox(width: 1, height: 1, child: _WarmupMap()),
      ),
    );
  }
}

class _WarmupMap extends StatelessWidget {
  const _WarmupMap();

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      key: const ValueKey('vibes-warmup-map'),
      styleUri: Appearance.isDark
          ? MapConstants.darkStyleUri
          : MapConstants.styleUri,
      textureView: false,
      cameraOptions: CameraOptions(
        center: Point(
          coordinates: Position(
            MapConstants.iraqCenter.lng,
            MapConstants.iraqCenter.lat,
          ),
        ),
        zoom: MapConstants.defaultZoom,
      ),
    );
  }
}
