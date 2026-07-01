import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../firebase/notification_service.dart';
import '../providers/notification_provider.dart';

class NotificationBell extends ConsumerWidget {
  final String notificationsRoute;

  const NotificationBell({
    super.key,
    required this.notificationsRoute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(unreadCountProvider);
    Future<void> openNotifications() async {
      await NotificationService().ensurePermissionWithPrompt(context);
      if (!context.mounted) return;
      context.go(notificationsRoute);
    }

    return countAsync.when(
      loading: () => IconButton(
        icon: const Icon(Icons.notifications_outlined),
        onPressed: openNotifications,
      ),
      error: (_, __) => IconButton(
        icon: const Icon(Icons.notifications_outlined),
        onPressed: openNotifications,
      ),
      data: (count) {
        final displayCount = count > 99 ? '99+' : '$count';
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                count > 0
                    ? Icons.notifications_rounded
                    : Icons.notifications_outlined,
              ),
              onPressed: openNotifications,
            ),
            if (count > 0)
              Positioned(
                right: 4,
                top: 5,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 16,
                  ),
                  child: Text(
                    displayCount,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
