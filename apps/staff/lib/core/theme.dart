import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const placeInk = Color(0xFF141C2B);
const placeInk2 = Color(0xFF5A6678);
const placeBrass = Color(0xFFA5813A);
const placePaper = Color(0xFFF6F7F9);
const placeLine = Color(0xFFE4E9F0);
const placeSuccess = Color(0xFF0D9488);
const placeDanger = Color(0xFFDC2626);
const placeShiftMorning = Color(0xFFD97706);
const placeShiftEvening = Color(0xFF4F46E5);
const placeShiftFull = Color(0xFF141C2B);

const apiBase = 'http://187.127.88.146:6001';

ThemeData buildStaffTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: placeInk,
      primary: placeInk,
      secondary: placeBrass,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: placePaper,
    dividerColor: placeLine,
  );
  final cairo = GoogleFonts.cairoTextTheme(base.textTheme);
  final montserrat = GoogleFonts.montserrat();
  return base.copyWith(
    textTheme: cairo,
    appBarTheme: AppBarTheme(
      backgroundColor: placePaper,
      foregroundColor: placeInk,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: cairo.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: placeInk),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: placeBrass.withValues(alpha: 0.15),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return cairo.labelSmall?.copyWith(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? placeInk : placeInk2,
        );
      }),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: placeLine)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: placeInk,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: cairo.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: placeInk,
        side: const BorderSide(color: placeLine),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: placeLine)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: placeLine)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: placeBrass, width: 1.5)),
      labelStyle: TextStyle(color: placeInk2, fontFamily: cairo.bodyMedium?.fontFamily),
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
