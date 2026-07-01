import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Streams the current user's recent transactions from Firestore.
final paymentHistoryProvider = StreamProvider<List<Map<String, dynamic>>>(
  (ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('transactions')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
        );
  },
);

class PaymentHistoryWidget extends ConsumerWidget {
  const PaymentHistoryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(paymentHistoryProvider);

    return history.when(
      loading: () => const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (transactions) {
        if (transactions.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'Payment History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
            ...transactions.map((tx) => _PaymentTile(tx: tx)),
          ],
        );
      },
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final Map<String, dynamic> tx;

  const _PaymentTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final status = tx['status'] as String? ?? 'unknown';
    final amountRaw =
        tx['amountDisplay'] ?? (((tx['amount'] as num?) ?? 0) / 100);
    final amount = amountRaw is num
        ? amountRaw.toDouble()
        : double.tryParse(amountRaw.toString()) ?? 0;
    final createdAt = tx['createdAt'];
    final txId = tx['id'] as String? ?? '';
    final bookingId =
        tx['referenceId'] as String? ?? tx['bookingId'] as String? ?? '';

    String dateStr = '';
    if (createdAt is Timestamp) {
      final dt = createdAt.toDate();
      dateStr = '${dt.day} ${_month(dt.month)} ${dt.year}';
    }

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'captured':
      case 'paid':
        statusColor = const Color(0xFF2E7D32);
        statusLabel = 'Paid';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'failed':
        statusColor = const Color(0xFFC62828);
        statusLabel = 'Failed';
        statusIcon = Icons.cancel_rounded;
        break;
      case 'refunded':
        statusColor = const Color(0xFF1565C0);
        statusLabel = 'Refunded';
        statusIcon = Icons.replay_rounded;
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        statusLabel = 'Cancelled';
        statusIcon = Icons.remove_circle_rounded;
        break;
      case 'refund_initiated':
        statusColor = const Color(0xFF1565C0);
        statusLabel = 'Refund Processing';
        statusIcon = Icons.hourglass_top_rounded;
        break;
      default:
        statusColor = const Color(0xFFB8860B);
        statusLabel = 'Pending';
        statusIcon = Icons.hourglass_bottom_rounded;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INR ${amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: bookingId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Booking ID copied'),
                        duration: Duration(seconds: 1),
                        backgroundColor: Color(0xFFB8860B),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Booking #$bookingId',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      Icon(
                        Icons.copy_rounded,
                        size: 12,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
                if (dateStr.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
                if (txId.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: txId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Transaction ID copied'),
                          duration: Duration(seconds: 1),
                          backgroundColor: Color(0xFFB8860B),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Txn: $txId',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade400,
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        Icon(
                          Icons.copy_rounded,
                          size: 12,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _month(int m) => [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][m];
}
