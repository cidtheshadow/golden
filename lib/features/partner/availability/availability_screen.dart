import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/availability_provider.dart';

class AvailabilityScreen extends ConsumerWidget {
  const AvailabilityScreen({super.key});

  static const _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  String _toDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(availabilityProvider);

    if (state.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Availability'),
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/partner/dashboard');
            }
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Available For Booking Today',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                      state.isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Switch(
                              value: state.isAvailable,
                              onChanged: (value) => ref
                                  .read(availabilityProvider.notifier)
                                  .toggleAvailability(value),
                            ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Turning this off blocks only today and will auto-reset tomorrow.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recurring Days Off',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: List.generate(_weekdays.length, (index) {
                      final selected =
                          state.unavailableWeekdays.contains(index);
                      final blocked = state.blockedWeekdays.contains(index);
                      return FilterChip(
                        label: Text(_weekdays[index]),
                        selected: selected,
                        avatar: (!selected && blocked)
                            ? const Icon(Icons.lock_outline, size: 16)
                            : null,
                        onSelected: (!selected && blocked)
                            ? null
                            : (_) => ref
                                .read(availabilityProvider.notifier)
                                .toggleUnavailableWeekday(index),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Weekdays with existing upcoming bookings are locked.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Specific Dates Off',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final today = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: today,
                            initialDate: today,
                            lastDate:
                                DateTime.now().add(const Duration(days: 90)),
                            selectableDayPredicate: (day) {
                              final key = _toDateKey(day);
                              return !state.bookedDates.contains(key);
                            },
                          );
                          if (picked == null) return;
                          final date = _toDateKey(picked);
                          ref
                              .read(availabilityProvider.notifier)
                              .toggleUnavailableDate(date);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Date'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (state.unavailableDates.isEmpty)
                    const Text('No specific dates selected')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: state.unavailableDates
                          .map(
                            (date) => Chip(
                              label: Text(date),
                              onDeleted: () => ref
                                  .read(availabilityProvider.notifier)
                                  .toggleUnavailableDate(date),
                            ),
                          )
                          .toList(),
                    ),
                  if (state.bookedDates.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Booked Dates (Cannot mark unavailable)',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: state.bookedDates
                          .take(10)
                          .map(
                            (date) => Chip(
                              avatar: const Icon(Icons.lock_outline, size: 16),
                              label: Text(date),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (state.error != null) ...[
            const SizedBox(height: 16),
            Text(
              state.error!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }
}
