const test = require("node:test");
const assert = require("node:assert/strict");

const {
    computeRefundPolicy,
    determineCancellationTransition,
} = require("../lib/refund_logic");

test("computeRefundPolicy always applies partial refund for cancellation", () => {
    const now = new Date("2026-03-30T10:00:00.000Z");
    const booking = {
        startTime: {
            toDate: () => new Date("2026-03-31T10:00:00.000Z"),
        },
    };

    const result = computeRefundPolicy(10000, booking, now);

    assert.equal(result.isFullRefund, false);
    assert.equal(result.refundPercent, 75);
    assert.equal(result.refundAmountPaise, 7500);
    assert.equal(result.cancellationFeePaise, 2500);
});

test("computeRefundPolicy returns partial refund within threshold", () => {
    const now = new Date("2026-03-30T10:00:00.000Z");
    const booking = {
        startTime: {
            toDate: () => new Date("2026-03-30T20:00:00.000Z"),
        },
    };

    const result = computeRefundPolicy(10000, booking, now);

    assert.equal(result.isFullRefund, false);
    assert.equal(result.refundPercent, 75);
    assert.equal(result.refundAmountPaise, 7500);
    assert.equal(result.cancellationFeePaise, 2500);
});

test("determineCancellationTransition handles no transaction", () => {
    const result = determineCancellationTransition({
        booking: { status: "pending_payment", transactionId: null },
    });

    assert.equal(result.scenario, "no_transaction");
});

test("determineCancellationTransition handles missing provider payment id", () => {
    const result = determineCancellationTransition({
        booking: { status: "confirmed", transactionId: "tx_1" },
        transactionExists: true,
        transaction: { status: "captured", paymentStatus: "captured", amount: 12000 },
    });

    assert.equal(result.scenario, "provider_payment_id_missing");
});

test("determineCancellationTransition requires gateway refund when payment id exists", () => {
    const now = new Date("2026-03-30T10:00:00.000Z");
    const booking = {
        status: "confirmed",
        transactionId: "tx_1",
        startTime: {
            toDate: () => new Date("2026-03-30T16:00:00.000Z"),
        },
    };
    const transaction = {
        status: "captured",
        paymentStatus: "captured",
        amount: 10000,
        providerPaymentId: "pay_123",
    };

    const result = determineCancellationTransition({
        booking,
        transaction,
        transactionExists: true,
        now,
    });

    assert.equal(result.scenario, "gateway_refund_required");
    assert.equal(result.refundAmountPaise, 7500);
    assert.equal(result.refundPercent, 75);
    assert.equal(result.providerPaymentId, "pay_123");
});

test("determineCancellationTransition marks already_refunded", () => {
    const result = determineCancellationTransition({
        booking: { status: "confirmed", transactionId: "tx_1" },
        transactionExists: true,
        transaction: {
            status: "refunded",
            paymentStatus: "refunded",
            providerPaymentId: "pay_123",
            amount: 10000,
        },
    });

    assert.equal(result.scenario, "already_refunded");
});
