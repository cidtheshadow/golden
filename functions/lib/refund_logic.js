const DEFAULT_REFUND_POLICY = Object.freeze({
    partialRefundPercent: 75,
    platformFeePercent: 2,
});

const NON_CANCELLABLE_STATUSES = new Set([
    "cancelled",
    "completed",
    "caregiver_noshow",
    "expired",
]);

function toPaise(value) {
    const amount = Number(value || 0);
    if (!Number.isFinite(amount) || amount <= 0) {
        return 0;
    }
    return Math.round(amount);
}

function computeRefundPolicy(totalPaidPaise, booking, now = new Date(), policy = DEFAULT_REFUND_POLICY) {
    const safeTotalPaidPaise = toPaise(totalPaidPaise);
    const refundPercent = Number(policy.partialRefundPercent || 0);
    const isFullRefund = false;
    const refundAmountPaise = Math.max(0, Math.round((safeTotalPaidPaise * refundPercent) / 100));
    const cancellationFeePaise = Math.max(0, safeTotalPaidPaise - refundAmountPaise);
    const platformFeePaise = Math.max(
        0,
        Math.round(safeTotalPaidPaise * (policy.platformFeePercent / 100))
    );

    return {
        isFullRefund,
        refundPercent,
        refundAmountPaise,
        cancellationFeePaise,
        platformFeePaise,
    };
}

function determineCancellationTransition({
    booking = {},
    transaction = null,
    transactionExists = false,
    policy = DEFAULT_REFUND_POLICY,
    now = new Date(),
}) {
    const status = String(booking.status || "").toLowerCase();
    if (NON_CANCELLABLE_STATUSES.has(status)) {
        return { scenario: "already_cancelled" };
    }

    const bookingTransactionId = booking.transactionId || null;
    if (!bookingTransactionId) {
        return { scenario: "no_transaction" };
    }

    if (!transactionExists || !transaction) {
        return { scenario: "transaction_missing" };
    }

    const txStatus = String(transaction.status || "").toLowerCase();
    const txPaymentStatus = String(transaction.paymentStatus || "").toLowerCase();
    if (txStatus === "refunded" || txPaymentStatus === "refunded") {
        return { scenario: "already_refunded" };
    }

    const providerPaymentId = String(transaction.providerPaymentId || "").trim();
    if (!providerPaymentId) {
        return { scenario: "provider_payment_id_missing" };
    }

    const totalPaidPaise = toPaise(transaction.amount);
    const policyResult = computeRefundPolicy(totalPaidPaise, booking, now, policy);

    return {
        scenario: policyResult.refundAmountPaise > 0 ? "gateway_refund_required" : "refund_amount_zero",
        providerPaymentId,
        totalPaidPaise,
        ...policyResult,
    };
}

module.exports = {
    DEFAULT_REFUND_POLICY,
    NON_CANCELLABLE_STATUSES,
    computeRefundPolicy,
    determineCancellationTransition,
};
