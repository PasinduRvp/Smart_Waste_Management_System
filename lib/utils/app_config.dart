// lib/utils/app_config.dart
// Centralized configuration via compile-time environment variables.

class AppConfig {
  // Cloudinary
  static const String cloudinaryCloudName =
      String.fromEnvironment('CLOUDINARY_CLOUD_NAME', defaultValue: '');

  // If you are using unsigned uploads, provide an Upload Preset configured as unsigned in Cloudinary dashboard
  static const String cloudinaryUploadPreset =
      String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET', defaultValue: '');

  // DO NOT expose apiSecret in a client app. If you need signed uploads, proxy via your backend.

  // Optional: API base URL for your own backend if needed
  static const String apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static bool get isCloudinaryConfigured =>
      cloudinaryCloudName.isNotEmpty && cloudinaryUploadPreset.isNotEmpty;
}


