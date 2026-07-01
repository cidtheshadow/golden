import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/colors.dart';
import '../../../core/spacing.dart';
import '../../../core/typography.dart';
import '../../../models/service_personnel_model.dart';

class CaregiverCard extends StatelessWidget {
  final ServicePersonnelModel personnel;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;
  final int? completedVisitsOverride;

  const CaregiverCard({
    super.key,
    required this.personnel,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
    this.completedVisitsOverride,
  });

  int get _effectiveVisits {
    final override = completedVisitsOverride ?? personnel.visitsCompleted;
    return override > personnel.visitsCompleted
        ? override
        : personnel.visitsCompleted;
  }

  String _limitWords(String input, int maxWords) {
    final words =
        input.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length <= maxWords) return input.trim();
    return '${words.take(maxWords).join(' ')}...';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GCSpacing.radiusLg),
        border: Border.all(
          color: isSelected ? GCColors.primary : GCColors.border,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                    color: GCColors.primary.withAlpha(26),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ]
            : [
                BoxShadow(
                    color: Colors.black.withAlpha(13),
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section (always visible)
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(GCSpacing.radiusLg),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: GCColors.secondary,
                        child: ClipOval(
                          child: personnel.imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: personnel.imageUrl,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    color: GCColors.secondary,
                                    alignment: Alignment.center,
                                    child: Text(
                                      personnel.name.isNotEmpty
                                          ? personnel.name[0]
                                          : '?',
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: GCColors.secondary,
                                    alignment: Alignment.center,
                                    child: Text(
                                      personnel.name.isNotEmpty
                                          ? personnel.name[0]
                                          : '?',
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    personnel.name.isNotEmpty
                                        ? personnel.name[0]
                                        : '?',
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Basic Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(personnel.name,
                                      style: GCTypography.headlineSmall
                                          .copyWith(fontSize: 18),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                                '${personnel.age} years • ${personnel.experienceYears > 0 ? "${personnel.experienceYears}+" : "Fresh"} yrs experience',
                                style: GCTypography.bodySmall
                                    .copyWith(color: GCColors.mutedForeground)),
                            const SizedBox(height: 8),
                            // Rating and Reviews
                            Row(
                              children: [
                                _ratingStars(personnel.rating),
                                const SizedBox(width: 6),
                                Text(personnel.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                const SizedBox(width: 4),
                                Text('(${personnel.reviews.length} reviews)',
                                    style: GCTypography.bodySmall
                                        .copyWith(fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Badges Row
                  Row(
                    children: [
                      if (personnel.idVerified)
                        _badge(Icons.check_circle, 'ID Verified',
                            const Color(0xFFE3F2FD), const Color(0xFF1976D2)),
                      if (personnel.idVerified) const SizedBox(width: 8),
                      _visitsBadge(),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content (Dropdown)
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bio
                  if (personnel.bio.isNotEmpty) ...[
                    Text(personnel.bio,
                        style: GCTypography.bodySmall.copyWith(height: 1.5)),
                    const SizedBox(height: 20),
                  ],

                  // Languages
                  const Text('LANGUAGES',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: GCColors.mutedForeground,
                          letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Text(
                      personnel.languages.isNotEmpty
                          ? personnel.languages.join(', ')
                          : 'English',
                      style: GCTypography.bodyMedium
                          .copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 20),

                  // Key Skills
                  const Text('KEY SKILLS',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: GCColors.mutedForeground,
                          letterSpacing: 1)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: personnel.keySkills
                        .map((skill) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Text(skill,
                                  style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 24),

                  // Recent Review
                  if (personnel.reviews.isNotEmpty) ...[
                    const Text('Recent Review',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      constraints:
                          const BoxConstraints(minHeight: 128, maxHeight: 128),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  personnel.reviews.first['userName'] ?? 'User',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _ratingStars(
                                  (personnel.reviews.first['rating'] ?? 5)
                                      .toDouble()),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Text(
                              _limitWords(
                                (personnel.reviews.first['comment'] ??
                                        'Excellent service!')
                                    .toString(),
                                18,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: GCTypography.bodySmall,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(personnel.reviews.first['date'] ?? 'Recently',
                              style: GCTypography.bodySmall.copyWith(
                                  color: GCColors.mutedForeground,
                                  fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Selection Indicator
          if (isSelected && !isExpanded)
            Container(
              width: double.infinity,
              height: 4,
              decoration: const BoxDecoration(
                color: GCColors.primary,
                borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(GCSpacing.radiusLg)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: textColor, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _visitsBadge() {
    if (completedVisitsOverride != null) {
      return _badge(
        Icons.history,
        '$_effectiveVisits visits completed',
        const Color(0xFFFFF3E0),
        const Color(0xFFE65100),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('servicePersonnelId', isEqualTo: personnel.id)
          .where('status', isEqualTo: 'completed')
          .snapshots(),
      builder: (context, snapshot) {
        final completedFromBookings = snapshot.data?.docs.length ?? 0;
        final displayCount = completedFromBookings > _effectiveVisits
            ? completedFromBookings
            : _effectiveVisits;
        return _badge(
          Icons.history,
          '$displayCount visits completed',
          const Color(0xFFFFF3E0),
          const Color(0xFFE65100),
        );
      },
    );
  }

  Widget _ratingStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating.floor()
              ? Icons.star
              : (index < rating ? Icons.star_half : Icons.star_border),
          size: 16,
          color: Colors.orange,
        );
      }),
    );
  }
}
