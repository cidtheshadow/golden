import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/slot_availability_provider.dart';
import '../../../core/colors.dart';

/// Groups time slots into Morning / Afternoon / Evening sections
/// with availability badges (High Demand = locked, N free = clickable).
class SlotPickerWidget extends ConsumerWidget {
  /// The date for which to load slots.
  final DateTime selectedDate;

  /// The booking service duration (used for overlap calculation).
  final Duration duration;

  /// Currently selected slot string, e.g. "09:00". Null if none selected.
  final String? selectedSlot;

  /// Called when the user taps a non-full slot.
  final ValueChanged<String> onSlotSelected;

  const SlotPickerWidget({
    super.key,
    required this.selectedDate,
    required this.duration,
    required this.selectedSlot,
    required this.onSlotSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(
      slotAvailabilityProvider((date: selectedDate, duration: duration)),
    );

    return slotsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Unable to load time slots. Please try again.',
            style: TextStyle(color: Colors.red.shade400),
          ),
        ),
      ),
      data: (slots) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeGroup(
            context,
            'Morning',
            slots.where((s) => _isMorning(s.time)).toList(),
          ),
          const SizedBox(height: 16),
          _buildTimeGroup(
            context,
            'Afternoon',
            slots.where((s) => _isAfternoon(s.time)).toList(),
          ),
          const SizedBox(height: 16),
          _buildTimeGroup(
            context,
            'Evening',
            slots.where((s) => _isEvening(s.time)).toList(),
          ),
        ],
      ),
    );
  }

  bool _isMorning(String t) {
    final h = int.parse(t.split(':')[0]);
    return h >= 8 && h < 12;
  }

  bool _isAfternoon(String t) {
    final h = int.parse(t.split(':')[0]);
    return h >= 12 && h < 17;
  }

  bool _isEvening(String t) {
    final h = int.parse(t.split(':')[0]);
    return h >= 17;
  }

  Widget _buildTimeGroup(
    BuildContext context,
    String label,
    List<SlotAvailability> slots,
  ) {
    if (slots.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF888888),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: slots
              .map((slot) => _SlotChip(
                    slot: slot,
                    isSelected: selectedSlot == slot.time,
                    onTap: slot.status == SlotStatus.highDemand
                        ? null
                        : () => onSlotSelected(slot.time),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _SlotChip extends StatelessWidget {
  final SlotAvailability slot;
  final bool isSelected;
  final VoidCallback? onTap;

  const _SlotChip({
    required this.slot,
    required this.isSelected,
    required this.onTap,
  });

  /// Converts "HH:mm" 24h string to a display label like "9:00 AM"
  String _formatTime(String t) {
    final parts = t.split(':');
    final hour = int.parse(parts[0]);
    final minute = parts[1];
    final period = hour < 12 ? 'AM' : 'PM';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$h12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final isHighDemand = slot.status == SlotStatus.highDemand;

    Color bgColor;
    Color borderColor;
    Color textColor;

    if (isSelected) {
      bgColor = GCColors.primary;
      borderColor = GCColors.primary;
      textColor = Colors.white;
    } else if (isHighDemand) {
      bgColor = const Color(0xFFFFF3E0);
      borderColor = const Color(0xFFFF9800);
      textColor = const Color(0xFF9E6700);
    } else {
      bgColor = Colors.white;
      borderColor = Colors.grey.shade300;
      textColor = const Color(0xFF1A1A1A);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isHighDemand) ...[
                  const Icon(Icons.lock_rounded,
                      size: 12, color: Color(0xFFFF9800)),
                  const SizedBox(width: 4),
                ],
                Text(
                  _formatTime(slot.time),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
            if (isHighDemand && !isSelected) ...[
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'High Demand',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
            if (!isHighDemand && !isSelected) ...[
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person,
                    size: 8,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${slot.availableCount} available',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
