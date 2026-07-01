/// Spacing tokens estimated from web app visual observation
/// Web uses Tailwind spacing scale (4px base)
class GCSpacing {
  // ── Base unit ─────────────────────────────────────
  static const double unit = 4.0;

  // ── Common gaps ───────────────────────────────────
  static const double xs = 4.0;   // gap-1
  static const double sm = 8.0;   // gap-2
  static const double md = 16.0;  // gap-4
  static const double lg = 24.0;  // gap-6
  static const double xl = 32.0;  // gap-8
  static const double xxl = 48.0; // gap-12

  // ── Section padding ───────────────────────────────
  // from web: "py-20 md:py-28" → 80px–112px vertical
  static const double sectionVertical = 80.0;
  static const double sectionVerticalLarge = 112.0;

  // ── Content padding ───────────────────────────────
  // from web: "px-4 sm:px-6 lg:px-8"
  static const double pagePaddingMobile = 16.0;
  static const double pagePaddingTablet = 24.0;
  static const double pagePaddingDesktop = 32.0;

  // ── Card padding ──────────────────────────────────
  // from web: "p-6" → 24px
  static const double cardPadding = 24.0;

  // ── Max content width ─────────────────────────────
  // from web: "max-w-7xl" → 1280px
  static const double maxContentWidth = 1280.0;
  // from web: "max-w-4xl" → 896px (for CTA sections)
  static const double maxContentWidthNarrow = 896.0;

  // ── Border radius ─────────────────────────────────
  // from web: --radius: 0.75rem (12px)
  static const double radiusSm = 8.0;   // radius - 4px
  static const double radiusMd = 10.0;  // radius - 2px
  static const double radiusLg = 12.0;  // the base
  static const double radiusXl = 16.0;  // radius + 4px
  static const double radiusRound = 999.0; // full round (pill, avatar)

  // ── Nav bar ───────────────────────────────────────
  // from web: "h-16 md:h-20"
  static const double navHeightMobile = 64.0;
  static const double navHeightDesktop = 80.0;
}
