import '../../domain/entities/post_entity.dart';

/// Data model representing post data transfer object from REST API.
class PostModel {
  const PostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorUsername,
    this.authorAvatarUrl,
    this.authorLocality,
    this.authorCity,
    required this.content,
    required this.category,
    this.locality,
    this.neighborhood,
    this.city,
    this.state,
    this.countryCode = 'IN',
    this.likeCount = 0,
    this.commentCount = 0,
    this.currentUserLiked = false,
    this.distance,
    this.distanceMeters,
    this.communityId,
    this.communityName,
    this.communitySlug,
    this.mentions = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorUsername;
  final String? authorAvatarUrl;
  final String? authorLocality;
  final String? authorCity;
  final String content;
  final PostCategory category;
  final String? locality;
  final String? neighborhood;
  final String? city;
  final String? state;
  final String countryCode;
  final int likeCount;
  final int commentCount;
  final bool currentUserLiked;
  final String? distance;
  final int? distanceMeters;
  final String? communityId;
  final String? communityName;
  final String? communitySlug;
  final List<PostMention> mentions;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PostModel.fromJson(Map<String, dynamic> json) {
    final authorMap = json['author'] as Map<String, dynamic>?;
    final communityMap = json['community'] as Map<String, dynamic>?;

    return PostModel(
      id: json['id'] as String? ?? '',
      authorId:
          json['authorId'] as String? ?? authorMap?['id'] as String? ?? '',
      authorName: authorMap?['displayName'] as String? ?? 'Neighbor',
      authorUsername: authorMap?['username'] as String?,
      authorAvatarUrl: authorMap?['avatarUrl'] as String?,
      authorLocality: authorMap?['locality'] as String?,
      authorCity: authorMap?['city'] as String?,
      content: json['content'] as String? ?? '',
      category: PostCategory.fromString(json['category'] as String?),
      locality: json['locality'] as String?,
      neighborhood: json['neighborhood'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      countryCode: json['countryCode'] as String? ?? 'IN',
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      currentUserLiked: json['currentUserLiked'] as bool? ?? false,
      distance: json['distance'] as String?,
      distanceMeters: (json['distanceMeters'] as num?)?.toInt(),
      communityId:
          json['communityId'] as String? ?? communityMap?['id'] as String?,
      communityName:
          json['communityName'] as String? ?? communityMap?['name'] as String?,
      communitySlug:
          json['communitySlug'] as String? ?? communityMap?['slug'] as String?,
      mentions: (json['mentions'] as List<dynamic>?)
              ?.map((m) => PostMention.fromJson(m as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  PostEntity toEntity() {
    return PostEntity(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorUsername: authorUsername,
      authorAvatarUrl: authorAvatarUrl,
      authorLocality: authorLocality,
      authorCity: authorCity,
      content: content,
      category: category,
      locality: locality,
      neighborhood: neighborhood,
      city: city,
      state: state,
      countryCode: countryCode,
      likeCount: likeCount,
      commentCount: commentCount,
      currentUserLiked: currentUserLiked,
      distance: distance,
      distanceMeters: distanceMeters,
      communityId: communityId,
      communityName: communityName,
      communitySlug: communitySlug,
      mentions: mentions,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
