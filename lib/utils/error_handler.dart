import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class ErrorHandler {
  static String handle(dynamic error) {
    if (error is FirebaseAuthException) {
      return _handleAuthException(error);
    } else if (error is FirebaseException) {
      return _handleFirebaseException(error);
    } else if (error is PlatformException) {
      return _handlePlatformException(error);
    } else if (error is Exception) {
      return _handleGenericException(error);
    } else if (error is Error) {
      return _handleDartError(error);
    } else if (error is String) {
      return error;
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  static String _handleDartError(Error e) {
    final message = e.toString();
    return message.isEmpty
        ? 'An unexpected error occurred. Please try again.'
        : message;
  }

  static String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'credential-already-in-use':
        return 'This credential is already linked to another account.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email. Please sign in with your original method.';
      case 'popup-closed-by-user':
        return 'Sign-in popup was closed. Please try again.';
      case 'cancelled-popup-request':
        return 'Another sign-in popup is already open.';
      case 'popup-blocked':
        return 'Sign-in popup was blocked by the browser. Please allow popups for this site.';
      case 'invalid-verification-code':
        return 'The OTP entered is incorrect. Please try again.';
      case 'invalid-verification-id':
        return 'The verification session expired. Please request a new OTP.';
      case 'session-expired':
        return 'The sms code has expired. Please re-send the verification code to try again.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }

  static String _handleFirebaseException(FirebaseException e) {
    switch (e.code) {
      case 'unauthenticated':
        return 'Session expired. Please sign in again.';
      case 'permission-denied':
        return 'You do not have permission to perform this action.';
      case 'unavailable':
        return 'Service currently unavailable. Please check your internet connection.';
      case 'not-found':
        return 'The requested resource was not found.';
      case 'already-exists':
        return 'The resource already exists.';
      case 'cancelled':
        return 'The operation was cancelled.';
      case 'deadline-exceeded':
        return 'The operation timed out. Please try again.';
      default:
        return e.message ?? 'A database error occurred.';
    }
  }

  static String _handlePlatformException(PlatformException e) {
    switch (e.code) {
      case 'network_error':
        return 'Network error. Please check your connection.';
      case 'sign_in_failed':
        return 'Sign in cancelled or failed.';
      default:
        // Try to be generic and not expose low-level details.
        return 'An error occurred during operation. Please try again.';
    }
  }

  static String _handleGenericException(Exception e) {
    final message = e.toString();
    // Strip the "Exception: " prefix if present.
    if (message.startsWith('Exception: ')) {
      return message.substring(11);
    }
    return message;
  }
}
