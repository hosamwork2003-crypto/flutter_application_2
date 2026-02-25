import 'api_client.dart';

class AuthApi {
  final ApiClient api;
  AuthApi(this.api);

  Future<void> register(String name, String email, String password) async {
    final data = await api.post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
    });
    await api.saveToken(data['token']);
  }

  Future<void> login(String email, String password) async {
    final data = await api.post('/auth/login', {
      'email': email,
      'password': password,
    });
    await api.saveToken(data['token']);
  }

  Future<Map<String, dynamic>> me() async {
    final data = await api.get('/me');
    return data['user'] as Map<String, dynamic>;
  }
  Future<Map<String, dynamic>> updateProfile({
  String? fullName,
  String? academicLevel,
  String? birthDate, // YYYY-MM-DD
}) async {
  final data = await api.post('/profile/update', {
    'full_name': fullName,
    'academic_level': academicLevel,
    'birth_date': birthDate,
  });
  return data['user'] as Map<String, dynamic>;
}

Future<Map<String, dynamic>> updateAvatarBase64(String base64) async {
  final data = await api.post('/profile/avatar', {
    'avatar_base64': base64,
  });
  return data['user'] as Map<String, dynamic>;
}

  Future<void> logout() async {
    await api.clearToken();
  }
}