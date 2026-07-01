import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/spacing.dart';
import '../../core/typography.dart';
import '../../core/constants.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GCColors.background,
      appBar: AppBar(title: const Text('About Us')),
      body: ListView(
        padding: const EdgeInsets.all(GCSpacing.md),
        children: [
          Text(GCConstants.appName, style: GCTypography.displayMedium),
          const SizedBox(height: 8),
          Text(
            GCConstants.appTagline,
            style: GCTypography.bodyLarge.copyWith(color: GCColors.mutedForeground),
          ),
          const SizedBox(height: 24),
          Text('Who We Are', style: GCTypography.headlineMedium),
          const SizedBox(height: 12),
          const Text(
            'GoldenCare is a compassionate caregiving service platform that connects families '
            'with verified, professional caregivers in the Chandigarh, Mohali, and Panchkula region. '
            'We specialise in providing personalised companionship and non-medical assistance '
            'to elderly individuals so they can continue to live with dignity and comfort.',
            style: TextStyle(height: 1.6),
          ),
          const SizedBox(height: 24),
          Text('Our Mission', style: GCTypography.headlineMedium),
          const SizedBox(height: 12),
          const Text(
            'To bridge the gap between families and trusted caregivers through a seamless, '
            'technology-driven booking experience. Every caregiver on our platform is ID-verified, '
            'and every booking is tracked in real time for safety and transparency.',
            style: TextStyle(height: 1.6),
          ),
          const SizedBox(height: 24),
          Text('Contact Information', style: GCTypography.headlineMedium),
          const SizedBox(height: 12),
          const ListTile(
            leading: Icon(Icons.email, color: GCColors.primary),
            title: Text('Email'),
            subtitle: Text(GCConstants.email),
            contentPadding: EdgeInsets.zero,
          ),
          const ListTile(
            leading: Icon(Icons.phone, color: GCColors.primary),
            title: Text('Phone'),
            subtitle: Text(GCConstants.phone),
            contentPadding: EdgeInsets.zero,
          ),
          const ListTile(
            leading: Icon(Icons.location_on, color: GCColors.primary),
            title: Text('Registered Address'),
            subtitle: Text(GCConstants.address),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          Text(
            GCConstants.copyright,
            style: GCTypography.bodySmall.copyWith(color: GCColors.mutedForeground),
          ),
        ],
      ),
    );
  }
}
