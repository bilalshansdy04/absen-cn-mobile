import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  ApiException(this.message, {this.statusCode, this.code});

  @override
  String toString() => message;
}

class ApiService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'presensi_jwt_token';

  /// Dapat di-override dengan MockClient saat pengujian E2E.
  static http.Client httpClient = http.Client();
  static String? inMemoryTokenOverride;
  static bool skipSecureStorage = false;

  static Future<String?> getToken() async {
    if (inMemoryTokenOverride != null) return inMemoryTokenOverride;
    if (skipSecureStorage) return null;
    return _storage.read(key: _tokenKey);
  }

  static Future<void> saveToken(String token) async {
    inMemoryTokenOverride = token;
    if (skipSecureStorage) return;
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (_) {}
  }

  static Future<void> clearToken() async {
    inMemoryTokenOverride = null;
    if (skipSecureStorage) return;
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static dynamic _decodeResponse(http.Response res) {
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }
    final err = (body is Map && body['error'] != null)
        ? body['error'].toString()
        : 'Terjadi kesalahan (HTTP ${res.statusCode})';
    final code =
        (body is Map && body['code'] != null) ? body['code'].toString() : null;
    throw ApiException(err, statusCode: res.statusCode, code: code);
  }

  static Future<Map<String, dynamic>> login(
    String employeeCode,
    String password,
  ) async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final res = await httpClient.post(
      Uri.parse('$baseUrl/api/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'employee_code': employeeCode.trim().toUpperCase(),
        'password': password,
        'client': 'mobile',
      }),
    );
    final data = _decodeResponse(res) as Map<String, dynamic>;
    if (data['token'] != null) {
      await saveToken(data['token'].toString());
    }
    return data;
  }

  static Future<Map<String, dynamic>> getMe() async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final res = await httpClient.get(
      Uri.parse('$baseUrl/api/v1/auth/me'),
      headers: await _authHeaders(),
    );
    return _decodeResponse(res) as Map<String, dynamic>;
  }

  static Future<void> changePassword(String newPassword) async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final res = await httpClient.post(
      Uri.parse('$baseUrl/api/v1/auth/change-password'),
      headers: await _authHeaders(),
      body: jsonEncode({'new_password': newPassword}),
    );
    _decodeResponse(res);
  }

  static Future<Map<String, dynamic>> getAttendanceStatus({
    int days = 30,
  }) async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final res = await httpClient.get(
      Uri.parse('$baseUrl/api/v1/attendance/status?days=$days'),
      headers: await _authHeaders(),
    );
    return _decodeResponse(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> submitAttendance({
    required String action, // 'check-in' or 'check-out'
    required File photoFile,
    required double lat,
    required double lng,
    required String address,
  }) async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/api/v1/attendance/$action');

    final request = http.MultipartRequest('POST', uri);
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields['lat'] = lat.toString();
    request.fields['lng'] = lng.toString();
    request.fields['address'] = address;
    request.files.add(
      await http.MultipartFile.fromPath('photo', photoFile.path),
    );

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _decodeResponse(res) as Map<String, dynamic>;
  }
}
