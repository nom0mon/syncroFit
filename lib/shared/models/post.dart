import 'comment.dart';

class Post {
  final String id;
  final String authorName;
  final String content;
  final DateTime timestamp;
  final int likeCount;
  final bool isLikedByCurrentUser;
  final List<Comment> comments;

  const Post({
    required this.id,
    required this.authorName,
    required this.content,
    required this.timestamp,
    required this.likeCount,
    required this.isLikedByCurrentUser,
    required this.comments,
  });
}
