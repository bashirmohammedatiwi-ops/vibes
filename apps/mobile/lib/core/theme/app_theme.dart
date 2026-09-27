import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// =============================================================
/// VIBES — الهوية الرسمية
/// Sapphire وMidnight وBrass، مع لغة تحريرية مستلهمة من رمز V + S.
/// =============================================================

abstract final class Vibes {
  static const Color canvas = Color(0xFFFAF7F0); // Milk Jug
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF4F4F4); // Emptiness
  static const Color hairline = Color(0xFFD9DDE1);
  static const Color hairlineStrong = Color(0xFFBFC6CE);
  static const Color champagne = Color(0xFFF1ECE2);

  static const Color ink = Color(0xFF1E1E1E); // Dynamic Black
  static const Color inkSecondary = Color(0xFF4B5563);
  static const Color inkTertiary = Color(0xFF7B8490);

  // حافظنا على الأسماء القديمة لتجنب كسر الشاشات، لكن قيمها هي الهوية الرسمية.
  static const Color coral = Color(0xFF1B3857); // Sapphire
  static const Color coralBright = Color(0xFF315879);
  static const Color coralMint = Color(0xFFE5ECF3);
  static const Color coralSoft = Color(0x141B3857);
  static const Color onCoral = Color(0xFFFAF7F0);

  static const Color teal = Color(0xFFC89844); // Brass
  static const Color tealBright = Color(0xFFE0B568);
  static const Color tealMint = Color(0xFFF5EBD8);
  static const Color onTeal = Color(0xFFFFFFFF);
  static const Color mapple = Color(0xFFED5477);

  static const Color honey = Color(0xFFC69741);
  static const Color honeyDeep = Color(0xFF8D6324);
  static const Color honeyMint = Color(0xFFF5EBD8);

  static const Color success = Color(0xFF0D9488);
  static const Color warning = Color(0xFFE8A317);
  static const Color danger = Color(0xFFD6453D);
  static const Color info = Color(0xFF2C6BAA);

  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x121B3857), blurRadius: 24, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x071B3857), blurRadius: 3, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x211B3857), blurRadius: 28, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x0D1B3857), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static const LinearGradient coralFill = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF315879), coral],
  );
  static const LinearGradient tealFill = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE0B568), teal],
  );
  static const LinearGradient ivoryWash = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFFFFFFFF), canvas, Color(0xFFF3F0E9)],
  );
}

abstract final class VibesDark {
  static const Color canvas = Color(0xFF0B1828);
  static const Color surface = Color(0xFF13263C);
  static const Color surfaceMuted = Color(0xFF1A314C);
  static const Color hairline = Color(0xFF2A4460);
  static const Color hairlineStrong = Color(0xFF3E5C78);
  static const Color champagne = Color(0xFF16283E);

  static const Color ink = Color(0xFFF6F1E6);
  static const Color inkSecondary = Color(0xFFC9D4E0);
  static const Color inkTertiary = Color(0xFF8FA0B3);

  /// ياقوت مرفوع للقراءة على منتصف الليل — ليس لون الأزرار.
  static const Color coral = Color(0xFFD5E3F0);
  static const Color coralBright = Color(0xFF8FB4D4);
  static const Color coralMint = Color(0x332C6BAA);
  static const Color onCoral = Color(0xFF0B1828);

  static const Color teal = Color(0xFFE0B568);
  static const Color tealBright = Color(0xFFF0D7A4);
  static const Color honey = Color(0xFFC89844);

  static const LinearGradient nightWash = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF1A3350), Color(0xFF0F2138), Color(0xFF081422)],
  );

  static const LinearGradient buttonFill = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8C98A), Color(0xFFC89844)],
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
  static const Color gold = Vibes.coral;
  static const Color goldLight = Vibes.coralBright;
  static const Color goldDeep = Vibes.coral;
  static const Color goldSoft = Vibes.coralSoft;
  static const Color onGold = Vibes.onCoral;
  static const LinearGradient gradient = Vibes.coralFill;
  static const LinearGradient textGradient = Vibes.coralFill;
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

  /// إطار Folio الموحّد — قطع معماري خفيف بلا كبسولات
  static const BorderRadius folio = BorderRadius.only(
    topLeft: Radius.circular(8),
    topRight: Radius.circular(12),
    bottomRight: Radius.circular(8),
    bottomLeft: Radius.circular(10),
  );

  static const BorderRadius folioCompact = BorderRadius.only(
    topLeft: Radius.circular(5),
    topRight: Radius.circular(8),
    bottomRight: Radius.circular(5),
    bottomLeft: Radius.circular(7),
  );

  static const RoundedRectangleBorder folioShape = RoundedRectangleBorder(
    borderRadius: folio,
  );

  static const BorderRadius folioSheet = BorderRadius.only(
    topLeft: Radius.circular(8),
    topRight: Radius.circular(12),
  );

  /// مستطيل معماري — زاوية علوية يمنى أحدّ من الباقي
  static RoundedRectangleBorder card([double r = 18]) =>
      const RoundedRectangleBorder(borderRadius: folio);
}

