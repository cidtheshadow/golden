import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final allTransactionsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('transactions')
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(allTransactionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: const Text(
          'Transactions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
        ),
      ),
      body: SafeArea(
        child: txAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFB8860B),
            ),
          ),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                const SizedBox(height: 12),
                Text('Failed to load transactions: $e'),
              ],
            ),
          ),
          data: (transactions) {
            if (transactions.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 64,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No transactions yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your payment history will appear here',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: transactions.length,
              itemBuilder: (context, i) => _TransactionCard(
                tx: transactions[i],
                onTap: () => _showTransactionDetail(context, transactions[i]),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showTransactionDetail(
    BuildContext context,
    Map<String, dynamic> tx,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransactionDetailSheet(tx: tx),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final Map<String, dynamic> tx;
  final VoidCallback onTap;

  const _TransactionCard({
    required this.tx,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = _resolveStatus(tx);
    final amount = _getAmount(tx);
    final date = _getDate(tx['createdAt']);
    final bookingId =
        tx['referenceId'] as String? ?? tx['bookingId'] as String? ?? '';
    final provider = tx['provider'] as String? ?? 'razorpay';
    final (statusColor, statusLabel, statusIcon) = _getStatus(status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: statusColor.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(26),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
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
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          date,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          provider.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if ((tx['paymentMethod'] as String?)?.isNotEmpty ??
                          false) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              (tx['paymentMethod'] as String).toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade600,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  String _resolveStatus(Map<String, dynamic> tx) {
    final status = (tx['status'] as String? ?? '').trim();
    final paymentStatus = (tx['paymentStatus'] as String? ?? '').trim();
    final refundRetryPending = tx['refundRetryPending'] == true;

    if (refundRetryPending &&
        (status == 'refund_failed' || paymentStatus == 'refund_failed')) {
      return 'refund_retry_pending';
    }

    if (status.isEmpty) {
      return paymentStatus.isEmpty ? 'unknown' : paymentStatus;
    }

    const prefersPaymentStatusWhenPending = {
      'payment_initiated',
      'pending',
      'pending_payment',
    };

    if (prefersPaymentStatusWhenPending.contains(status) &&
        paymentStatus.isNotEmpty) {
      return paymentStatus;
    }

    return status;
  }

  double _getAmount(Map<String, dynamic> tx) {
    final display = tx['amountDisplay'];
    if (display != null) return (display as num).toDouble();
    final raw = tx['amount'];
    if (raw != null) return (raw as num).toDouble() / 100;
    return 0;
  }

  String _getDate(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      final months = [
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
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }

  (Color, String, IconData) _getStatus(String status) {
    switch (status) {
      case 'captured':
        return (const Color(0xFF2E7D32), 'Paid', Icons.check_circle_rounded);
      case 'failed':
        return (const Color(0xFFC62828), 'Failed', Icons.cancel_rounded);
      case 'refunded':
        return (const Color(0xFF1565C0), 'Refunded', Icons.replay_rounded);
      case 'refund_failed':
        return (
          const Color(0xFFC62828),
          'Refund Failed',
          Icons.error_rounded,
        );
      case 'refund_retry_pending':
        return (
          const Color(0xFFC62828),
          'Refund Failed (Retrying)',
          Icons.autorenew_rounded,
        );
      case 'refund_processing':
      case 'refund_initiated':
        return (
          const Color(0xFF1565C0),
          'Refund Processing',
          Icons.hourglass_top_rounded
        );
      case 'cancelled':
        return (Colors.grey, 'Cancelled', Icons.remove_circle_rounded);
      case 'payment_initiated':
        return (
          const Color(0xFFB8860B),
          'Processing',
          Icons.hourglass_bottom_rounded
        );
      default:
        return (const Color(0xFFB8860B), 'Pending', Icons.pending_rounded);
    }
  }
}

class _TransactionDetailSheet extends StatelessWidget {
  final Map<String, dynamic> tx;

  const _TransactionDetailSheet({required this.tx});

  @override
  Widget build(BuildContext context) {
    final status = _resolveStatus(tx);
    final amount = _getAmount();
    final txId = tx['id'] as String? ?? '';
    final providerOrderId = tx['providerOrderId'] as String? ?? '';
    final providerPaymentId = tx['providerPaymentId'] as String? ?? '';
    final bookingId =
        tx['referenceId'] as String? ?? tx['bookingId'] as String? ?? '';
    final provider = tx['provider'] as String? ?? 'razorpay';
    final createdAt = _getDate(tx['createdAt']);
    final capturedAt = _getDate(tx['capturedAt']);
    final metadata = tx['metadata'] as Map? ?? {};
    final refundId = tx['refundId'] as String?;
    final refundAmount = tx['refundAmount'];
    final refundFailReason = tx['refundFailReason'] as String?;
    final refundRetryPending = tx['refundRetryPending'] == true;
    final refundNextRetryAt = _getDate(tx['refundNextRetryAt']);
    final paymentMethod = tx['paymentMethod'] as String? ??
        tx['method'] as String? ??
        (metadata['method'] as String?) ??
        (metadata['paymentMethod'] as String?);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F0E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '₹${amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _StatusBadge(status: status),
                  ],
                ),
              ),
              _DetailRow(
                label: 'Transaction ID',
                value: txId,
                copyable: true,
                icon: Icons.tag_rounded,
              ),
              if (providerOrderId.isNotEmpty)
                _DetailRow(
                  label: 'Order ID',
                  value: providerOrderId,
                  copyable: true,
                  icon: Icons.receipt_outlined,
                ),
              if (providerPaymentId.isNotEmpty)
                _DetailRow(
                  label: 'Payment ID',
                  value: providerPaymentId,
                  copyable: true,
                  icon: Icons.payment_rounded,
                ),
              _DetailRow(
                label: 'Booking ID',
                value: bookingId,
                copyable: true,
                icon: Icons.bookmark_rounded,
              ),
              _DetailRow(
                label: 'Amount',
                value: '₹${amount.toStringAsFixed(2)}',
                icon: Icons.currency_rupee_rounded,
              ),
              _DetailRow(
                label: 'Provider',
                value: provider.toUpperCase(),
                icon: Icons.account_balance_rounded,
              ),
              if (paymentMethod != null && paymentMethod.isNotEmpty)
                _DetailRow(
                  label: 'Payment Mode',
                  value: paymentMethod.toUpperCase(),
                  icon: Icons.credit_card_rounded,
                ),
              if (metadata['serviceName'] != null ||
                  metadata['serviceType'] != null)
                _DetailRow(
                  label: 'Service',
                  value:
                      (metadata['serviceName'] ?? metadata['serviceType'] ?? '')
                          .toString(),
                  icon: Icons.medical_services_rounded,
                ),
              if (metadata['bookingDate'] != null)
                _DetailRow(
                  label: 'Booking Date',
                  value: () {
                    final bd = metadata['bookingDate'];
                    if (bd is Timestamp) {
                      final dt = bd.toDate();
                      const months = [
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
                      ];
                      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
                    }
                    if (bd is String && bd.isNotEmpty) return bd;
                    return '—';
                  }(),
                  icon: Icons.calendar_today_rounded,
                ),
              _DetailRow(
                label: 'Created',
                value: createdAt,
                icon: Icons.access_time_rounded,
              ),
              if (capturedAt.isNotEmpty)
                _DetailRow(
                  label: 'Paid At',
                  value: capturedAt,
                  icon: Icons.check_circle_rounded,
                ),
              if (refundId != null) ...[
                const Divider(height: 24),
                _DetailRow(
                  label: 'Refund ID',
                  value: refundId,
                  copyable: true,
                  icon: Icons.replay_rounded,
                ),
                if (refundAmount != null)
                  _DetailRow(
                    label: 'Refund Amount',
                    value:
                        '₹${((refundAmount as num) / 100).toStringAsFixed(2)}',
                    icon: Icons.currency_rupee_rounded,
                  ),
              ],
              if (refundFailReason != null && refundFailReason.isNotEmpty)
                _DetailRow(
                  label: 'Refund Status',
                  value: 'FAILED: $refundFailReason',
                  icon: Icons.error_outline_rounded,
                ),
              if (refundRetryPending)
                _DetailRow(
                  label: 'Retry Queue',
                  value: refundNextRetryAt.isNotEmpty
                      ? 'Queued - next attempt at $refundNextRetryAt'
                      : 'Queued - retry attempt pending',
                  icon: Icons.autorenew_rounded,
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _resolveStatus(Map<String, dynamic> tx) {
    final status = (tx['status'] as String? ?? '').trim();
    final paymentStatus = (tx['paymentStatus'] as String? ?? '').trim();
    final refundRetryPending = tx['refundRetryPending'] == true;

    if (refundRetryPending &&
        (status == 'refund_failed' || paymentStatus == 'refund_failed')) {
      return 'refund_retry_pending';
    }

    if (status.isEmpty) {
      return paymentStatus;
    }

    const prefersPaymentStatusWhenPending = {
      'payment_initiated',
      'pending',
      'pending_payment',
    };

    if (prefersPaymentStatusWhenPending.contains(status) &&
        paymentStatus.isNotEmpty) {
      return paymentStatus;
    }

    return status;
  }

  double _getAmount() {
    final display = tx['amountDisplay'];
    if (display != null) return (display as num).toDouble();
    final raw = tx['amount'];
    if (raw != null) return (raw as num).toDouble() / 100;
    return 0;
  }

  String _getDate(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      final months = [
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
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = _statusMeta(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  (Color, String) _statusMeta(String s) {
    switch (s) {
      case 'captured':
        return (const Color(0xFF2E7D32), 'Paid');
      case 'failed':
        return (const Color(0xFFC62828), 'Failed');
      case 'refunded':
        return (const Color(0xFF1565C0), 'Refunded');
      case 'refund_failed':
        return (const Color(0xFFC62828), 'Refund Failed');
      case 'refund_retry_pending':
        return (const Color(0xFFC62828), 'Refund Failed (Retrying)');
      case 'refund_processing':
      case 'refund_initiated':
        return (const Color(0xFF1565C0), 'Refund Processing');
      case 'cancelled':
        return (Colors.grey, 'Cancelled');
      default:
        return (const Color(0xFFB8860B), 'Pending');
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;
  final IconData? icon;

  const _DetailRow({
    required this.label,
    required this.value,
    this.copyable = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          SizedBox(
            width: 28,
            child: icon != null
                ? Icon(icon, size: 16, color: const Color(0xFFB8860B))
                : const SizedBox.shrink(),
          ),
          // Label
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ),
          // Value
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          // Copy button
          if (copyable && value.isNotEmpty)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label copied'),
                    duration: const Duration(seconds: 1),
                    backgroundColor: const Color(0xFFB8860B),
                  ),
                );
              },
              child: Icon(
                Icons.copy_rounded,
                size: 15,
                color: Colors.grey.shade400,
              ),
            ),
        ],
      ),
    );
  }
}
