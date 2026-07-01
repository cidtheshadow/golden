import 'package:flutter/material.dart';
import '../colors.dart';
import '../utils/responsive.dart';

enum GCButtonVariant { primary, secondary, outline }

/// GoldenCare branded button — responsive with hover effects for web
/// Uses exact brand tokens from GCColors and adapts sizing for web vs mobile
class GCButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final GCButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final double? width;

  const GCButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = GCButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    final buttonWidth = width ?? double.infinity;
    final borderRadius = BorderRadius.circular(wide ? 12 : 10);
    final verticalPad = wide ? 16.0 : 14.0;
    final fontSize = wide ? 16.0 : 15.0;

    // Brand colors from GCColors design tokens
    const primaryColor = GCColors.primary;
    const onPrimaryColor = GCColors.primaryForeground;
    const secondaryColor = GCColors.secondary;
    const onSecondaryColor = GCColors.secondaryForeground;

    Widget child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant == GCButtonVariant.primary
                  ? onPrimaryColor
                  : primaryColor,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: fontSize + 2),
                const SizedBox(width: 8),
              ],
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  label,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          );

    ButtonStyle style(Color bg, Color fg, Color? border) => ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return bg.withValues(alpha: 0.4);
            }
            if (states.contains(WidgetState.hovered)) {
              return bg.withValues(alpha: 0.85);
            }
            return bg;
          }),
          foregroundColor: WidgetStateProperty.all(fg),
          overlayColor: WidgetStateProperty.all(fg.withValues(alpha: 0.08)),
          elevation: WidgetStateProperty.resolveWith((states) {
            if (variant != GCButtonVariant.primary) return 0;
            return states.contains(WidgetState.hovered) ? 4 : 2;
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: borderRadius),
          ),
          side: border != null
              ? WidgetStateProperty.all(BorderSide(color: border, width: 1.5))
              : null,
          padding: WidgetStateProperty.all(
            EdgeInsets.symmetric(vertical: verticalPad, horizontal: 24),
          ),
          minimumSize: WidgetStateProperty.all(Size(buttonWidth, 0)),
        );

    return switch (variant) {
      GCButtonVariant.primary => ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: style(primaryColor, onPrimaryColor, null),
          child: child,
        ),
      GCButtonVariant.secondary => ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: style(secondaryColor, onSecondaryColor, null),
          child: child,
        ),
      GCButtonVariant.outline => OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: style(Colors.transparent, primaryColor, primaryColor),
          child: child,
        ),
    };
  }
}
