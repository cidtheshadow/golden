import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors.dart';
import '../../core/widgets/notification_bell.dart';
import '../auth/auth_controller.dart';

/// Partner shell: 3-tab bottom navigation (Dashboard | Bookings | Profile).
/// On desktop (≥768px): top AppBar with tab-style navigation items.
/// On mobile (<768px): traditional BottomNavigationBar.
class PartnerMainLayout extends ConsumerWidget {
  final Widget child;
  const PartnerMainLayout({super.key, required this.child});

  int _calculateIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/partner/bookings')) return 1;
    if (location.startsWith('/partner/profile')) return 2;
    return 0; // dashboard
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/partner/dashboard');
        break;
      case 1:
        context.go('/partner/bookings');
        break;
      case 2:
        context.go('/partner/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final currentIndex = _calculateIndex(context);

    Widget layout;
    if (isDesktop) {
      layout = _DesktopShell(
        currentIndex: currentIndex,
        onTap: (i) => _onItemTapped(i, context),
        ref: ref,
        child: child,
      );
    } else {
      layout = Scaffold(
        backgroundColor: GCColors.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 72,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: Colors.grey.shade200),
          ),
          title: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 42,
                  height: 42,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.health_and_safety, size: 42),
                ),
              ),
              const SizedBox(width: 12),
              const Text('GoldenCare Partner',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: 0.3,
                  )),
            ],
          ),
          actions: [
            const NotificationBell(
              notificationsRoute: '/partner/notifications',
            ),
            Container(
              width: 1,
              height: 28,
              margin: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
              color: Colors.grey.shade300,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await ref.read(authControllerProvider.notifier).signOut();
                  if (context.mounted) context.go('/');
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Logout',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GCColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
        body: child,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) => _onItemTapped(i, context),
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard),
                label: 'Dashboard'),
            BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today_outlined),
                activeIcon: Icon(Icons.calendar_today),
                label: 'Bookings'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile'),
          ],
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        if (currentIndex != 0) {
          context.go('/partner/dashboard');
        } else {
          context.go('/');
        }
      },
      child: layout,
    );
  }
}

class _DesktopShell extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Widget child;
  final WidgetRef ref;

  const _DesktopShell({
    required this.currentIndex,
    required this.onTap,
    required this.child,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GCColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 42,
                      height: 42,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.health_and_safety, size: 42),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('GoldenCare Partner',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: 0.3,
                      )),
                  const Spacer(),

                  // Nav tabs
                  _NavTab(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    selected: currentIndex == 0,
                    onTap: () => onTap(0),
                  ),
                  const SizedBox(width: 4),
                  _NavTab(
                    icon: Icons.calendar_today_outlined,
                    label: 'Bookings',
                    selected: currentIndex == 1,
                    onTap: () => onTap(1),
                  ),
                  const SizedBox(width: 4),
                  _NavTab(
                    icon: Icons.person_outline,
                    label: 'Profile',
                    selected: currentIndex == 2,
                    onTap: () => onTap(2),
                  ),
                  const SizedBox(width: 16),
                  const NotificationBell(
                    notificationsRoute: '/partner/notifications',
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    color: Colors.grey.shade300,
                  ),

                  // Sign out
                  ElevatedButton.icon(
                    onPressed: () async {
                      await ref.read(authControllerProvider.notifier).signOut();
                      if (context.mounted) context.go('/');
                    },
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Logout',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GCColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: child,
    );
  }
}

class _NavTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? GCColors.primary : Colors.grey.shade500,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? GCColors.primary : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: selected ? 40 : 0,
              decoration: BoxDecoration(
                color: GCColors.primary,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
