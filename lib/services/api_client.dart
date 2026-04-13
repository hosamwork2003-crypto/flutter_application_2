import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  final String baseUrl;
  ApiClient(this.baseUrl);

  static const _storage = FlutterSecureStorage();

  Future<String?> token() => _storage.read(key: 'token');

  Future<void> saveToken(String token) =>
      _storage.write(key: 'token', value: token);

  Future<void> clearToken() => _storage.delete(key: 'token');

  Future<Map<String, dynamic>> post(String path, Map body) async {
    final t = await token();
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        if (t != null) 'Authorization': 'Bearer $t',
      },
      body: jsonEncode(body),
    );

    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw Exception(data['error'] ?? 'Request failed');
    }
    return data;
  }

  Future<Map<String, dynamic>> get(String path) async {
    
    final t = await token();
    final res = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: {
        if (t != null) 'Authorization': 'Bearer $t',
      },
    );

    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw Exception(data['error'] ?? 'Request failed');
    }
    return data;
  }
  Future<Map<String, dynamic>> delete(String path) async {
  final t = await token();
  final res = await http.delete(
    Uri.parse('$baseUrl$path'),
    headers: {
      if (t != null) 'Authorization': 'Bearer $t',
    },
  );

  final data = jsonDecode(res.body);
  if (res.statusCode >= 400) {
    throw Exception(data['error'] ?? 'Request failed');
  }
  return data;
}
}