abstract final class VibesMotion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 380);
  static const Curve curve = Curves.easeOutCubic;
  static const Duration stagger = Duration(milliseconds: 40);
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

  /// علامة الهوية المقروءة: ياقوت على الورق، حليب ياقوتي على الليل.
  static Color brandOf(BuildContext c) =>
      isDark(c) ? VibesDark.coral : Vibes.coral;

  /// لون الزر الممتلئ: ياقوت نهاراً، نحاس ليلاً.
  static Color actionOf(BuildContext c) => isDark(c) ? Vibes.teal : Vibes.coral;

  static Color onActionOf(BuildContext c) =>
      isDark(c) ? VibesDark.onCoral : Vibes.onCoral;

  static Color hairlineStrongOf(BuildContext c) =>
      isDark(c) ? VibesDark.hairlineStrong : Vibes.hairlineStrong;

  static List<BoxShadow> cardOf(BuildContext c) =>
      isDark(c) ? VibesDark.card : Vibes.card;

  static List<BoxShadow> floatOf(BuildContext c) =>
      isDark(c) ? VibesDark.floating : Vibes.floating;

  static LinearGradient washOf(BuildContext c) =>
      isDark(c) ? VibesDark.nightWash : Vibes.ivoryWash;

  static LinearGradient buttonOf(BuildContext c) =>
      isDark(c) ? VibesDark.buttonFill : Vibes.coralFill;

  /// Cairo للنص العربي حتى تبقى الحروف متصلة. Montserrat احتياط للاتيني
  /// والأرقام إلى أن تُوفَّر ملفات Avenir Arabic المرخّصة.
  static TextTheme _text(TextTheme base) {
    final cairo = GoogleFonts.cairoTextTheme(base);
    final latin = GoogleFonts.montserrat().fontFamily;
    final fallback = <String>[?latin];

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
        weight: FontWeight.w800,
        height: 1.15,
      ),
      displayMedium: face(
        cairo.displayMedium,
        weight: FontWeight.w800,
        height: 1.18,
      ),
      displaySmall: face(
        cairo.displaySmall,
        weight: FontWeight.w800,
        height: 1.2,
      ),
      headlineMedium: face(
        cairo.headlineMedium,
        weight: FontWeight.w800,
        height: 1.25,
      ),
      headlineSmall: face(
        cairo.headlineSmall,
        weight: FontWeight.w800,
        height: 1.28,
      ),
      titleLarge: face(cairo.titleLarge, weight: FontWeight.w800),
      titleMedium: face(
        cairo.titleMedium,
        weight: FontWeight.w700,
        height: 1.4,
      ),
      titleSmall: face(cairo.titleSmall, weight: FontWeight.w700, height: 1.4),
      bodyLarge: face(cairo.bodyLarge, height: 1.6),
      bodyMedium: face(cairo.bodyMedium, height: 1.65),
      bodySmall: face(cairo.bodySmall, height: 1.55),
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
      colorScheme: const ColorScheme.light(
        primary: Vibes.coral,
        onPrimary: Vibes.onCoral,
        secondary: Vibes.teal,
        onSecondary: Vibes.onTeal,
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
          fontWeight: FontWeight.w800,
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
        indicatorColor: Vibes.coralMint,
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
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Vibes.ink,
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
        backgroundColor: Vibes.coral,
        foregroundColor: Vibes.onCoral,
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
          color: Vibes.coral,
          fontWeight: FontWeight.w800,
        ),
        labelStyle: text.labelMedium?.copyWith(
          color: Vibes.inkSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Vibes.coral,
          foregroundColor: Vibes.onCoral,
          minimumSize: const Size.fromHeight(56),
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          shape: const RoundedRectangleBorder(borderRadius: VibesRadius.folio),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Vibes.ink,
          minimumSize: const Size.fromHeight(56),
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
        labelColor: Vibes.coral,
        unselectedLabelColor: Vibes.inkTertiary,
        indicatorColor: Vibes.coral,
        dividerColor: Vibes.hairline,
        labelStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        unselectedLabelStyle: text.titleSmall,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Vibes.coral,
        linearTrackColor: Vibes.coralMint,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? Colors.white : Vibes.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Vibes.coral
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
          fontWeight: FontWeight.w800,
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
        focusedBorder: border(VibesDark.teal, 1.4),
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
          minimumSize: const Size.fromHeight(56),
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          shape: const RoundedRectangleBorder(borderRadius: VibesRadius.folio),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: VibesDark.ink,
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: VibesDark.hairlineStrong),
          shape: const RoundedRectangleBorder(borderRadius: VibesRadius.folio),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: VibesDark.tealBright,
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
        labelColor: VibesDark.tealBright,
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
