import 'package:flutter/material.dart';
import '../core/colors.dart';

class GCButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final bool isPrimary;

  const GCButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? GCColors.primary : GCColors.secondary,
        foregroundColor: isPrimary ? GCColors.primaryForeground : GCColors.secondaryForeground,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
