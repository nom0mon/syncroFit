class User {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName'.trim();

  /// Backward-compatible: reads 'name' as fallback for old responses
  factory User.fromJson(Map<String, dynamic> json) {
    final firstName = json['first_name'] as String? ?? '';
    final lastName = json['last_name'] as String? ?? '';
    // Fallback: if first_name/last_name are empty but 'name' exists, split it
    if (firstName.isEmpty && lastName.isEmpty && json['name'] != null) {
      final parts = (json['name'] as String).split(' ');
      return User(
        id: json['id'].toString(),
        firstName: parts.first,
        lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '',
        email: json['email'] as String,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
      );
    }
    return User(
      id: json['id'].toString(),
      firstName: firstName,
      lastName: lastName,
      email: json['email'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'created_at': createdAt.toIso8601String(),
      };
}
