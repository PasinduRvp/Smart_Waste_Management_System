import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Base Exception Class
class AppException implements Exception {
  final String message;
  final String code;
  final dynamic originalException;

  AppException({
    required this.message,
    this.code = 'UNKNOWN_ERROR',
    this.originalException,
  });

  @override
  String toString() => 'AppException: $message (Code: $code)';
}

// Specific Exception Types
class ValidationException extends AppException {
  ValidationException({required super.message})
      : super(code: 'VALIDATION_ERROR');
}

class NotFoundException extends AppException {
  NotFoundException({required super.message})
      : super(code: 'NOT_FOUND');
}

class NetworkException extends AppException {
  NetworkException({required super.message})
      : super(code: 'NETWORK_ERROR');
}

class ServerException extends AppException {
  ServerException({required super.message})
      : super(code: 'SERVER_ERROR');
}

class UnauthorizedException extends AppException {
  UnauthorizedException({required super.message})
      : super(code: 'UNAUTHORIZED');
}

// ErrorHandler Class - This is what was missing!
class ErrorHandler {
  /// Parses any exception and converts it to an AppException
  static AppException parseException(dynamic error) {
    // Firebase Auth Exceptions
    if (error is FirebaseAuthException) {
      return _handleFirebaseAuthException(error);
    }
    
    // Firestore Exceptions
    if (error is FirebaseException) {
      return _handleFirestoreException(error);
    }
    
    // Already an AppException
    if (error is AppException) {
      return error;
    }
    
    // Generic Exception
    return AppException(
      message: error.toString(),
      code: 'UNKNOWN_ERROR',
      originalException: error,
    );
  }

  /// Handles Firebase Authentication exceptions
  static AppException _handleFirebaseAuthException(FirebaseAuthException e) {
    String message;
    
    switch (e.code) {
      case 'user-not-found':
        message = 'No user found with this email.';
        break;
      case 'wrong-password':
        message = 'Incorrect password.';
        break;
      case 'email-already-in-use':
        message = 'This email is already registered.';
        break;
      case 'weak-password':
        message = 'Password is too weak. Use at least 6 characters.';
        break;
      case 'invalid-email':
        message = 'Invalid email address format.';
        break;
      case 'user-disabled':
        message = 'This account has been disabled.';
        break;
      case 'operation-not-allowed':
        message = 'Operation not allowed. Please contact support.';
        break;
      case 'network-request-failed':
        message = 'Network error. Please check your internet connection.';
        break;
      case 'too-many-requests':
        message = 'Too many attempts. Please try again later.';
        break;
      case 'invalid-credential':
        message = 'Invalid credentials provided.';
        break;
      case 'account-exists-with-different-credential':
        message = 'An account already exists with a different sign-in method.';
        break;
      default:
        message = e.message ?? 'Authentication error occurred.';
    }
    
    return AppException(
      message: message,
      code: e.code,
      originalException: e,
    );
  }

  /// Handles Firestore exceptions
  static AppException _handleFirestoreException(FirebaseException e) {
    String message;
    
    switch (e.code) {
      case 'permission-denied':
        message = 'You do not have permission to perform this action.';
        break;
      case 'unavailable':
        message = 'Service is currently unavailable. Please try again.';
        break;
      case 'not-found':
        message = 'Requested resource not found.';
        break;
      case 'already-exists':
        message = 'Resource already exists.';
        break;
      case 'deadline-exceeded':
        message = 'Request timed out. Please try again.';
        break;
      case 'cancelled':
        message = 'Operation was cancelled.';
        break;
      case 'data-loss':
        message = 'Data loss occurred. Please contact support.';
        break;
      case 'unauthenticated':
        message = 'Please sign in to continue.';
        break;
      case 'aborted':
        message = 'Operation was aborted. Please try again.';
        break;
      case 'out-of-range':
        message = 'Operation was attempted past the valid range.';
        break;
      case 'unimplemented':
        message = 'Operation is not implemented or supported.';
        break;
      case 'internal':
        message = 'Internal server error occurred.';
        break;
      case 'resource-exhausted':
        message = 'Resource quota exceeded. Please try again later.';
        break;
      case 'failed-precondition':
        message = 'Operation rejected due to system state.';
        break;
      case 'invalid-argument':
        message = 'Invalid data provided.';
        break;
      default:
        message = e.message ?? 'Database error occurred.';
    }
    
    return AppException(
      message: message,
      code: e.code,
      originalException: e,
    );
  }

  /// Get error message from any exception
  static String getErrorMessage(dynamic error) {
    return parseException(error).message;
  }

  /// Get error code from any exception
  static String getErrorCode(dynamic error) {
    return parseException(error).code;
  }

  /// Check if error is a network error
  static bool isNetworkError(dynamic error) {
    final exception = parseException(error);
    return exception.code == 'NETWORK_ERROR' || 
           exception.code == 'network-request-failed' ||
           exception.code == 'unavailable';
  }

  /// Check if error is an authentication error
  static bool isAuthError(dynamic error) {
    final exception = parseException(error);
    return exception.code.contains('auth') || 
           exception.code == 'UNAUTHORIZED' ||
           exception.code == 'unauthenticated';
  }

  /// Check if error is a permission error
  static bool isPermissionError(dynamic error) {
    final exception = parseException(error);
    return exception.code == 'permission-denied' ||
           exception.code == 'UNAUTHORIZED';
  }
}