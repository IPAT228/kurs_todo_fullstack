class SessionUser {
  SessionUser({
    required this.id,
    required this.email,
    required this.role,
  });

  final int id;
  final String email;
  final String role;

  bool get isAdmin => role == 'admin';

  factory SessionUser.fromJson(Map<String, dynamic> j) {
    return SessionUser(
      id: j['id'] as int,
      email: j['email'] as String,
      role: j['role'] as String,
    );
  }
}
