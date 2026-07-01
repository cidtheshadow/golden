import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/colors.dart';
import '../../core/spacing.dart';
import '../../core/typography.dart';

class LegalPolicyScreen extends StatelessWidget {
  final String title;
  final String content;

  const LegalPolicyScreen({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GCColors.background,
      appBar: AppBar(
        title: Text(title, style: GCTypography.headlineMedium),
        centerTitle: true,
        elevation: 0,
        backgroundColor: GCColors.background,
        automaticallyImplyLeading: false, // Remove default back button
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: GCSpacing.md, vertical: GCSpacing.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Container(
              padding: const EdgeInsets.all(GCSpacing.xxl),
              decoration: BoxDecoration(
                color: GCColors.card,
                borderRadius: BorderRadius.circular(GCSpacing.radiusLg),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_back, size: 20, color: GCColors.foreground),
                          const SizedBox(width: 8),
                          Text(
                            "Back",
                            style: GCTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: GCColors.foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: GCSpacing.xl),
                  MarkdownBody(
                    data: content,
                    styleSheet: MarkdownStyleSheet(
                      h1: GCTypography.displayMedium.copyWith(color: GCColors.primary),
                      h2: GCTypography.headlineMedium.copyWith(color: GCColors.foreground),
                      p: GCTypography.bodyLarge.copyWith(height: 1.6, color: GCColors.foreground.withAlpha(220)),
                      listBullet: GCTypography.bodyLarge.copyWith(color: GCColors.primary),
                      strong: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
