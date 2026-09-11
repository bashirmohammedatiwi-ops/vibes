import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ═══════════════════════════════════════════════════════════
/// VIBES Élégance — لغة التصميم الراقية
/// ثلاث نغمات فقط: الحبر Ink · البورسلان Porcelain · الذهبي الشامبانيا
/// الفخامة من خفض التعقيد: مساحات سخية، طباعة واثقة، حركة حريرية.
/// ═══════════════════════════════════════════════════════════

abstract final class InkColors {
  // الحبر — الخلفية الداكنة الافتراضية
  static const Color canvas = Color(0xFF101114);
  static const Color canvasHigh = Color(0xFF16181D);
  static const Color surface = Color(0xFF1A1C22);
  static const Color surfaceHigh = Color(0xFF22252C);
  static const Color hairline = Color(0x14FFFFFF); // حدود شعرية ~8% أبيض
  static const Color textPrimary = Color(0xFFF2F1EE);
  static const Color textSecondary = Color(0xFFA8A9AE);
  static const Color textTertiary = Color(0xFF6D6E74);
}

abstract final class PorcelainColors {
  // البورسلان — الوضع الفاتح
  static const Color canvas = Color(0xFFF7F6F3);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceHigh = Color(0xFFF1EFEA);
  static const Color hairline = Color(0x14101114); // ~8% حبر
  static const Color textPrimary = Color(0xFF17181C);
  static const Color textSecondary = Color(0xFF5C5D63);
  static const Color textTertiary = Color(0xFF9A9BA1);
}

abstract final class GoldColors {
  // الذهبي الشامبانيا — اللون المميز الوحيد
  static const Color gold = Color(0xFFC9A96A);
  static const Color goldLight = Color(0xFFE3C990);
  static const Color goldDeep = Color(0xFFA8854F);
  static const Color goldSoft = Color(0x1FC9A96A); // ~12% للسطوح الخافتة
  static const Color onGold = Color(0xFF17130B);

  static const LinearGradient gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldLight, gold, goldDeep],
  );

  static const LinearGradient textGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [goldLight, gold],
  );
}

/// ألوان وظيفية فقط — تظهر في الشرائح والنقاط، أبداً كزينة
abstract final class SemanticColors {
  static const Color success = Color(0xFF4C9A7A);
  static const Color warning = Color(0xFFC08A3E);
  static const Color danger = Color(0xFFB4574F);
  static const Color info = Color(0xFF5F7FA8);
}

/// سلّم المسافات — إيقاع موحد
abstract final class VibesSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// أنصاف الأقطار — بطاقات كبيرة ناعمة
abstract final class VibesRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double pill = 999;
}

/// مدد ومنحنيات الحركة الحريرية
abstract final class VibesMotion {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration base = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);
  static const Curve curve = Curves.easeOutCubic;
  static const Duration stagger = Duration(milliseconds: 40);
}

class VibesTheme {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// ألوان السياق الحالي
  static Color canvasOf(BuildContext c) =>
      isDark(c) ? InkColors.canvas : PorcelainColors.canvas;
  static Color surfaceOf(BuildContext c) =>
      isDark(c) ? InkColors.surface : PorcelainColors.surface;
  static Color surfaceHighOf(BuildContext c) =>
      isDark(c) ? InkColors.surfaceHigh : PorcelainColors.surfaceHigh;
  static Color hairlineOf(BuildContext c) =>
      isDark(c) ? InkColors.hairline : PorcelainColors.hairline;
  static Color textPrimaryOf(BuildContext c) =>
      isDark(c) ? InkColors.textPrimary : PorcelainColors.textPrimary;
  static Color textSecondaryOf(BuildContext c) =>
      isDark(c) ? InkColors.textSecondary : PorcelainColors.textSecondary;
  static Color textTertiaryOf(BuildContext c) =>
      isDark(c) ? InkColors.textTertiary : PorcelainColors.textTertiary;

