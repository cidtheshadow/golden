import 'package:flutter/material.dart';
import '../../core/typography.dart';
import '../../core/spacing.dart';
import '../../core/colors.dart';
import '../../core/constants.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GCColors.background,
      appBar: AppBar(title: const Text('Contact Us')),
      body: ListView(
        padding: const EdgeInsets.all(GCSpacing.md),
        children: [
          Text('Get in Touch', style: GCTypography.displayMedium),
          const SizedBox(height: 24),
          const ListTile(
            leading: Icon(Icons.email, color: GCColors.primary),
            title: Text('Support Email'),
            subtitle: Text(GCConstants.email),
          ),
          const ListTile(
            leading: Icon(Icons.phone, color: GCColors.primary),
            title: Text('Phone Number'),
            subtitle: Text(GCConstants.phone),
          ),
          const ListTile(
            leading: Icon(Icons.location_on, color: GCColors.primary),
            title: Text('Business Address'),
            subtitle: Text(GCConstants.address),
          ),
        ],
      ),
    );
  }
}
