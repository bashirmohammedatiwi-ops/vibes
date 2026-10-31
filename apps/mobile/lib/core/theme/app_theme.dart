import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n/i18n.dart';

/// =====================================================================
/// VIBES — الهوية البصرية الرسمية (NEW VIBES VISUAL IDENTITY)
/// ─────────────────────────────────────────────────────────────────────
/// اللوحة الرسمية:
///   BRASS      #C89844  — لون التوقيع: الأزرار، التمييز، الأسعار
///   SAPPHIRE   #1B3857  — الأزرق الملكي: الروابط، الحالات النشطة
///   MIDNIGHT   #0F2138  — الليلي الفاخر: الهيرو، السبلاش، الوضع الليلي
///   DYNAMIC BK #1E1E1E  — حبر النصوص
///   MAPPLE     #ED5477  — لمسة نادرة: المفضلة والتنبيهات العاجلة
///   EMPTINESS  #F4F4F4  — أسطح صامتة
///   MILK JUG   #FAF7F0  — الخلفية الدافئة
/// الخط الرسمي: Montserrat للاتينية، Cairo بديل Avenir Arabic للعربية.
/// التسلسل: عناوين Black → متن Medium → ثانوي Light.
/// =====================================================================

/// لوحة الهوية الرسمية — أسماء الهوية نفسها
abstract final class Brand {
  static const Color brass = Color(0xFFC89844);
  static const Color brassSoft = Color(0xFFC69741);
  static const Color brassLight = Color(0xFFE0B568);
  static const Color brassPale = Color(0xFFF5EBD8);
  static const Color brassDeep = Color(0xFF8D6324);

  static const Color sapphire = Color(0xFF1B3857);
  static const Color sapphireLight = Color(0xFF315879);
  static const Color sapphirePale = Color(0xFFE5ECF3);

  static const Color midnight = Color(0xFF0F2138);
  static const Color midnightHigh = Color(0xFF162C46);

  static const Color ink = Color(0xFF1E1E1E);
  static const Color mapple = Color(0xFFED5477);
  static const Color emptiness = Color(0xFFF4F4F4);
  static const Color milkJug = Color(0xFFFAF7F0);
}

/// نظام الألوان التطبيقي — الأسماء التاريخية بقيم الهوية الرسمية.
abstract final class VibesLight {
  static const Color canvas = Color(0xFFFFFFFF); // أبيض نقي
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Brand.emptiness; // Emptiness
  static const Color hairline = Color(0xFFE3DDD1);
  static const Color hairlineStrong = Color(0xFFCFC7B8);
  static const Color champagne = Color(0xFFF3EDDF);

  static const Color ink = Brand.ink; // Dynamic Black
  static const Color inkSecondary = Color(0xFF565D68);
  static const Color inkTertiary = Color(0xFF8A9099);

  // أزرق ملكي — روابط وحالات نشطة وأسطح ثقة.
  static const Color coral = Brand.sapphire; // Sapphire
  static const Color coralBright = Brand.sapphireLight;
  static const Color coralMint = Brand.sapphirePale;
  static const Color coralSoft = Color(0x141B3857);
  static const Color onCoral = Brand.milkJug;

  // نحاس — لون التوقيع: أزرار وتمييز وأسعار.
  static const Color teal = Brand.brass; // Brass
  static const Color tealBright = Brand.brassLight;
  static const Color tealMint = Brand.brassPale;
  static const Color onTeal = Brand.midnight; // حبر ليلي فوق النحاس

  static const Color mapple = Brand.mapple;

  static const Color honey = Brand.brassSoft;
  static const Color honeyDeep = Brand.brassDeep;
  static const Color honeyMint = Brand.brassPale;

  static const Color success = Color(0xFF2E7D5B);
  static const Color warning = Color(0xFFB97E12);
  static const Color danger = Color(0xFFC2402F);
  static const Color info = Brand.sapphireLight;

  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0F0F2138), blurRadius: 20, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x060F2138), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x1A0F2138), blurRadius: 30, offset: Offset(0, 14)),
    BoxShadow(color: Color(0x0A0F2138), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static const LinearGradient coralFill = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Brand.sapphireLight, Brand.sapphire],
  );

  /// تدرج النحاس — شامبانيا إلى نحاس بلمعة حريرية.
  static const LinearGradient tealFill = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Brand.brassLight, Brand.brass],
  );

  /// تدرج ليلي فاخر — منتصف الليل إلى السبور.
  static const LinearGradient midnightFill = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Brand.midnightHigh, Brand.midnight],
  );

  static const LinearGradient ivoryWash = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
  );
}