  static TextTheme _text(TextTheme base) =>
      GoogleFonts.cairoTextTheme(base);

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final text = _text(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: InkColors.canvas,
      textTheme: text,
      colorScheme: const ColorScheme.dark(
        primary: GoldColors.gold,
        onPrimary: GoldColors.onGold,
        secondary: GoldColors.goldLight,
        onSecondary: GoldColors.onGold,
        surface: InkColors.surface,
        onSurface: InkColors.textPrimary,
        surfaceContainerHighest: InkColors.surfaceHigh,
        onSurfaceVariant: InkColors.textSecondary,
        outline: InkColors.hairline,
        error: SemanticColors.danger,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: InkColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: InkColors.textPrimary),
      ),
      dividerTheme: const DividerThemeData(
        color: InkColors.hairline,
        thickness: 0.5,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xF016181D),
        surfaceTintColor: Colors.transparent,
        indicatorColor: GoldColors.goldSoft,
        height: 72,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          text.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: InkColors.textSecondary,
          ),
        ),
        iconTheme: const WidgetStatePropertyAll(
          IconThemeData(color: InkColors.textTertiary),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: InkColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: InkColors.surface,
        showDragHandle: true,
        dragHandleColor: GoldColors.gold,
        dragHandleSize: Size(44, 4),
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(VibesRadius.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: InkColors.surfaceHigh,
        contentTextStyle:
            text.bodyMedium?.copyWith(color: InkColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VibesRadius.md),
          side: const BorderSide(color: InkColors.hairline),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: InkColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VibesRadius.xl),
          side: const BorderSide(color: InkColors.hairline),
        ),
      ),
      inputDecorationTheme: _input(true, text),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GoldColors.gold,
          foregroundColor: GoldColors.onGold,
          minimumSize: const Size.fromHeight(52),
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VibesRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: InkColors.textPrimary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: InkColors.hairline, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VibesRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: GoldColors.gold,
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: InkColors.surfaceHigh,
        side: const BorderSide(color: InkColors.hairline),
        labelStyle: text.labelMedium?.copyWith(color: InkColors.textSecondary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VibesRadius.pill),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: GoldColors.gold,
        unselectedLabelColor: InkColors.textTertiary,
        indicatorColor: GoldColors.gold,
        dividerColor: InkColors.hairline,
        labelStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: text.titleSmall,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: GoldColors.gold,
        linearTrackColor: GoldColors.goldSoft,
      ),
    );
  }

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final text = _text(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: PorcelainColors.canvas,
      textTheme: text,
      colorScheme: const ColorScheme.light(
        primary: GoldColors.goldDeep,
        onPrimary: GoldColors.onGold,
        secondary: GoldColors.gold,
        onSecondary: GoldColors.onGold,
        surface: PorcelainColors.surface,
        onSurface: PorcelainColors.textPrimary,
        surfaceContainerHighest: PorcelainColors.surfaceHigh,
        onSurfaceVariant: PorcelainColors.textSecondary,
        outline: PorcelainColors.hairline,
        error: SemanticColors.danger,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: PorcelainColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: PorcelainColors.textPrimary),
      ),
      dividerTheme: const DividerThemeData(
        color: PorcelainColors.hairline,
        thickness: 0.5,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xF0FFFFFF),
        surfaceTintColor: Colors.transparent,
        indicatorColor: GoldColors.goldSoft,
        height: 72,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          text.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: PorcelainColors.textSecondary,
          ),
        ),
        iconTheme: const WidgetStatePropertyAll(
          IconThemeData(color: PorcelainColors.textTertiary),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: PorcelainColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: PorcelainColors.surface,
        showDragHandle: true,
        dragHandleColor: GoldColors.gold,
        dragHandleSize: Size(44, 4),
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(VibesRadius.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: PorcelainColors.surface,
        contentTextStyle:
            text.bodyMedium?.copyWith(color: PorcelainColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VibesRadius.md),
          side: const BorderSide(color: PorcelainColors.hairline),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: PorcelainColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VibesRadius.xl),
          side: const BorderSide(color: PorcelainColors.hairline),
        ),
      ),
      inputDecorationTheme: _input(false, text),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GoldColors.goldDeep,
          foregroundColor: GoldColors.onGold,
          minimumSize: const Size.fromHeight(52),
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VibesRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PorcelainColors.textPrimary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: PorcelainColors.hairline, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VibesRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: GoldColors.goldDeep,
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: PorcelainColors.surfaceHigh,
        side: const BorderSide(color: PorcelainColors.hairline),
        labelStyle:
            text.labelMedium?.copyWith(color: PorcelainColors.textSecondary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VibesRadius.pill),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: GoldColors.goldDeep,
        unselectedLabelColor: PorcelainColors.textTertiary,
        indicatorColor: GoldColors.gold,
        dividerColor: PorcelainColors.hairline,
        labelStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: text.titleSmall,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: GoldColors.goldDeep,
        linearTrackColor: GoldColors.goldSoft,
      ),
    );
  }

  static InputDecorationTheme _input(bool dark, TextTheme text) {
    final fill = dark ? InkColors.canvasHigh : PorcelainColors.surface;
    final hint = dark ? InkColors.textTertiary : PorcelainColors.textTertiary;
    final hairline =
        dark ? InkColors.hairline : PorcelainColors.hairline;

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(VibesRadius.md),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      hintStyle: text.bodyMedium?.copyWith(color: hint),
      labelStyle: text.bodyMedium?.copyWith(color: hint),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: VibesSpacing.lg,
        vertical: VibesSpacing.md,
      ),
      border: border(hairline),
      enabledBorder: border(hairline),
      focusedBorder: border(GoldColors.gold, 1.2),
      errorBorder: border(SemanticColors.danger),
      focusedErrorBorder: border(SemanticColors.danger, 1.2),
      suffixIconColor: GoldColors.gold,
      prefixIconColor: hint,
      errorStyle: text.bodySmall?.copyWith(color: SemanticColors.danger),
      floatingLabelStyle: text.bodySmall?.copyWith(color: GoldColors.gold),
      counterStyle: text.bodySmall?.copyWith(color: hint),
      helperStyle: text.bodySmall?.copyWith(color: hint),
    );
  }
}

/// ألوان ثابتة للاستخدام في const contexts
abstract final class VibesThemeStatic {
  static const Color muted = InkColors.textSecondary;
}

/// توافق مع الإصدار القديم — سيُزال تدريجياً
@Deprecated('استخدم GoldColors / InkColors / PorcelainColors')
abstract final class AppColors {
  static const primary = InkColors.canvas;
  static const accent = GoldColors.gold;
  static const surface = PorcelainColors.canvas;
  static const muted = PorcelainColors.textSecondary;
}
