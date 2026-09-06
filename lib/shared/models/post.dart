import 'comment.dart';

class CommunityPhoto {
  const CommunityPhoto({required this.id, required this.url, required this.mimeType, required this.position, this.width, this.height});
  final String id;
  final String url;
  final String mimeType;
  final int position;
  final int? width;
  final int? height;

  factory CommunityPhoto.fromJson(Map<String, dynamic> json) => CommunityPhoto(
        id: json['id'].toString(), url: json['url'] as String,
        mimeType: json['mime_type'] as String, position: (json['position'] as num).toInt(),
        width: (json['width'] as num?)?.toInt(), height: (json['height'] as num?)?.toInt(),
      );
  Map<String, dynamic> toJson() => {'id': id, 'url': url, 'mime_type': mimeType, 'position': position, 'width': width, 'height': height};
}

class Post {
  final String id;
  final String authorName;
  final String authorId;
  final String content;
  final DateTime timestamp;
  final int likeCount;
  final bool isLikedByCurrentUser;
  final List<Comment> comments;
  final int commentCount;
  final bool isOwnedByCurrentUser;
  final List<CommunityPhoto> media;

  const Post({
    required this.id,
    required this.authorName,
    this.authorId = '',
    required this.content,
    required this.timestamp,
    required this.likeCount,
    required this.isLikedByCurrentUser,
    required this.comments,
    int? commentCount,
    this.isOwnedByCurrentUser = false,
    this.media = const [],
  }) : commentCount = commentCount ?? comments.length;

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['id'].toString(),
        authorId: json['author_id']?.toString() ?? '',
        authorName: json['author_name'] as String? ?? 'Unknown user',
        content: json['content'] as String,
        timestamp: DateTime.parse(json['created_at'] as String),
        likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
        commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
        isLikedByCurrentUser: json['is_liked_by_current_user'] as bool? ?? false,
        isOwnedByCurrentUser: json['is_owned_by_current_user'] as bool? ?? false,
        comments: (json['comments'] as List<dynamic>? ?? const [])
            .map((item) => Comment.fromJson(item as Map<String, dynamic>)).toList(),
        media: (json['media'] as List<dynamic>? ?? const [])
            .map((item) => CommunityPhoto.fromJson(item as Map<String, dynamic>)).toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'author_id': authorId, 'author_name': authorName,
        'content': content, 'created_at': timestamp.toIso8601String(),
        'like_count': likeCount, 'comment_count': commentCount,
        'is_liked_by_current_user': isLikedByCurrentUser,
        'is_owned_by_current_user': isOwnedByCurrentUser,
        'comments': comments.map((item) => item.toJson()).toList(),
        'media': media.map((item) => item.toJson()).toList(),
      };

  Post copyWith({int? likeCount, bool? isLikedByCurrentUser, List<Comment>? comments, int? commentCount}) => Post(
        id: id, authorId: authorId, authorName: authorName, content: content,
        timestamp: timestamp, likeCount: likeCount ?? this.likeCount,
        isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
        comments: comments ?? this.comments,
        commentCount: commentCount ?? this.commentCount,
        isOwnedByCurrentUser: isOwnedByCurrentUser,
        media: media,
      );
}
