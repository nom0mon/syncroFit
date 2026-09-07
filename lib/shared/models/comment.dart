class Comment {
  final String id;
  final String postId;
  final String authorName;
  final String authorId;
  final String text;
  final DateTime timestamp;
  final bool isOwnedByCurrentUser;

  const Comment({
    required this.id,
    required this.postId,
    required this.authorName,
    this.authorId = '',
    required this.text,
    required this.timestamp,
    this.isOwnedByCurrentUser = false,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'].toString(),
        postId: json['post_id'].toString(),
        authorId: json['author_id']?.toString() ?? '',
        authorName: json['author_name'] as String? ?? 'Unknown user',
        text: json['content'] as String,
        timestamp: DateTime.parse(json['created_at'] as String),
        isOwnedByCurrentUser:
            json['is_owned_by_current_user'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'post_id': postId,
        'author_id': authorId,
        'author_name': authorName,
        'content': text,
        'created_at': timestamp.toIso8601String(),
        'is_owned_by_current_user': isOwnedByCurrentUser,
      };
}
