import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
abstract final class Vibes {
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

  static const LinearGradient buttonFill = Vibes.tealFill;

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
  static const Color canvas = Vibes.canvas;
  static const Color surface = Vibes.surface;
  static const Color surfaceMuted = Vibes.surfaceMuted;
  static const Color hairline = Vibes.hairline;
  static const Color hairlineStrong = Vibes.hairlineStrong;

  static const Color ink = Vibes.ink;
  static const Color inkSecondary = Vibes.inkSecondary;
  static const Color inkTertiary = Vibes.inkTertiary;

  static const Color emerald = Vibes.coral;
  static const Color emeraldBright = Vibes.coralBright;
  static const Color emeraldMint = Vibes.coralMint;
  static const Color emeraldSoft = Vibes.coralSoft;
  static const Color onEmerald = Vibes.onCoral;

  static const Color honey = Vibes.honey;
  static const Color honeyDeep = Vibes.honeyDeep;

  static const Color success = Vibes.success;
  static const Color warning = Vibes.warning;
  static const Color danger = Vibes.danger;
  static const Color info = Vibes.info;

  static const List<BoxShadow> card = Vibes.card;
  static const List<BoxShadow> floating = Vibes.floating;

  static const LinearGradient emeraldFill = Vibes.coralFill;
}

abstract final class InkColors {
  static const Color canvas = Vibes.canvas;
  static const Color canvasHigh = Vibes.surfaceMuted;
  static const Color surface = Vibes.surface;
  static const Color surfaceHigh = Vibes.surfaceMuted;
  static const Color hairline = Vibes.hairline;
  static const Color textPrimary = Vibes.ink;
  static const Color textSecondary = Vibes.inkSecondary;
  static const Color textTertiary = Vibes.inkTertiary;
}

abstract final class PorcelainColors {
  static const Color canvas = Vibes.canvas;
  static const Color surface = Vibes.surface;
  static const Color surfaceHigh = Vibes.surfaceMuted;
  static const Color hairline = Vibes.hairline;
  static const Color textPrimary = Vibes.ink;
  static const Color textSecondary = Vibes.inkSecondary;
  static const Color textTertiary = Vibes.inkTertiary;
}

abstract final class GoldColors {
  static const Color gold = Vibes.teal;
  static const Color goldLight = Vibes.tealBright;
  static const Color goldDeep = Vibes.honeyDeep;
  static const Color goldSoft = Vibes.tealMint;
  static const Color onGold = Vibes.onTeal;
  static const LinearGradient gradient = Vibes.tealFill;
  static const LinearGradient textGradient = Vibes.tealFill;
}

abstract final class SemanticColors {
  static const Color success = Vibes.success;
  static const Color warning = Vibes.warning;
  static const Color danger = Vibes.danger;
  static const Color info = Vibes.info;
}

abstract final class VibesThemeStatic {
  static const Color muted = Vibes.inkSecondary;
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
      isDark(c) ? VibesDark.canvas : Vibes.canvas;
  static Color surfaceOf(BuildContext c) =>
      isDark(c) ? VibesDark.surface : Vibes.surface;
  static Color surfaceHighOf(BuildContext c) =>
      isDark(c) ? VibesDark.surfaceMuted : Vibes.surfaceMuted;
  static Color hairlineOf(BuildContext c) =>
      isDark(c) ? VibesDark.hairline : Vibes.hairline;
  static Color textPrimaryOf(BuildContext c) =>
      isDark(c) ? VibesDark.ink : Vibes.ink;
  static Color textSecondaryOf(BuildContext c) =>
      isDark(c) ? VibesDark.inkSecondary : Vibes.inkSecondary;
  static Color textTertiaryOf(BuildContext c) =>
      isDark(c) ? VibesDark.inkTertiary : Vibes.inkTertiary;
  static Color accentOf(BuildContext c) =>
      isDark(c) ? VibesDark.coral : Vibes.coral;

  /// لون الهوية المقروء: أزرق ملكي على الورق، أزرق فاتح على الليل.
  static Color brandOf(BuildContext c) =>
      isDark(c) ? VibesDark.coral : Vibes.coral;

  /// لون الزر الممتلئ: نحاس دائماً — لون التوقيع.
  static Color actionOf(BuildContext c) => Vibes.teal;

  static Color onActionOf(BuildContext c) =>
      isDark(c) ? VibesDark.onCoral : Vibes.onTeal;

  static Color hairlineStrongOf(BuildContext c) =>
      isDark(c) ? VibesDark.hairlineStrong : Vibes.hairlineStrong;

  static List<BoxShadow> cardOf(BuildContext c) =>
      isDark(c) ? VibesDark.card : Vibes.card;

  static List<BoxShadow> floatOf(BuildContext c) =>
      isDark(c) ? VibesDark.floating : Vibes.floating;

  static LinearGradient washOf(BuildContext c) =>
      isDark(c) ? VibesDark.nightWash : Vibes.ivoryWash;

  static LinearGradient buttonOf(BuildContext c) =>
      isDark(c) ? VibesDark.buttonFill : Vibes.tealFill;

