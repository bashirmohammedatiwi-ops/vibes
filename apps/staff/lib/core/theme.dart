import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// ═══════════════════════════════════════════════════════════
/// نظام تصميم «VIBES مكتب» — كحلي وذهبي، خلفية فاتحة وبطاقات بيضاء.
/// الأسماء القديمة (placeInk…) محفوظة لتعمل كل الشاشات، بقيم جديدة.
/// ═══════════════════════════════════════════════════════════

// ── الألوان الأساسية ──
const placeInk = Color(0xFF0F1B2D); // نص أساسي + كحلي العلامة
const placeInk2 = Color(0xFF5B6576); // نص ثانوي
const placeInk3 = Color(0xFF8A93A3); // نص ثالث / تلميحات
const placeBrass = Color(0xFFB8862E); // ذهبي (نص/أيقونات على الأبيض)
const placeGold = Color(0xFFC89844); // ذهبي التعبئة
const placeGoldSoft = Color(0xFFFBF4E6); // خلفية ذهبية خفيفة
const placeNavy = Color(0xFF13233A);
const placeNavyHigh = Color(0xFF1B3857);
const placePaper = Color(0xFFF4F5F8); // خلفية الشاشات
const placeSurface = Colors.white;
const placeLine = Color(0xFFE7E9EE);
const placeLineSoft = Color(0xFFF0F1F4);

// ── دلالات ──
const placeSuccess = Color(0xFF0F9D7A);
const placeWarning = Color(0xFFD97706);
const placeDanger = Color(0xFFDC2626);
const placeInfo = Color(0xFF2563EB);

// ── الشفتات ──
const placeShiftMorning = Color(0xFFD97706);
const placeShiftEvening = Color(0xFF4F46E5);
const placeShiftFull = Color(0xFF0F1B2D);

// ── تدرّجات ──
const placeNavyFill = LinearGradient(
  begin: AlignmentDirectional.topStart,
  end: AlignmentDirectional.bottomEnd,
  colors: [placeNavyHigh, placeNavy],
);
const placeGoldFill = LinearGradient(
  begin: AlignmentDirectional.topStart,
  end: AlignmentDirectional.bottomEnd,
  colors: [Color(0xFFE0B568), placeGold],
);

// ── مقاييس ──
abstract final class StaffRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 26.0;
}

abstract final class StaffSpace {
  static const page = 16.0; // هامش الشاشة
  static const gap = 12.0; // بين البطاقات
}

/// ظل البطاقات الموحّد — ناعم وخفيف.
const staffCardShadow = [
  BoxShadow(color: Color(0x0A0F1B2D), blurRadius: 14, offset: Offset(0, 4)),
];

const apiBase = 'http://187.127.88.146:6001';

