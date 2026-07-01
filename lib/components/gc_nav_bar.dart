import 'package:flutter/material.dart';

class GCNavBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const GCNavBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      centerTitle: true,
      elevation: 0,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