/// المظهر الحالي — يُضبط من VibesApp قبل بناء الواجهة.
abstract final class Appearance {
  static bool isDark = false;
}

/// لونان حسب المظهر الحالي، للقيم الخاصة بشاشة واحدة.
Color themed(Color light, Color dark) => Appearance.isDark ? dark : light;

/// خط الواجهة: Cairo للعربية، Montserrat للإنجليزية حسب دليل الهوية.
abstract final class VibesFont {
  static String get ui => I18n.isEn ? 'Montserrat' : 'Cairo';
}

/// نظام الألوان التطبيقي — كل رمز يتبع المظهر الحالي تلقائياً.
abstract final class Vibes {
  static bool get _d => Appearance.isDark;

  static Color get canvas => _d ? VibesDark.canvas : VibesLight.canvas;
  static Color get surface => _d ? VibesDark.surface : VibesLight.surface;
  static Color get surfaceMuted =>
      _d ? VibesDark.surfaceMuted : VibesLight.surfaceMuted;
  static Color get hairline => _d ? VibesDark.hairline : VibesLight.hairline;
  static Color get hairlineStrong =>
      _d ? VibesDark.hairlineStrong : VibesLight.hairlineStrong;
  static Color get champagne => _d ? VibesDark.champagne : VibesLight.champagne;

  static Color get ink => _d ? VibesDark.ink : VibesLight.ink;
  static Color get inkSecondary =>
      _d ? VibesDark.inkSecondary : VibesLight.inkSecondary;
  static Color get inkTertiary =>
      _d ? VibesDark.inkTertiary : VibesLight.inkTertiary;

  static Color get coral => _d ? VibesDark.coral : VibesLight.coral;
  static Color get coralBright =>
      _d ? VibesDark.coralBright : VibesLight.coralBright;
  static Color get coralMint => _d ? VibesDark.coralMint : VibesLight.coralMint;
  static Color get coralSoft => _d ? VibesDark.coralSoft : VibesLight.coralSoft;
  static Color get onCoral => _d ? VibesDark.onCoral : VibesLight.onCoral;

  static Color get teal => _d ? VibesDark.teal : VibesLight.teal;
  static Color get tealBright =>
      _d ? VibesDark.tealBright : VibesLight.tealBright;
  static Color get tealMint => _d ? VibesDark.tealMint : VibesLight.tealMint;
  static Color get onTeal => _d ? VibesDark.onTeal : VibesLight.onTeal;

  static Color get mapple => _d ? VibesDark.mapple : VibesLight.mapple;

  static Color get honey => _d ? VibesDark.honey : VibesLight.honey;
  static Color get honeyDeep => _d ? VibesDark.honeyDeep : VibesLight.honeyDeep;
  static Color get honeyMint => _d ? VibesDark.honeyMint : VibesLight.honeyMint;

  static Color get success => _d ? VibesDark.success : VibesLight.success;
  static Color get warning => _d ? VibesDark.warning : VibesLight.warning;
  static Color get danger => _d ? VibesDark.danger : VibesLight.danger;
  static Color get info => _d ? VibesDark.info : VibesLight.info;

  static List<BoxShadow> get card => _d ? VibesDark.card : VibesLight.card;
  static List<BoxShadow> get floating =>
      _d ? VibesDark.floating : VibesLight.floating;

  static LinearGradient get coralFill =>
      _d ? VibesDark.coralFill : VibesLight.coralFill;
  static const LinearGradient tealFill = VibesLight.tealFill;
  static const LinearGradient midnightFill = VibesLight.midnightFill;
  static LinearGradient get ivoryWash =>
      _d ? VibesDark.nightWash : VibesLight.ivoryWash;
}

