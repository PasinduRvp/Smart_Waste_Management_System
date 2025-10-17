import 'dart:developer' as developer;

class AppLogger {
  static const String _baseTag = 'SmartWaste';

  static void debug(String message, [String? context]) {
    final tag = _buildTag(context);
    developer.log('🐛 DEBUG: $message', name: tag);
  }

  static void info(String message, [String? context]) {
    final tag = _buildTag(context);
    developer.log('ℹ️ INFO: $message', name: tag);
  }

  static void warning(String message, [String? context]) {
    final tag = _buildTag(context);
    developer.log('⚠️ WARNING: $message', name: tag);
  }

  static void error(String message, [String? context]) {
    final tag = _buildTag(context);
    developer.log('❌ ERROR: $message', name: tag);
  }

  static void success(String message, [String? context]) {
    final tag = _buildTag(context);
    developer.log('✅ SUCCESS: $message', name: tag);
  }

  static String _buildTag(String? context) {
    return context != null ? '$_baseTag:$context' : _baseTag;
  }
}