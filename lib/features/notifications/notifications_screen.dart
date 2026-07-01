import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/providers/notification_provider.dart';
import '../../firebase/notification_service.dart';
import '../../models/notification_model.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _showUnreadOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await NotificationService().ensurePermissionWithPrompt(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final currentPath = GoRouterState.of(context).uri.path;
    final isPartner = currentPath.startsWith('/partner');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(isPartner ? '/partner/dashboard' : '/dashboard');
            }
          },
        ),
      ),
      body: SafeArea(
        child: notificationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(
            child: Text('Could not load notifications'),
          ),
          data: (allNotifications) {
            final notifications = _showUnreadOnly
                ? allNotifications.where((n) => !n.isRead).toList()
                : allNotifications;
            final unreadCount = allNotifications.where((n) => !n.isRead).length;

            if (allNotifications.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No notifications yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: !_showUnreadOnly,
                          onSelected: (_) =>
                              setState(() => _showUnreadOnly = false),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text('Unread ($unreadCount)'),
                          selected: _showUnreadOnly,
                          onSelected: (_) =>
                              setState(() => _showUnreadOnly = true),
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          onPressed: unreadCount == 0
                              ? null
                              : () async {
                                  await markAllNotificationsRead(
                                      allNotifications);
                                },
                          icon: const Icon(Icons.done_all_rounded, size: 18),
                          label: const Text('Mark all read'),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: notifications.isEmpty
                      ? const Center(child: Text('No unread notifications.'))
                      : ListView.separated(
                          itemCount: notifications.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, thickness: 0.6),
                          itemBuilder: (context, index) {
                            return _NotificationTile(
                              notification: notifications[index],
                              isPartner: isPartner,
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final bool isPartner;

  const _NotificationTile({
    required this.notification,
    required this.isPartner,
  });

  IconData _iconForType(String type) {
    switch (type) {
      case 'booking':
      case 'service_started':
      case 'service_completed':
        return Icons.calendar_month_rounded;
      case 'payment':
        return Icons.payments_rounded;
      case 'completion_requested':
        return Icons.verified_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return InkWell(
      onTap: () {
        markNotificationRead(notification);

        final bookingId = notification.bookingId;
        if (bookingId != null && bookingId.isNotEmpty) {
          final route = isPartner
              ? '/partner/booking-details/$bookingId'
              : '/booking-details/$bookingId';
          context.push(route);
        }
      },
      child: Container(
        color: isUnread
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.12),
              ),
              child: Icon(
                _iconForType(notification.type),
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight:
                                isUnread ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(notification.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}