abstract final class VibesDark {
  static const Color canvas = Color(0xFF0A1626);
  static const Color surface = Color(0xFF11233A);
  static const Color surfaceMuted = Color(0xFF18304C);
  static const Color hairline = Color(0xFF24405F);
  static const Color hairlineStrong = Color(0xFF3A5A7D);
  static const Color champagne = Color(0xFF152A44);

  static const Color ink = Color(0xFFF6F1E6);
  static const Color inkSecondary = Color(0xFFC7D2DF);
  static const Color inkTertiary = Color(0xFF8CA0B5);

  /// نص مميز ليلاً — أزرق فاتح مقروء.
  static const Color coral = Color(0xFFD9E5F1);
  static const Color coralBright = Color(0xFF8FB4D4);
  static const Color coralMint = Color(0x332C6BAA);
  static const Color onCoral = Color(0xFF0A1626);

  static const Color teal = Brand.brassLight; // نحاس مرفوع للقراءة ليلاً
  static const Color tealBright = Color(0xFFF0D7A4);
  static const Color honey = Brand.brass;

  static const LinearGradient nightWash = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF17304E), Brand.midnight, Color(0xFF071120)],
  );

  static const LinearGradient buttonFill = VibesLight.tealFill;

  static const Color coralSoft = Color(0x268FB4D4);
  static const Color tealMint = Color(0x2EC89844);
  static const Color onTeal = Brand.midnight;
  static const Color honeyDeep = Brand.brassLight;
  static const Color honeyMint = Color(0x2EC89844);
  static const Color mapple = Color(0xFFF4789A);

  static const Color success = Color(0xFF5BC79A);
  static const Color warning = Color(0xFFE5B04F);
  static const Color danger = Color(0xFFF2786A);
  static const Color info = Color(0xFF8FB4D4);

  static const LinearGradient coralFill = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8FB4D4), Color(0xFF5E8AB0)],
  );

  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x80000000), blurRadius: 22, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x33000000), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x99000000), blurRadius: 32, offset: Offset(0, 14)),
    BoxShadow(color: Color(0x33C89844), blurRadius: 8, offset: Offset(0, 1)),
  ];
}

/// لون حسب نوع العقار — مزرعة نحاس، قاعة أزرق ملكي، التزيين نحاس فاتح.
abstract final class TypeColors {
  static Color of(String type) {
    return switch (type.toUpperCase()) {
      'FARM' => Vibes.teal,
      'HALL' => Vibes.coral,
      _ => Vibes.honey,
    };
  }

  static Color mintOf(String type) {
    return switch (type.toUpperCase()) {
      'FARM' => Vibes.tealMint,
      'HALL' => Vibes.coralMint,
      _ => Vibes.honeyMint,
    };
  }
}

/// توافق الكود القديم — يشير إلى الهوية الجديدة
abstract final class Atelier {
  static Color get canvas => Vibes.canvas;
  static Color get surface => Vibes.surface;
  static Color get surfaceMuted => Vibes.surfaceMuted;
  static Color get hairline => Vibes.hairline;
  static Color get hairlineStrong => Vibes.hairlineStrong;

  static Color get ink => Vibes.ink;
  static Color get inkSecondary => Vibes.inkSecondary;
  static Color get inkTertiary => Vibes.inkTertiary;

  static Color get emerald => Vibes.coral;
  static Color get emeraldBright => Vibes.coralBright;
  static Color get emeraldMint => Vibes.coralMint;
  static Color get emeraldSoft => Vibes.coralSoft;
  static Color get onEmerald => Vibes.onCoral;

  static Color get honey => Vibes.honey;
  static Color get honeyDeep => Vibes.honeyDeep;

  static Color get success => Vibes.success;
  static Color get warning => Vibes.warning;
  static Color get danger => Vibes.danger;
  static Color get info => Vibes.info;

  static List<BoxShadow> get card => Vibes.card;
  static List<BoxShadow> get floating => Vibes.floating;

  static LinearGradient get emeraldFill => Vibes.coralFill;
}

abstract final class InkColors {
  static Color get canvas => Vibes.canvas;
  static Color get canvasHigh => Vibes.surfaceMuted;
  static Color get surface => Vibes.surface;
  static Color get surfaceHigh => Vibes.surfaceMuted;
  static Color get hairline => Vibes.hairline;
  static Color get textPrimary => Vibes.ink;
  static Color get textSecondary => Vibes.inkSecondary;
  static Color get textTertiary => Vibes.inkTertiary;
}

