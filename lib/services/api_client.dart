import 'dart:convert';
import 'dart:io';

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

  Future<Map<String, dynamic>> multipartPost(
    String path, {
    Map<String, String>? fields,
    Map<String, File>? files,
  }) async {
    final t = await token();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl$path'),
    );

    if (t != null && t.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $t';
    }

    if (fields != null) {
      request.fields.addAll(fields);
    }

    if (files != null) {
      for (final entry in files.entries) {
        request.files.add(
          await http.MultipartFile.fromPath(
            entry.key,
            entry.value.path,
            filename: entry.value.path.split(Platform.pathSeparator).last,
          ),
        );
      }
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      data = {'raw': response.body};
    }

    if (response.statusCode >= 400) {
      if (data is Map<String, dynamic>) {
        throw Exception(data['error'] ?? data['message'] ?? 'Request failed');
      }
      throw Exception('Request failed');
    }

    if (data is Map<String, dynamic>) {
      return data;
    }

    return {'data': data};
  }
}