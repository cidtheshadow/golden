import 'package:flutter/material.dart';

/// Design tokens extracted from Web app globals.css
/// OKLCH values converted to HEX approximations
class GCColors {
  // ── Primary (Olive Green) ──────────────────────────────
  static const primary = Color(0xFF5A6844);
  static const primaryForeground = Color(0xFFFAF6EE);

  // ── Background & Foreground ─────────────────────────
  static const background = Color(0xFFFAF6EE);
  static const foreground = Color(0xFF2D3325);

  // ── Card ────────────────────────────────────────────
  static const card = Color(0xFFFFFFFF);
  static const cardForeground = Color(0xFF2D3325); 

  // ── Secondary (Sage Green Accent) ───────────────────
  static const secondary = Color(0xFFE3ECE1);
  static const secondaryForeground = Color(0xFF5A6844);

  // ── Muted ───────────────────────────────────────────
  static const muted = Color(0xFFF7F4EB);
  static const mutedForeground = Color(0xFF5C6450);

  // ── Accent ──────────────────────────────────────────
  static const accent = Color(0xFF6D7A56);
  static const accentForeground = Color(0xFFFAFAFA);

  // ── Destructive ─────────────────────────────────────
  static const destructive = Color(0xFFB5302D);
  static const destructiveForeground = Color(0xFFFAFAFA);

  // ── Borders & Inputs ────────────────────────────────
  static const border = Color(0xFFE7DFD4);
  static const input = Color(0xFFE7DFD4);
  static const ring = Color(0xFF5A6844);

  // ── Gold Shades (Kept for compatibility, updated tones if needed) ──
  static const goldLight = Color(0xFFDCC590);
  static const goldDark = Color(0xFF8A6A1E);

  // ── Sage Shades ─────────────────────────────────────
  static const sageLight = Color(0xFFB5D4C0);

  // ── Star Rating ─────────────────────────────────────
  static const starFilled = Color(0xFFC4973B); // Keep stars gold

  // ── Footer ──────────────────────────────────────────
  static const footerBackground = foreground;
  static const footerText = background;

  // ── Warning (Important Notice) ──────────────────────
  static const warningBackground = Color(0xFFFFF8E1); 
  static const warningBorder = Color(0xFFFFE082); 
  static const warningText = Color(0xFF6D4C00); 
  static const warningIcon = Color(0xFFE65100); 
}