  /// Cairo للنص العربي حتى تبقى الحروف متصلة. Montserrat احتياط للاتيني
  /// والأرقام إلى أن تُوفَّر ملفات Avenir Arabic المرخّصة.
  /// التسلسل الرسمي: عناوين Black (900) — متن Medium — ثانوي عادي.
  static TextTheme _text(TextTheme base) {
    final cairo = base.apply(fontFamily: 'Cairo');
    const fallback = <String>['Montserrat'];

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
      scaffoldBackgroundColor: Vibes.canvas,
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
        primary: Vibes.teal,
        onPrimary: Vibes.onTeal,
        secondary: Vibes.coral,
        onSecondary: Vibes.onCoral,
        surface: Vibes.surface,
        onSurface: Vibes.ink,
        surfaceContainerHighest: Vibes.surfaceMuted,
        onSurfaceVariant: Vibes.inkSecondary,
        outline: Vibes.hairline,
        error: Vibes.danger,
        tertiary: Vibes.honey,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
          color: Vibes.ink,
        ),
        iconTheme: const IconThemeData(color: Vibes.ink),
      ),
      dividerTheme: const DividerThemeData(
        color: Vibes.hairline,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Vibes.tealMint,
        height: 68,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          text.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Vibes.inkSecondary,
          ),
        ),
        iconTheme: const WidgetStatePropertyAll(
          IconThemeData(color: Vibes.inkTertiary),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Vibes.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Vibes.surface,
        showDragHandle: false,
        shape: RoundedRectangleBorder(borderRadius: VibesRadius.folioSheet),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Vibes.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: VibesRadius.folio),
        elevation: 6,
        textStyle: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: Vibes.ink,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Brand.midnight,
        contentTextStyle: text.bodyMedium?.copyWith(color: Vibes.canvas),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: VibesRadius.folio),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Vibes.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: VibesRadius.folio),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Vibes.teal,
        foregroundColor: Vibes.onTeal,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: VibesRadius.folio),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Vibes.surface,
        hintStyle: text.bodyMedium?.copyWith(color: Vibes.inkTertiary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: VibesSpacing.lg,
          vertical: 16,
        ),
        border: border(Vibes.hairlineStrong),
        enabledBorder: border(Vibes.hairlineStrong),
        focusedBorder: border(Vibes.teal, 1.4),
        errorBorder: border(Vibes.danger),
        focusedErrorBorder: border(Vibes.danger, 1.4),
        suffixIconColor: Vibes.coral,
        prefixIconColor: Vibes.inkTertiary,
        errorStyle: text.bodySmall?.copyWith(color: Vibes.danger),
        floatingLabelStyle: text.bodySmall?.copyWith(
          color: Vibes.teal,
          fontWeight: FontWeight.w800,
        ),
        labelStyle: text.labelMedium?.copyWith(
          color: Vibes.inkSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Vibes.teal,
          foregroundColor: Vibes.onTeal,
          minimumSize: const Size.fromHeight(48),
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          shape: const RoundedRectangleBorder(borderRadius: VibesRadius.folio),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Brand.midnight,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: Vibes.hairlineStrong),
          shape: const RoundedRectangleBorder(borderRadius: VibesRadius.folio),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Vibes.coral,
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Vibes.surface,
        side: const BorderSide(color: Vibes.hairlineStrong),
        labelStyle: text.labelMedium?.copyWith(color: Vibes.inkSecondary),
        shape: const RoundedRectangleBorder(borderRadius: VibesRadius.folio),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: Vibes.teal,
        unselectedLabelColor: Vibes.inkTertiary,
        indicatorColor: Vibes.teal,
        dividerColor: Vibes.hairline,
        labelStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        unselectedLabelStyle: text.titleSmall,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Vibes.teal,
        linearTrackColor: Vibes.tealMint,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? Vibes.onTeal : Vibes.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Vibes.teal
              : Vibes.hairlineStrong,
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
        primary: Vibes.teal,
        onPrimary: VibesDark.onCoral,
        secondary: VibesDark.tealBright,
        onSecondary: VibesDark.onCoral,
        surface: VibesDark.surface,
        onSurface: VibesDark.ink,
        surfaceContainerHighest: VibesDark.surfaceMuted,
        onSurfaceVariant: VibesDark.inkSecondary,
        outline: VibesDark.hairline,
        error: Vibes.danger,
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
        backgroundColor: Vibes.teal,
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
        focusedBorder: border(Vibes.teal, 1.4),
        errorBorder: border(Vibes.danger),
        focusedErrorBorder: border(Vibes.danger, 1.4),
        suffixIconColor: VibesDark.teal,
        prefixIconColor: VibesDark.inkTertiary,
        errorStyle: text.bodySmall?.copyWith(color: Vibes.danger),
        labelStyle: text.labelMedium?.copyWith(
          color: VibesDark.inkSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Vibes.teal,
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
          foregroundColor: Vibes.tealBright,
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
        indicatorColor: Vibes.teal.withValues(alpha: .22),
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
        labelColor: Vibes.tealBright,
        unselectedLabelColor: VibesDark.inkTertiary,
        indicatorColor: Vibes.teal,
        dividerColor: VibesDark.hairline,
        labelStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        unselectedLabelStyle: text.titleSmall,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Vibes.teal,
        linearTrackColor: VibesDark.surfaceMuted,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Vibes.teal,
        selectionColor: Color(0x55C89844),
        selectionHandleColor: Vibes.teal,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? VibesDark.onCoral
              : VibesDark.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Vibes.teal
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
