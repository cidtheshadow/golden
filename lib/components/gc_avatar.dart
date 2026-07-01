import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/colors.dart';

class GCAvatar extends StatelessWidget {
  final String? url;
  final double radius;

  const GCAvatar({super.key, this.url, this.radius = 24.0});

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim() ?? '';

    if (imageUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: GCColors.secondary,
        child: const Icon(Icons.person, color: GCColors.mutedForeground),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: GCColors.secondary,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            color: GCColors.secondary,
            alignment: Alignment.center,
            child: const Icon(Icons.person, color: GCColors.mutedForeground),
          ),
          errorWidget: (_, __, ___) => Container(
            color: GCColors.secondary,
            alignment: Alignment.center,
            child: const Icon(Icons.person, color: GCColors.mutedForeground),
          ),
        ),
      ),
    );
  }
}
