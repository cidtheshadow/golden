import 'package:flutter/material.dart';

/// Breakpoints for GoldenCare responsive layout
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

/// Returns true if the current screen is web/desktop width
bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= Breakpoints.mobile;

/// Returns true if running on a desktop-width screen
bool isDesktop(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= Breakpoints.desktop;

/// Constrained width for web content — centers content on wide screens
/// Use this as the maxWidth for page body content
double contentMaxWidth(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= Breakpoints.desktop) return 500;
  if (w >= Breakpoints.tablet) return 600;
  return w;
}

/// Responsive horizontal padding
double horizontalPadding(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= Breakpoints.desktop) return 0;
  if (w >= Breakpoints.tablet) return 48;
  return 24;
}

/// Responsive font size multiplier
double fontScale(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= Breakpoints.desktop) return 1.1;
  if (w >= Breakpoints.tablet) return 1.05;
  return 1.0;
}

/// Wraps a child in a centered, width-constrained box for web layouts
/// Use this on every screen's body content
Widget responsiveContainer({
  required BuildContext context,
  required Widget child,
  EdgeInsets? padding,
}) {
  return Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
      child: Padding(
        padding: padding ??
            EdgeInsets.symmetric(
              horizontal: horizontalPadding(context),
              vertical: 16,
            ),
        child: child,
      ),
    ),
  );
}
