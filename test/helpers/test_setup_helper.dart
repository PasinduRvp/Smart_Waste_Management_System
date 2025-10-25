// File: test/helpers/test_setup_helper.dart

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class TestSetupHelper {
  static void setupAllMocks() {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Mock path_provider (needed for GetStorage)
    _mockPathProvider();

    // Mock Firebase services
    _mockFirebaseCore();
    _mockFirebaseAuth();
    _mockFirebaseFirestore();
    _mockFirebaseStorage();
    _mockFirebaseMessaging();
  }

  static void _mockPathProvider() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getApplicationDocumentsDirectory':
            return '/tmp/test_documents';
          case 'getTemporaryDirectory':
            return '/tmp/test_temp';
          case 'getApplicationSupportDirectory':
            return '/tmp/test_support';
          default:
            return null;
        }
      },
    );
  }

  static void _mockFirebaseCore() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_core'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'Firebase#initializeCore') {
          return [
            {
              'name': '[DEFAULT]',
              'options': {
                'apiKey': 'test-api-key',
                'appId': 'test-app-id',
                'messagingSenderId': 'test-sender-id',
                'projectId': 'test-project-id',
                'storageBucket': 'test-bucket',
              },
              'pluginConstants': {},
            }
          ];
        }
        if (methodCall.method == 'Firebase#initializeApp') {
          return {
            'name': methodCall.arguments['appName'],
            'options': methodCall.arguments['options'],
            'pluginConstants': {},
          };
        }
        return null;
      },
    );
  }

  static void _mockFirebaseAuth() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_auth'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'Auth#registerIdTokenListener':
            return {'name': '[DEFAULT]'};
          case 'Auth#registerAuthStateListener':
            return {'name': '[DEFAULT]'};
          default:
            return null;
        }
      },
    );
  }

  static void _mockFirebaseFirestore() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/cloud_firestore'),
      (MethodCall methodCall) async {
        return null;
      },
    );
  }

  static void _mockFirebaseStorage() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_storage'),
      (MethodCall methodCall) async {
        return null;
      },
    );
  }

  static void _mockFirebaseMessaging() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_messaging'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'Messaging#getToken':
            return 'test-fcm-token';
          default:
            return null;
        }
      },
    );
  }

  static void cleanupMocks() {
    // Reset all mock handlers
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_core'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_auth'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/cloud_firestore'),
      null,
    );
  }
}