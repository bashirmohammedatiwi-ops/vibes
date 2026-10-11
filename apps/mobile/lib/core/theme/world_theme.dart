import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/home/home_sections.dart';
import 'app_theme.dart';

/// ═══════════════════════════════════════════════════════════
/// نظام العوالم — كل عالم جوّ كامل لا لونٌ واحد:
///   المزارع  → النحاس على كريم دافئ   (الضيافة · الشمس · الأرض)
///   القاعات  → الياقوت على عاج بارد   (الليلة الكبيرة · الفخامة)
///   التزيين  → الوردي على بلاش ناعم   (الفرح · الورد · البهجة)
/// اللوحة تُغذّي ThemeData كاملاً (أزرار، شرائح، حقول، مؤشرات،
/// تبويبات، مفاتيح، دوك) فيتبدّل التطبيق كله عند تبديل العالم.
/// ═══════════════════════════════════════════════════════════

class WorldPalette {
  const WorldPalette({
    required this.world,
    required this.accent,
    required this.accentDeep,
    required this.accentLight,
    required this.onAccent,
    required this.canvas,
    required this.canvasTint,
    required this.night,
    required this.nightHigh,
    required this.glow,
    required this.mood,
    required this.verb,
  });

  final HomeSection world;

  /// اللون التوقيعي — الأزرار والتمييز.
  final Color accent;

  /// النسخة العميقة — نصوص مميزة فوق الفاتح.
  final Color accentDeep;

  /// النسخة الفاتحة — تدرجات ولمعات.
  final Color accentLight;

  /// النص فوق اللون الممتلئ.
  final Color onAccent;

  /// خلفية الشاشة الفاتحة — تميل بلطف لجوّ العالم.
  final Color canvas;

  /// صبغة أقوى قليلاً للأقسام والبطاقات الهادئة.
  final Color canvasTint;

  /// الليل الغامر — للهيرو والسبلاش والترحيب.
  final Color night;
  final Color nightHigh;

  /// لون التوهّج — ظلال وهالات.
  final Color glow;

  /// جملة الجوّ — تُستخدم في الترحيب والهيرو.
  final String mood;

  /// فعل الدعوة — «احجز مزرعتك» ...
  final String verb;

  Color get accentSoft => accent.withValues(alpha: .12);
  Color get accentFaint => accent.withValues(alpha: .07);

  /// تدرج الزر والعناصر الممتلئة.
  LinearGradient get fill => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentLight, accent],
  );

  /// تدرج الجوّ الفاتح — يُفرش خلف الرئيسية.
  LinearGradient get atmosphere => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0, .45, 1],
    colors: [canvasTint, canvas, Colors.white],
  );

  /// تدرج الليل الغامر.
  LinearGradient get nightfall => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [nightHigh, night],
  );

  List<BoxShadow> get glowShadow => [
    BoxShadow(
      color: glow.withValues(alpha: .28),
      blurRadius: 28,
      offset: const Offset(0, 12),
    ),
  ];

  static const farm = WorldPalette(
    world: HomeSection.farm,
    accent: Color(0xFFC89844),
    accentDeep: Color(0xFF8D6324),
    accentLight: Color(0xFFE0B568),
    onAccent: Color(0xFF0F2138),
    canvas: Color(0xFFFFFDFA),
    canvasTint: Color(0xFFFAF2E4),
    night: Color(0xFF2A1F0E),
    nightHigh: Color(0xFF4A3718),
    glow: Color(0xFFC89844),
    mood: 'ضيافة الأرض والشمس',
    verb: 'احجز مزرعتك',
  );

  static const hall = WorldPalette(
    world: HomeSection.hall,
    accent: Color(0xFF1B3857),
    accentDeep: Color(0xFF0F2138),
    accentLight: Color(0xFF315879),
    onAccent: Color(0xFFFAF7F0),
    canvas: Color(0xFFFCFDFE),
    canvasTint: Color(0xFFEEF3F8),
    night: Color(0xFF0F2138),
    nightHigh: Color(0xFF1B3857),
    glow: Color(0xFF315879),
    mood: 'ليلة العمر تستحق قاعة',
    verb: 'احجز قاعتك',
  );

  static const decoration = WorldPalette(
    world: HomeSection.decoration,
    accent: Color(0xFFED5477),
    accentDeep: Color(0xFFC93A5C),
    accentLight: Color(0xFFF58AA3),
    onAccent: Color(0xFFFFFFFF),
    canvas: Color(0xFFFFFCFC),
    canvasTint: Color(0xFFFCEEF2),
    night: Color(0xFF3A1020),
    nightHigh: Color(0xFF6A1F3A),
    glow: Color(0xFFED5477),
    mood: 'تفاصيل تصنع الفرح',
    verb: 'زيّن مناسبتك',
  );

  /// بوابة المالك — هوية تنفيذية: كحلي عميق وذهب، مستقلة عن عوالم الضيف.
  static const owner = WorldPalette(
    world: HomeSection.hall,
    accent: Color(0xFFC89844),
    accentDeep: Color(0xFF8D6324),
    accentLight: Color(0xFFE0B568),
    onAccent: Color(0xFF0F2138),
    canvas: Color(0xFFFBFCFD),
    canvasTint: Color(0xFFEEF2F7),
    night: Color(0xFF0B1A2E),
    nightHigh: Color(0xFF1B3857),
    glow: Color(0xFFC89844),
    mood: 'إدارة أماكنك بثقة',
    verb: 'أدِر أماكنك',
  );

  static WorldPalette of(HomeSection world) => switch (world) {
    HomeSection.farm => farm,
    HomeSection.hall => hall,
    HomeSection.decoration => decoration,
  };

  static WorldPalette forType(String? type) => of(sectionForType(type));

  /// مزج بين لوحتين — للانتقالات اليدوية.
  static WorldPalette lerp(WorldPalette a, WorldPalette b, double t) {
    if (t <= 0) return a;
    if (t >= 1) return b;
    Color c(Color x, Color y) => Color.lerp(x, y, t)!;
    return WorldPalette(
      world: t < .5 ? a.world : b.world,
      accent: c(a.accent, b.accent),
      accentDeep: c(a.accentDeep, b.accentDeep),
      accentLight: c(a.accentLight, b.accentLight),
      onAccent: c(a.onAccent, b.onAccent),
      canvas: c(a.canvas, b.canvas),
      canvasTint: c(a.canvasTint, b.canvasTint),
      night: c(a.night, b.night),
      nightHigh: c(a.nightHigh, b.nightHigh),
      glow: c(a.glow, b.glow),
      mood: t < .5 ? a.mood : b.mood,
      verb: t < .5 ? a.verb : b.verb,
    );
  }
}

