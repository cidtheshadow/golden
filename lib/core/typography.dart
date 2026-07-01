import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// Typography tokens extracted from web app layout.tsx and globals.css
/// Heading font: Playfair Display (serif) — from web: font-serif
/// Body font:    Inter (sans-serif) — from web: font-sans
class GCTypography {
  // ── Heading (Serif — Playfair Display) ──────────────
  // Used for: hero headline, section titles, CTA headings
  // from web: "text-4xl md:text-5xl lg:text-6xl font-serif font-bold"
  static TextStyle displayLarge = GoogleFonts.playfairDisplay(
    fontSize: 48, // ~text-5xl / text-6xl
    fontWeight: FontWeight.w700,
    color: GCColors.foreground,
    height: 1.15,
  );

  // from web: "text-3xl md:text-4xl font-serif font-bold"
  static TextStyle displayMedium = GoogleFonts.playfairDisplay(
    fontSize: 36, // ~text-3xl / text-4xl
    fontWeight: FontWeight.w700,
    color: GCColors.foreground,
    height: 1.2,
  );

  static TextStyle displaySmall = GoogleFonts.playfairDisplay(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: GCColors.foreground,
    height: 1.25,
  );

  // ── Heading (Sans — Inter) for smaller headings ─────
  // from web: "text-xl font-semibold"
  static TextStyle headlineLarge = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: GCColors.foreground,
  );

  static TextStyle headlineMedium = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: GCColors.foreground,
  );

  // from web: "text-lg font-semibold" — service card titles
  static TextStyle headlineSmall = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: GCColors.foreground,
  );

  // ── Body ────────────────────────────────────────────
  // from web: "text-lg text-muted-foreground" — hero subtext
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: GCColors.mutedForeground,
    height: 1.6,
  );

  // from web: "text-sm text-muted-foreground" — card descriptions
  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: GCColors.mutedForeground,
    height: 1.5,
  );

  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: GCColors.mutedForeground,
  );

  // ── Labels & Buttons ────────────────────────────────
  // from web: "text-sm font-medium" — nav items
  static TextStyle labelMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: GCColors.mutedForeground,
    height: 1.4,
  );

  // from web: "text-base" — button text
  static TextStyle buttonText = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: GCColors.primaryForeground,
    height: 1.4,
  );

  // ── Stats ───────────────────────────────────────────
  // from web: "text-3xl md:text-4xl font-bold text-primary"
  static TextStyle statValue = GoogleFonts.inter(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    color: GCColors.primary,
  );

  static TextStyle statLabel = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: GCColors.mutedForeground,
  );

  // ── Badge ───────────────────────────────────────────
  // from web: badge text with icon
  static TextStyle badgeText = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  // ── Price ───────────────────────────────────────────
  // from web: "text-sm font-semibold text-primary"
  static TextStyle price = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: GCColors.primary,
  );
}
