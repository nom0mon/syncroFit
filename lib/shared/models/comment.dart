class Comment {
  final String id;
  final String postId;
  final String authorName;
  final String text;
  final DateTime timestamp;

  const Comment({
    required this.id,
    required this.postId,
    required this.authorName,
    required this.text,
    required this.timestamp,
  });
}