extension HomeSectionPalette on HomeSection {
  WorldPalette get palette => WorldPalette.of(this);
}

/// امتداد الثيم — يحمل لوحة العالم داخل ThemeData فتقرأها أي ودجت.
class WorldThemeExtension extends ThemeExtension<WorldThemeExtension> {
  const WorldThemeExtension(this.palette);

  final WorldPalette palette;

  @override
  WorldThemeExtension copyWith({WorldPalette? palette}) =>
      WorldThemeExtension(palette ?? this.palette);

  @override
  WorldThemeExtension lerp(
    ThemeExtension<WorldThemeExtension>? other,
    double t,
  ) {
    if (other is! WorldThemeExtension) return this;
    return WorldThemeExtension(WorldPalette.lerp(palette, other.palette, t));
  }
}

extension WorldContextX on BuildContext {
  /// لوحة العالم الحالية — من الثيم المتحرك، فتتبع الانتقال بسلاسة.
  WorldPalette get world =>
      Theme.of(this).extension<WorldThemeExtension>()?.palette ??
      WorldPalette.farm;
}

/// يطبع لوحة العالم على ThemeData الأساسي — كل مكوّن Material يلتقط اللون.
ThemeData applyWorld(ThemeData base, WorldPalette p) {
  final dark = base.brightness == Brightness.dark;
  final text = base.textTheme;
  final accent = dark ? p.accentLight : p.accent;
  final deep = dark ? p.accentLight : p.accentDeep;
  final onAccent = dark ? p.night : p.onAccent;

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: VibesRadius.folio,
    borderSide: BorderSide(color: c, width: w),
  );

  return base.copyWith(
    scaffoldBackgroundColor: dark ? VibesDark.canvas : p.canvas,
    extensions: [...base.extensions.values, WorldThemeExtension(p)],
    colorScheme: base.colorScheme.copyWith(
      primary: accent,
      onPrimary: onAccent,
      secondary: deep,
      onSecondary: dark ? p.night : Colors.white,
      tertiary: p.accentLight,
      primaryContainer: p.accentSoft,
      onPrimaryContainer: deep,
    ),
    primaryColor: accent,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: onAccent,
        disabledBackgroundColor: accent.withValues(alpha: .38),
        disabledForegroundColor: onAccent.withValues(alpha: .7),
        minimumSize: const Size.fromHeight(52),
        textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        shape: const RoundedRectangleBorder(borderRadius: VibesRadius.folio),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: deep,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: accent.withValues(alpha: .45)),
        textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        shape: const RoundedRectangleBorder(borderRadius: VibesRadius.folio),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: deep,
        textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: dark ? VibesDark.ink : Vibes.ink,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accent,
      foregroundColor: onAccent,
      elevation: 6,
      shape: const RoundedRectangleBorder(borderRadius: VibesRadius.folio),
    ),
    chipTheme: base.chipTheme.copyWith(
      selectedColor: accent,
      secondarySelectedColor: accent,
      checkmarkColor: onAccent,
      secondaryLabelStyle: text.labelMedium?.copyWith(color: onAccent),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: accent,
      linearTrackColor: p.accentSoft,
      circularTrackColor: Colors.transparent,
    ),
    tabBarTheme: base.tabBarTheme.copyWith(
      labelColor: deep,
      indicatorColor: accent,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: accent,
      inactiveTrackColor: p.accentSoft,
      thumbColor: accent,
      overlayColor: p.accentSoft,
      valueIndicatorColor: deep,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? onAccent : Colors.white,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? accent
            : (dark ? VibesDark.hairlineStrong : Vibes.hairlineStrong),
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? accent : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(onAccent),
      side: BorderSide(color: accent.withValues(alpha: .6), width: 1.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    radioTheme: RadioThemeData(fillColor: WidgetStatePropertyAll(accent)),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      focusedBorder: border(accent, 1.5),
      focusColor: accent,
      floatingLabelStyle: text.bodySmall?.copyWith(
        color: deep,
        fontWeight: FontWeight.w800,
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: accent,
      selectionColor: accent.withValues(alpha: .28),
      selectionHandleColor: accent,
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      indicatorColor: p.accentSoft,
    ),
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      dragHandleColor: accent.withValues(alpha: .4),
    ),
    dividerColor: dark ? VibesDark.hairline : Vibes.hairline,
    splashColor: accent.withValues(alpha: .10),
    highlightColor: accent.withValues(alpha: .06),
  );
}

