class Task {
  Task({
    required this.id,
    required this.title,
    this.description,
    required this.isDone,
    required this.ownerId,
    required this.ownerEmail,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final String? description;
  final bool isDone;
  final int ownerId;
  final String ownerEmail;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Task.fromJson(Map<String, dynamic> j) {
    return Task(
      id: j['id'] as int,
      title: j['title'] as String,
      description: j['description'] as String?,
      isDone: j['is_done'] as bool,
      ownerId: j['owner_id'] as int,
      ownerEmail: j['owner_email'] as String? ?? '',
      createdAt: DateTime.parse(j['created_at'] as String),
      updatedAt: DateTime.parse(j['updated_at'] as String),
    );
  }
}