abstract final class PorcelainColors {
  static Color get canvas => Vibes.canvas;
  static Color get surface => Vibes.surface;
  static Color get surfaceHigh => Vibes.surfaceMuted;
  static Color get hairline => Vibes.hairline;
  static Color get textPrimary => Vibes.ink;
  static Color get textSecondary => Vibes.inkSecondary;
  static Color get textTertiary => Vibes.inkTertiary;
}

abstract final class GoldColors {
  static Color get gold => Vibes.teal;
  static Color get goldLight => Vibes.tealBright;
  static Color get goldDeep => Vibes.honeyDeep;
  static Color get goldSoft => Vibes.tealMint;
  static Color get onGold => Vibes.onTeal;
  static LinearGradient get gradient => Vibes.tealFill;
  static LinearGradient get textGradient => Vibes.tealFill;
}

abstract final class SemanticColors {
  static Color get success => Vibes.success;
  static Color get warning => Vibes.warning;
  static Color get danger => Vibes.danger;
  static Color get info => Vibes.info;
}

abstract final class VibesThemeStatic {
  static Color get muted => Vibes.inkSecondary;
}

abstract final class VibesSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

abstract final class VibesRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 18;
  static const double xl = 24;
  static const double xxl = 28;
  static const double pill = 999;

  /// قص موحّد — 12 للأسطح و8 للشارات، بلا زوايا معمارية غير متساوية.
  static const BorderRadius folio = BorderRadius.all(Radius.circular(12));

  static const BorderRadius folioCompact = BorderRadius.all(Radius.circular(8));

  static const RoundedRectangleBorder folioShape = RoundedRectangleBorder(
    borderRadius: folio,
  );

  static const BorderRadius folioSheet = BorderRadius.vertical(
    top: Radius.circular(16),
  );

  static RoundedRectangleBorder card([double r = 12]) =>
      const RoundedRectangleBorder(borderRadius: folio);
}

abstract final class VibesMotion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 380);
  static const Curve curve = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Duration stagger = Duration(milliseconds: 40);
}

/// انتقال صفحات الهوية — عمق ثلاثي الطبقات بتحويلات فقط (60fps):
/// الصفحة الداخلة تصعد بمنحنى emphasized، والخارجة تتلاشى وتتراجع
/// قليلاً للوراء — إحساس تكدس ورقي حقيقي بدل انزلاق مسطح.
class VibesPageTransition extends PageTransitionsBuilder {
  const VibesPageTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // الدخول: صعود ناعم بتسارع مركّز — أرقى منحنيات Material.
    final curvedIn = CurvedAnimation(
      parent: animation,
      curve: VibesMotion.emphasized,
      reverseCurve: Curves.easeInCubic,
    );

    // الخروج (عندما تدخل صفحة فوقها): تراجع خفيف وتلاشٍ.
    final curvedOut = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: curvedIn,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.030),
          end: Offset.zero,
        ).animate(curvedIn),
        child: SlideTransition(
          position: Tween(
            begin: Offset.zero,
            end: const Offset(0, -0.024),
          ).animate(curvedOut),
          child: FadeTransition(
            opacity: Tween(begin: 1.0, end: 0.55).animate(curvedOut),
            child: child,
          ),
        ),
      ),
    );
  }
}

class VibesTheme {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color canvasOf(BuildContext c) =>
      isDark(c) ? VibesDark.canvas : VibesLight.canvas;
  static Color surfaceOf(BuildContext c) =>
      isDark(c) ? VibesDark.surface : VibesLight.surface;
  static Color surfaceHighOf(BuildContext c) =>
      isDark(c) ? VibesDark.surfaceMuted : VibesLight.surfaceMuted;
  static Color hairlineOf(BuildContext c) =>
      isDark(c) ? VibesDark.hairline : VibesLight.hairline;
  static Color textPrimaryOf(BuildContext c) =>
      isDark(c) ? VibesDark.ink : VibesLight.ink;
  static Color textSecondaryOf(BuildContext c) =>
      isDark(c) ? VibesDark.inkSecondary : VibesLight.inkSecondary;
  static Color textTertiaryOf(BuildContext c) =>
      isDark(c) ? VibesDark.inkTertiary : VibesLight.inkTertiary;
  static Color accentOf(BuildContext c) =>
      isDark(c) ? VibesDark.coral : VibesLight.coral;