/// جوّ العالم — خلفية متدرجة ناعمة مع هالتين ضوئيتين تتنفسان
/// ببطء، تتبدّل ألوانها مع تبديل العالم بلا قطع.
class WorldAtmosphere extends StatefulWidget {
  const WorldAtmosphere({
    super.key,
    required this.palette,
    this.child,
    this.intensity = 1,
    this.night = false,
  });

  final WorldPalette palette;
  final Widget? child;

  /// 0..1 — شدّة الهالات.
  final double intensity;

  /// الوضع الليلي الغامر (سبلاش/ترحيب).
  final bool night;

  @override
  State<WorldAtmosphere> createState() => _WorldAtmosphereState();
}

class _WorldAtmosphereState extends State<WorldAtmosphere>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final gradient = widget.night ? p.nightfall : p.atmosphere;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(gradient: gradient),
      // passthrough: يملأ الشاشة إن كانت القيود محدودة، ويأخذ حجم
      // محتواه داخل عمود غير محدود الارتفاع (رأس الصفحات) بلا انهيار.
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _breath,
                builder: (context, _) {
                  final t = reduce ? .5 : _breath.value;
                  return CustomPaint(
                    painter: _AtmospherePainter(
                      color: widget.night ? p.accentLight : p.accent,
                      secondary: widget.night ? p.accent : p.accentLight,
                      t: t,
                      intensity: widget.intensity * (widget.night ? 1.4 : 1),
                    ),
                  );
                },
              ),
            ),
          ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _AtmospherePainter extends CustomPainter {
  _AtmospherePainter({
    required this.color,
    required this.secondary,
    required this.t,
    required this.intensity,
  });

  final Color color;
  final Color secondary;
  final double t;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final a = (0.10 * intensity).clamp(0.0, 0.6);
    final b = (0.07 * intensity).clamp(0.0, 0.5);

    final c1 = Offset(
      size.width * (0.85 - t * 0.12),
      size.height * (0.08 + t * 0.05),
    );
    final r1 = size.width * (0.55 + t * 0.08);
    canvas.drawCircle(
      c1,
      r1,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: a),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c1, radius: r1)),
    );

    final c2 = Offset(
      size.width * (0.10 + t * 0.10),
      size.height * (0.55 - t * 0.08),
    );
    final r2 = size.width * (0.5 + (1 - t) * 0.1);
    canvas.drawCircle(
      c2,
      r2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            secondary.withValues(alpha: b),
            secondary.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c2, radius: r2)),
    );
  }

  @override
  bool shouldRepaint(_AtmospherePainter old) =>
      old.t != t ||
      old.color != color ||
      old.secondary != secondary ||
      old.intensity != intensity;
}

/// نبضة لمسية موحّدة عند تبديل العالم.
void worldSwitchHaptic() => HapticFeedback.mediumImpact();

/// نمط شريط الحالة المناسب للخلفية.
SystemUiOverlayStyle overlayFor({required bool darkBackground}) =>
    darkBackground
    ? const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      )
    : const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      );
