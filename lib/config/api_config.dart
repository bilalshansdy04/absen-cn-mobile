import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiConfig {
  static const _storage = FlutterSecureStorage();
  static const _baseUrlKey = 'api_base_url';
  static const String _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://absen-cn-web-admin.vercel.app',
  );

  static String? baseUrlOverride;

  static Future<String> getBaseUrl() async {
    if (baseUrlOverride != null) return baseUrlOverride!;
    try {
      final saved = await _storage.read(key: _baseUrlKey);
      if (saved != null && saved.trim().isNotEmpty) {
        return saved.trim().replaceAll(RegExp(r'/$'), '');
      }
    } catch (_) {}
    return _defaultBaseUrl.replaceAll(RegExp(r'/$'), '');
  }

  static Future<void> setBaseUrl(String url) async {
    final cleaned = url.trim().replaceAll(RegExp(r'/$'), '');
    if (cleaned.isEmpty) {
      await _storage.delete(key: _baseUrlKey);
    } else {
      await _storage.write(key: _baseUrlKey, value: cleaned);
    }
  }
}
