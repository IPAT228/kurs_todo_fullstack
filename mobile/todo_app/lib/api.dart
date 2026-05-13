import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'models/session_user.dart';
import 'models/task.dart';

/// Сессия истекла или токен недействителен.
class UnauthorizedException implements Exception {
  @override
  String toString() => 'Требуется повторный вход';
}

String normalizeApiBase(String url) {
  var s = url.trim();
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// Базовый URL API. Для Android-эмулятора часто нужен http://10.0.2.2:8000
class TodoApi {
  TodoApi({required String baseUrl, FlutterSecureStorage? storage})
      : baseUrl = normalizeApiBase(baseUrl),
        _storage = storage ?? const FlutterSecureStorage();

  String baseUrl;
  final FlutterSecureStorage _storage;
  static const _tokenKey = 'access_token';
  static const _emailKey = 'user_email';
  static const _baseUrlKey = 'api_base_url';
  static const _roleKey = 'user_role';
  static const _userIdKey = 'user_id';

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _roleKey);
    await _storage.delete(key: _userIdKey);
  }

  Future<void> saveEmail(String email) => _storage.write(key: _emailKey, value: email);

  Future<String?> getSavedEmail() => _storage.read(key: _emailKey);

  Future<void> clearSavedEmail() => _storage.delete(key: _emailKey);

  Future<void> saveBaseUrl(String url) =>
      _storage.write(key: _baseUrlKey, value: normalizeApiBase(url));

  Future<String?> getSavedBaseUrl() => _storage.read(key: _baseUrlKey);

  Future<void> clearSavedBaseUrl() => _storage.delete(key: _baseUrlKey);

  Map<String, String> _headers(String? token) {
    final h = {'Content-Type': 'application/json'};
    if (token != null) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  void _throwIfUnauthorized(http.Response r) {
    if (r.statusCode == 401) {
      throw UnauthorizedException();
    }
  }

  Future<bool> isAdmin() async {
    final role = await _storage.read(key: _roleKey);
    return role == 'admin';
  }

  Future<int?> storedUserId() async {
    final s = await _storage.read(key: _userIdKey);
    if (s == null || s.isEmpty) {
      return null;
    }
    return int.tryParse(s);
  }

  /// Загрузить роль и id из `/auth/me` (нужно после входа и при старте с сохранённым токеном).
  Future<SessionUser> fetchMe() async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Нет токена');
    }
    final r = await http.get(Uri.parse('$baseUrl/auth/me'), headers: _headers(token));
    _throwIfUnauthorized(r);
    if (r.statusCode != 200) {
      throw Exception('Профиль (${r.statusCode}): ${r.body}');
    }
    final user = SessionUser.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    await _storage.write(key: _roleKey, value: user.role);
    await _storage.write(key: _userIdKey, value: '${user.id}');
    return user;
  }

  Future<void> register({required String email, required String password}) async {
    final r = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers(null),
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (r.statusCode != 201 && r.statusCode != 400) {
      throw Exception('Ошибка регистрации (${r.statusCode}): ${r.body}');
    }
  }

  Future<void> login({required String email, required String password}) async {
    final r = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': email, 'password': password},
    );
    if (r.statusCode != 200) {
      throw Exception('Ошибка входа (${r.statusCode}): ${r.body}');
    }
    final token = (jsonDecode(r.body) as Map<String, dynamic>)['access_token'] as String;
    await saveToken(token);
    await fetchMe();
  }

  Future<List<Task>> listTasks({
    bool? isDone,
    String sort = 'created_at',
    String order = 'desc',
  }) async {
    final token = await getToken();
    final admin = await isAdmin();
    final params = <String, String>{
      'sort': sort,
      'order': order,
    };
    if (isDone != null) {
      params['is_done'] = isDone ? 'true' : 'false';
    }
    final path = admin ? '/admin/tasks' : '/tasks';
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: params);
    final r = await http.get(uri, headers: _headers(token));
    _throwIfUnauthorized(r);
    if (r.statusCode != 200) {
      throw Exception('Не удалось загрузить задачи (${r.statusCode}): ${r.body}');
    }
    final list = jsonDecode(r.body) as List<dynamic>;
    return list.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Task> createTask({
    required String title,
    String? description,
    int? assignToUserId,
  }) async {
    final token = await getToken();
    final admin = await isAdmin();
    final body = <String, dynamic>{
      'title': title,
      'description': description,
      'is_done': false,
    };
    late Uri uri;
    if (admin) {
      final ownerId = assignToUserId ?? await storedUserId();
      if (ownerId == null) {
        throw Exception('Неизвестен id пользователя: выполните вход снова.');
      }
      body['owner_id'] = ownerId;
      uri = Uri.parse('$baseUrl/admin/tasks');
    } else {
      uri = Uri.parse('$baseUrl/tasks');
    }
    final r = await http.post(
      uri,
      headers: _headers(token),
      body: jsonEncode(body),
    );
    _throwIfUnauthorized(r);
    if (r.statusCode != 201) {
      throw Exception('Не удалось создать задачу (${r.statusCode}): ${r.body}');
    }
    return Task.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<Task> patchTask(int id, {bool? isDone, String? title}) async {
    final token = await getToken();
    final admin = await isAdmin();
    final path = admin ? '/admin/tasks/$id' : '/tasks/$id';
    final body = <String, dynamic>{};
    if (isDone != null) {
      body['is_done'] = isDone;
    }
    if (title != null) {
      body['title'] = title;
    }
    final r = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    _throwIfUnauthorized(r);
    if (r.statusCode != 200) {
      throw Exception('Не удалось обновить задачу (${r.statusCode}): ${r.body}');
    }
    return Task.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> deleteTask(int id) async {
    final token = await getToken();
    final admin = await isAdmin();
    final path = admin ? '/admin/tasks/$id' : '/tasks/$id';
    final r = await http.delete(Uri.parse('$baseUrl$path'), headers: _headers(token));
    _throwIfUnauthorized(r);
    if (r.statusCode != 204) {
      throw Exception('Не удалось удалить задачу (${r.statusCode}): ${r.body}');
    }
  }
}
