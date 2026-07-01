import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'payment_service.dart';
import '../../utils/error_handler.dart';

PaymentCheckoutService getPaymentCheckoutService() => RazorpayMobileService();

class RazorpayMobileService implements PaymentCheckoutService {
  late Razorpay _razorpay;
  void Function(String, String, String)? _onSuccess;
  void Function(String)? _onFailure;

  @override
  void initialize() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      _onSuccess?.call(r.paymentId ?? '', r.orderId ?? '', r.signature ?? '');
    });
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      _onFailure?.call(r.message ?? 'Unknown Error');
    });
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
      _onFailure?.call('External Wallet not supported : ${r.walletName}');
    });
  }

  @override
  void dispose() {
    _razorpay.clear();
  }

  @override
  Future<void> openCheckout({
    required String keyId,
    required String orderId,
    required int amount,
    required String userEmail,
    required String userName,
    required String userPhone,
    required String description,
    required void Function(String paymentId, String orderId, String signature)
        onSuccess,
    required void Function(String errorMessage) onFailure,
  }) async {
    _onSuccess = onSuccess;
    _onFailure = onFailure;

    final options = {
      'key': keyId,
      'order_id': orderId,
      'amount': amount,
      'currency': 'INR',
      'name': 'Golden Care',
      'description': description,
      'prefill': {
        'name': userName,
        'contact': userPhone,
        'email': userEmail,
      },
    };
    try {
      _razorpay.open(options);
    } catch (e) {
      _onFailure?.call(ErrorHandler.handle(e));
    }
  }
}
