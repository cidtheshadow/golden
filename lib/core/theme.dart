import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';
import 'spacing.dart';

/// Master theme built entirely from Phase 1 design tokens
ThemeData gcTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: GCColors.background,

    // ── Color Scheme ────────────────────────────────
    colorScheme: const ColorScheme.light(
      primary: GCColors.primary,
      onPrimary: GCColors.primaryForeground,
      secondary: GCColors.secondary,
      onSecondary: GCColors.secondaryForeground,
      surface: GCColors.card,
      onSurface: GCColors.foreground,
      error: GCColors.destructive,
      onError: GCColors.destructiveForeground,
      outline: GCColors.border,
    ),

    // ── Typography ──────────────────────────────────
    textTheme: TextTheme(
      displayLarge: GoogleFonts.lora(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        color: GCColors.foreground,
      ),
      displayMedium: GoogleFonts.lora(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: GCColors.foreground,
      ),
      displaySmall: GoogleFonts.lora(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: GCColors.foreground,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: GCColors.foreground,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: GCColors.foreground,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: GCColors.foreground,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: GCColors.mutedForeground,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: GCColors.mutedForeground,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: GCColors.mutedForeground,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: GCColors.foreground,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: GCColors.mutedForeground,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: GCColors.mutedForeground,
      ),
    ),

    // ── App Bar ─────────────────────────────────────
    appBarTheme: AppBarTheme(
      backgroundColor: GCColors.card,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: GCColors.background,
      titleTextStyle: GoogleFonts.lora(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: GCColors.foreground,
      ),
      iconTheme: const IconThemeData(color: GCColors.foreground),
    ),

    // ── Cards ───────────────────────────────────────
    // from web: white bg, border, 12px radius, p-6
    cardTheme: CardThemeData(
      color: GCColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GCSpacing.radiusLg),
        side: const BorderSide(color: GCColors.border, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),

    // ── Elevated Buttons (Primary) ──────────────────
    // from web: "bg-primary text-primary-foreground hover:bg-primary/90"
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: GCColors.primary,
        foregroundColor: GCColors.primaryForeground,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GCSpacing.radiusMd),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),

    // ── Outlined Buttons ────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: GCColors.foreground,
        side: const BorderSide(color: GCColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GCSpacing.radiusMd),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),

    // ── Text Buttons (Ghost) ────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: GCColors.foreground,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),

    // ── Input Decoration ────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: GCColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GCSpacing.radiusMd),
        borderSide: const BorderSide(color: GCColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GCSpacing.radiusMd),
        borderSide: const BorderSide(color: GCColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GCSpacing.radiusMd),
        borderSide: const BorderSide(color: GCColors.primary, width: 2),
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 14,
        color: GCColors.mutedForeground,
      ),
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        color: GCColors.mutedForeground,
      ),
    ),

    // ── Divider ─────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: GCColors.border,
      thickness: 1,
    ),

    // ── Bottom Nav (for post-login dashboard) ───────
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: GCColors.card,
      selectedItemColor: GCColors.primary,
      unselectedItemColor: GCColors.mutedForeground,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    // ── Chip (for badges) ───────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: GCColors.primary.withAlpha(26), // primary/10
      side: BorderSide(color: GCColors.primary.withAlpha(51)), // primary/20
      labelStyle: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: GCColors.primary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GCSpacing.radiusRound),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
  );
}