ThemeData buildStaffTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: placeNavy,
    primary: placeInk,
    onPrimary: Colors.white,
    secondary: placeGold,
    onSecondary: placeInk,
    surface: Colors.white,
    onSurface: placeInk,
    error: placeDanger,
  ).copyWith(
    surfaceTint: Colors.transparent,
    outline: placeLine,
    outlineVariant: placeLineSoft,
    surfaceContainerHighest: placePaper,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: placePaper,
    dividerColor: placeLine,
    visualDensity: VisualDensity.standard,
  );
  final cairo = GoogleFonts.cairoTextTheme(base.textTheme).apply(bodyColor: placeInk, displayColor: placeInk);
  final montserrat = GoogleFonts.montserrat();
  final shape14 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(StaffRadius.md));

  OutlineInputBorder field(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(StaffRadius.md),
        borderSide: BorderSide(color: c, width: w),
      );

  return base.copyWith(
    textTheme: cairo.copyWith(
      headlineSmall: cairo.headlineSmall?.copyWith(fontWeight: FontWeight.w900, fontSize: 24),
      titleLarge: cairo.titleLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 19),
      titleMedium: cairo.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 16),
      titleSmall: cairo.titleSmall?.copyWith(fontWeight: FontWeight.w800, fontSize: 14),
      bodyMedium: cairo.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
      bodySmall: cairo.bodySmall?.copyWith(fontSize: 12.5, color: placeInk2, height: 1.45),
      labelLarge: cairo.labelLarge?.copyWith(fontWeight: FontWeight.w800),
      labelMedium: cairo.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: placeInk2),
      labelSmall: cairo.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: placeInk2),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: placePaper,
      surfaceTintColor: Colors.transparent,
      foregroundColor: placeInk,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      shadowColor: placeLine,
      centerTitle: false,
      titleSpacing: 4,
      systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      titleTextStyle: cairo.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: placeInk, fontSize: 19),
      iconTheme: const IconThemeData(color: placeInk, size: 22),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: placeGoldSoft,
      indicatorShape: const StadiumBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? placeBrass : placeInk2, size: 24),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return cairo.labelSmall?.copyWith(
          fontSize: 11.5,
          fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
          color: selected ? placeInk : placeInk2,
        );
      }),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StaffRadius.lg),
        side: const BorderSide(color: placeLine),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: placeInk2,
      titleTextStyle: cairo.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: placeInk),
      subtitleTextStyle: cairo.bodySmall?.copyWith(color: placeInk2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      shape: shape14,
    ),
    dividerTheme: const DividerThemeData(color: placeLine, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: placeInk,
        foregroundColor: Colors.white,
        disabledBackgroundColor: placeLine,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: shape14,
        textStyle: cairo.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: placeGold,
        foregroundColor: placeInk,
        elevation: 0,
        minimumSize: const Size(64, 48),
        shape: shape14,
        textStyle: cairo.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: placeInk,
        backgroundColor: Colors.white,
        side: const BorderSide(color: placeLine),
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: shape14,
        textStyle: cairo.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: placeBrass,
        textStyle: cairo.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        shape: shape14,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: placeInk,
      foregroundColor: Colors.white,
      elevation: 2,
      highlightElevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StaffRadius.lg)),
      extendedTextStyle: cairo.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: field(placeLine),
      enabledBorder: field(placeLine),
      focusedBorder: field(placeGold, 1.6),
      errorBorder: field(placeDanger),
      focusedErrorBorder: field(placeDanger, 1.6),
      labelStyle: cairo.bodyMedium?.copyWith(color: placeInk2),
      floatingLabelStyle: cairo.bodyMedium?.copyWith(color: placeBrass, fontWeight: FontWeight.w700),
      hintStyle: cairo.bodyMedium?.copyWith(color: placeInk3),
      prefixIconColor: placeInk2,
      suffixIconColor: placeInk2,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: placeInk,
      disabledColor: placeLineSoft,
      side: const BorderSide(color: placeLine),
      shape: const StadiumBorder(),
      labelStyle: cairo.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: placeInk),
      secondaryLabelStyle: cairo.labelMedium?.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? placeInk : Colors.white),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : placeInk),
        side: const WidgetStatePropertyAll(BorderSide(color: placeLine)),
        textStyle: WidgetStatePropertyAll(cairo.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : placeInk3),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? placeSuccess : placeLine),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? placeInk : Colors.white),
      side: const BorderSide(color: placeInk3, width: 1.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? placeInk : placeInk3),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: placeInk,
      unselectedLabelColor: placeInk2,
      indicatorColor: placeGold,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: placeLine,
      labelStyle: cairo.titleSmall?.copyWith(fontWeight: FontWeight.w900),
      unselectedLabelStyle: cairo.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: placeLine,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(StaffRadius.xl))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StaffRadius.xl)),
      titleTextStyle: cairo.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: placeInk),
      contentTextStyle: cairo.bodyMedium?.copyWith(color: placeInk2, height: 1.6),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: placeInk,
      contentTextStyle: cairo.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
      actionTextColor: placeGold,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StaffRadius.md)),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StaffRadius.md)),
      textStyle: cairo.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: placeGold,
      linearTrackColor: placeLineSoft,
      circularTrackColor: Colors.transparent,
    ),
    badgeTheme: const BadgeThemeData(backgroundColor: placeDanger, textColor: Colors.white),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: placeInk,
      headerForegroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StaffRadius.xl)),
      todayBorder: const BorderSide(color: placeGold),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StaffRadius.xl)),
    ),
    extensions: [StaffBrand(montserrat: montserrat)],
  );
}

class StaffBrand extends ThemeExtension<StaffBrand> {
  const StaffBrand({required this.montserrat});

  final TextStyle montserrat;

  @override
  StaffBrand copyWith({TextStyle? montserrat}) => StaffBrand(montserrat: montserrat ?? this.montserrat);

  @override
  StaffBrand lerp(ThemeExtension<StaffBrand>? other, double t) => this;
}