  /// لون الهوية المقروء: أزرق ملكي على الورق، أزرق فاتح على الليل.
  static Color brandOf(BuildContext c) =>
      isDark(c) ? VibesDark.coral : VibesLight.coral;

  /// لون الزر الممتلئ: نحاس دائماً — لون التوقيع.
  static Color actionOf(BuildContext c) => VibesLight.teal;

  static Color onActionOf(BuildContext c) =>
      isDark(c) ? VibesDark.onCoral : VibesLight.onTeal;

  static Color hairlineStrongOf(BuildContext c) =>
      isDark(c) ? VibesDark.hairlineStrong : VibesLight.hairlineStrong;

  static List<BoxShadow> cardOf(BuildContext c) =>
      isDark(c) ? VibesDark.card : VibesLight.card;

  static List<BoxShadow> floatOf(BuildContext c) =>
      isDark(c) ? VibesDark.floating : VibesLight.floating;

  static LinearGradient washOf(BuildContext c) =>
      isDark(c) ? VibesDark.nightWash : VibesLight.ivoryWash;

  static LinearGradient buttonOf(BuildContext c) =>
      isDark(c) ? VibesDark.buttonFill : VibesLight.tealFill;

  /// Cairo للنص العربي حتى تبقى الحروف متصلة. Montserrat احتياط للاتيني
  /// والأرقام إلى أن تُوفَّر ملفات Avenir Arabic المرخّصة.
  /// التسلسل الرسمي: عناوين Black (900) — متن Medium — ثانوي عادي.
  static TextTheme _text(TextTheme base) {
    final cairo = base.apply(fontFamily: VibesFont.ui);
    final fallback = <String>[I18n.isEn ? 'Cairo' : 'Montserrat'];

    TextStyle? face(
      TextStyle? style, {
      FontWeight? weight,
      double? height,
      double? letterSpacing,
    }) {
      return style?.copyWith(
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
        fontFamilyFallback: fallback,
      );
    }

    return cairo.copyWith(
      displayLarge: face(
        cairo.displayLarge,
        weight: FontWeight.w900,
        height: 1.1,
      ),
      displayMedium: face(
        cairo.displayMedium,
        weight: FontWeight.w900,
        height: 1.12,
      ),
      displaySmall: face(
        cairo.displaySmall,
        weight: FontWeight.w900,
        height: 1.15,
      ),
      headlineMedium: face(
        cairo.headlineMedium,
        weight: FontWeight.w900,
        height: 1.2,
      ),
      headlineSmall: face(
        cairo.headlineSmall,
        weight: FontWeight.w900,
        height: 1.25,
      ),
      titleLarge: face(cairo.titleLarge, weight: FontWeight.w800, height: 1.25),
      titleMedium: face(
        cairo.titleMedium,
        weight: FontWeight.w700,
        height: 1.4,
      ),
      titleSmall: face(cairo.titleSmall, weight: FontWeight.w700, height: 1.4),
      bodyLarge: face(cairo.bodyLarge, weight: FontWeight.w500, height: 1.6),
      bodyMedium: face(cairo.bodyMedium, weight: FontWeight.w500, height: 1.65),
      bodySmall: face(cairo.bodySmall, weight: FontWeight.w500, height: 1.55),
      labelLarge: face(cairo.labelLarge, weight: FontWeight.w700),
      labelMedium: face(cairo.labelMedium, weight: FontWeight.w700),
      labelSmall: face(cairo.labelSmall, weight: FontWeight.w700),
    );
  }

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final text = _text(base.textTheme);

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: VibesRadius.folio,
      borderSide: BorderSide(color: c, width: w),
    );

    return base.copyWith(
      scaffoldBackgroundColor: VibesLight.canvas,
      textTheme: text,
      primaryTextTheme: text,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: VibesPageTransition(),
          TargetPlatform.iOS: VibesPageTransition(),
          TargetPlatform.macOS: VibesPageTransition(),
          TargetPlatform.windows: VibesPageTransition(),
          TargetPlatform.linux: VibesPageTransition(),
        },
      ),
      colorScheme: const ColorScheme.light(
        primary: VibesLight.teal,
        onPrimary: VibesLight.onTeal,
        secondary: VibesLight.coral,
        onSecondary: VibesLight.onCoral,
        surface: VibesLight.surface,
        onSurface: VibesLight.ink,
        surfaceContainerHighest: VibesLight.surfaceMuted,
        onSurfaceVariant: VibesLight.inkSecondary,
        outline: VibesLight.hairline,
        error: VibesLight.danger,
        tertiary: VibesLight.honey,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
          color: VibesLight.ink,
        ),
        iconTheme: const IconThemeData(color: VibesLight.ink),
      ),
      dividerTheme: const DividerThemeData(
        color: VibesLight.hairline,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: VibesLight.tealMint,
        height: 68,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          text.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: VibesLight.inkSecondary,
          ),
        ),
        iconTheme: const WidgetStatePropertyAll(
          IconThemeData(color: VibesLight.inkTertiary),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: VibesLight.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: VibesLight.surface,
        showDragHandle: false,
        shape: RoundedRectangleBorder(borderRadius: VibesRadius.folioSheet),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: VibesLight.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: VibesRadius.folio),
        elevation: 6,
        textStyle: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: VibesLight.ink,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Brand.midnight,
        contentTextStyle: text.bodyMedium?.copyWith(color: VibesLight.canvas),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: VibesRadius.folio),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: VibesLight.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: VibesRadius.folio),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: VibesLight.teal,
        foregroundColor: VibesLight.onTeal,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: VibesRadius.folio),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VibesLight.surface,
        hintStyle: text.bodyMedium?.copyWith(color: VibesLight.inkTertiary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: VibesSpacing.lg,
          vertical: 16,
        ),
        border: border(VibesLight.hairlineStrong),
        enabledBorder: border(VibesLight.hairlineStrong),
        focusedBorder: border(VibesLight.teal, 1.4),
        errorBorder: border(VibesLight.danger),
        focusedErrorBorder: border(VibesLight.danger, 1.4),
        suffixIconColor: VibesLight.coral,
        prefixIconColor: VibesLight.inkTertiary,
        errorStyle: text.bodySmall?.copyWith(color: VibesLight.danger),
        floatingLabelStyle: text.bodySmall?.copyWith(
          color: VibesLight.teal,
          fontWeight: FontWeight.w800,
        ),
        labelStyle: text.labelMedium?.copyWith(
          color: VibesLight.inkSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: VibesLight.teal,
          foregroundColor: VibesLight.onTeal,
          minimumSize: const Size.fromHeight(48),
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          shape: const RoundedRectangleBorder(borderRadius: VibesRadius.folio),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Brand.midnight,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: VibesLight.hairlineStrong),
          shape: const RoundedRectangleBorder(borderRadius: VibesRadius.folio),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: VibesLight.coral,
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: VibesLight.surface,
        side: const BorderSide(color: VibesLight.hairlineStrong),
        labelStyle: text.labelMedium?.copyWith(color: VibesLight.inkSecondary),
        shape: const RoundedRectangleBorder(borderRadius: VibesRadius.folio),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: VibesLight.teal,
        unselectedLabelColor: VibesLight.inkTertiary,
        indicatorColor: VibesLight.teal,
        dividerColor: VibesLight.hairline,
        labelStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        unselectedLabelStyle: text.titleSmall,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: VibesLight.teal,
        linearTrackColor: VibesLight.tealMint,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? VibesLight.onTeal : VibesLight.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? VibesLight.teal
              : VibesLight.hairlineStrong,
        ),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final text = _text(base.textTheme);

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: VibesRadius.folio,
      borderSide: BorderSide(color: c, width: w),
    );

    return base.copyWith(
      scaffoldBackgroundColor: VibesDark.canvas,
      textTheme: text,
      primaryTextTheme: text,
      iconTheme: const IconThemeData(color: VibesDark.ink),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: VibesPageTransition(),
          TargetPlatform.iOS: VibesPageTransition(),
          TargetPlatform.macOS: VibesPageTransition(),
          TargetPlatform.windows: VibesPageTransition(),
          TargetPlatform.linux: VibesPageTransition(),
        },
      ),
      colorScheme: const ColorScheme.dark(
        primary: VibesLight.teal,
        onPrimary: VibesDark.onCoral,
        secondary: VibesDark.tealBright,
        onSecondary: VibesDark.onCoral,
        surface: VibesDark.surface,
        onSurface: VibesDark.ink,
        surfaceContainerHighest: VibesDark.surfaceMuted,
        onSurfaceVariant: VibesDark.inkSecondary,
        outline: VibesDark.hairline,
        error: VibesLight.danger,
        tertiary: VibesDark.honey,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: VibesDark.canvas,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
          color: VibesDark.ink,
        ),
        iconTheme: const IconThemeData(color: VibesDark.ink),
      ),
      dividerTheme: const DividerThemeData(
        color: VibesDark.hairline,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: VibesDark.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: VibesDark.surface,
        showDragHandle: false,
        shape: RoundedRectangleBorder(borderRadius: VibesRadius.folioSheet),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: VibesDark.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: VibesRadius.folio),
        elevation: 6,
        textStyle: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: VibesDark.ink,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: VibesDark.surfaceMuted,
        contentTextStyle: text.bodyMedium?.copyWith(color: VibesDark.ink),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: VibesRadius.folio),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: VibesDark.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: VibesRadius.folio),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: VibesLight.teal,
        foregroundColor: VibesDark.onCoral,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: VibesRadius.folio),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VibesDark.surfaceMuted,
        hintStyle: text.bodyMedium?.copyWith(color: VibesDark.inkTertiary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: border(VibesDark.hairlineStrong),
        enabledBorder: border(VibesDark.hairlineStrong),
        focusedBorder: border(VibesLight.teal, 1.4),
        errorBorder: border(VibesLight.danger),
        focusedErrorBorder: border(VibesLight.danger, 1.4),
        suffixIconColor: VibesDark.teal,
        prefixIconColor: VibesDark.inkTertiary,
        errorStyle: text.bodySmall?.copyWith(color: VibesLight.danger),
        labelStyle: text.labelMedium?.copyWith(
          color: VibesDark.inkSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: VibesLight.teal,
          foregroundColor: VibesDark.onCoral,
          minimumSize: const Size.fromHeight(48),
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          shape: const RoundedRectangleBorder(borderRadius: VibesRadius.folio),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: VibesDark.ink,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: VibesDark.hairlineStrong),
          shape: const RoundedRectangleBorder(borderRadius: VibesRadius.folio),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: VibesLight.tealBright,
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: VibesDark.surface,
        side: const BorderSide(color: VibesDark.hairlineStrong),
        labelStyle: text.labelMedium?.copyWith(color: VibesDark.inkSecondary),
        shape: const RoundedRectangleBorder(borderRadius: VibesRadius.folio),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: VibesDark.canvas,
        surfaceTintColor: Colors.transparent,
        indicatorColor: VibesLight.teal.withValues(alpha: .22),
        height: 68,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          text.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: VibesDark.inkSecondary,
          ),
        ),
        iconTheme: const WidgetStatePropertyAll(
          IconThemeData(color: VibesDark.inkTertiary),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: VibesLight.tealBright,
        unselectedLabelColor: VibesDark.inkTertiary,
        indicatorColor: VibesLight.teal,
        dividerColor: VibesDark.hairline,
        labelStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        unselectedLabelStyle: text.titleSmall,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: VibesLight.teal,
        linearTrackColor: VibesDark.surfaceMuted,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: VibesLight.teal,
        selectionColor: Color(0x55C89844),
        selectionHandleColor: VibesLight.teal,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? VibesDark.onCoral
              : VibesDark.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? VibesLight.teal
              : VibesDark.hairlineStrong,
        ),
      ),
    );
  }
}

extension VibesTextX on BuildContext {
  Color get vibesCanvas => VibesTheme.canvasOf(this);
  Color get vibesSurface => VibesTheme.surfaceOf(this);
  Color get vibesText => VibesTheme.textPrimaryOf(this);
  Color get vibesText2 => VibesTheme.textSecondaryOf(this);
  Color get vibesText3 => VibesTheme.textTertiaryOf(this);
  Color get vibesHairline => VibesTheme.hairlineOf(this);
}
