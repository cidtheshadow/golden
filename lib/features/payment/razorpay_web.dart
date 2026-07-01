import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import 'payment_service.dart';
import '../../utils/error_handler.dart';

PaymentCheckoutService getPaymentCheckoutService() => RazorpayWebService();

@JS('Razorpay')
extension type _RazorpayJS._(JSObject _) implements JSObject {
  external factory _RazorpayJS(JSObject options);
  external void open();
  external void on(JSString event, JSFunction handler);
}

class RazorpayWebService implements PaymentCheckoutService {
  static const _scriptId = 'razorpay-js';

  @override
  void initialize() {
    if (web.document.getElementById(_scriptId) == null) {
      final script =
          web.document.createElement('script') as web.HTMLScriptElement;
      script.id = _scriptId;
      script.src = 'https://checkout.razorpay.com/v1/checkout.js';
      script.async = true;
      web.document.head!.appendChild(script);
    }
  }

  Future<void> _ensureCheckoutLoaded() async {
    initialize();

    // Give checkout.js a short window to initialize before creating the instance.
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  void dispose() {}

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
    try {
      await _ensureCheckoutLoaded();
    } catch (e) {
      onFailure(ErrorHandler.handle(e));
      return;
    }

    final handlerFn = ((JSAny response) {
      final res = response as JSObject;
      final paymentId = (res['razorpay_payment_id'] as JSString?)?.toDart ?? '';
      final razorpayOrderId =
          (res['razorpay_order_id'] as JSString?)?.toDart ?? orderId;
      final signature = (res['razorpay_signature'] as JSString?)?.toDart ?? '';

      onSuccess(paymentId, razorpayOrderId, signature);
    }).toJS;

    final modalDismissFn = (() {
      onFailure('Payment cancelled by user');
    }).toJS;

    // Build Razorpay options object using jsify for simple data
    // and setProperty for JS function callbacks
    final options = <String, Object>{
      'key': keyId,
      'order_id': orderId,
      'amount': amount,
      'currency': 'INR',
      'name': 'Golden Care',
      'description': description,
      'prefill': <String, Object>{
        'name': userName,
        'contact': userPhone,
        'email': userEmail,
      },
      'theme': <String, Object>{
        'color': '#B8860B',
      },
    }.jsify() as JSObject;

    options['handler'] = handlerFn;

    final modalObj = JSObject();
    modalObj['ondismiss'] = modalDismissFn;
    options['modal'] = modalObj;

    try {
      final rzp = _RazorpayJS(options);
      rzp.on(
        'payment.failed'.toJS,
        ((JSAny response) {
          final res = response as JSObject;
          final error = res['error'] as JSObject?;
          final desc =
              (error?['description'] as JSString?)?.toDart ?? 'Payment failed';
          onFailure(desc);
        }).toJS,
      );
      rzp.open();
    } catch (e) {
      onFailure("Could not launch Razorpay on web: ${ErrorHandler.handle(e)}");
    }
  }
}
