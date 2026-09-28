import '../../domain/entities/comment_entity.dart';

/// Data model representing comment data transfer object from REST API.
class CommentModel {
  const CommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorUsername,
    this.authorAvatarUrl,
    this.authorLocality,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String? authorUsername;
  final String? authorAvatarUrl;
  final String? authorLocality;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final authorMap = json['author'] as Map<String, dynamic>?;

    return CommentModel(
      id: json['id'] as String? ?? '',
      postId: json['postId'] as String? ?? '',
      authorId:
          json['authorId'] as String? ?? authorMap?['id'] as String? ?? '',
      authorName: authorMap?['displayName'] as String? ?? 'Neighbor',
      authorUsername: authorMap?['username'] as String?,
      authorAvatarUrl: authorMap?['avatarUrl'] as String?,
      authorLocality: authorMap?['locality'] as String?,
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  CommentEntity toEntity() {
    return CommentEntity(
      id: id,
      postId: postId,
      authorId: authorId,
      authorName: authorName,
      authorUsername: authorUsername,
      authorAvatarUrl: authorAvatarUrl,
      authorLocality: authorLocality,
      content: content,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
