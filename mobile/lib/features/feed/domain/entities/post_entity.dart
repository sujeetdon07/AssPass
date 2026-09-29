import 'package:flutter/material.dart';

import 'post_image_entity.dart';

/// Supported post categories in Aaspaas.
enum PostCategory {
  general('general', 'General', Icons.chat_bubble_outline_rounded),
  announcement('announcement', 'Announcement', Icons.campaign_outlined),
  question('question', 'Ask Neighbors', Icons.help_outline_rounded),
  recommendation('recommendation', 'Recommendation', Icons.thumb_up_outlined),
  alert('alert', 'Local Alert', Icons.warning_amber_rounded);

  const PostCategory(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;

  static PostCategory fromString(String? val) {
    if (val == null) return PostCategory.general;
    return PostCategory.values.firstWhere(
      (e) => e.value == val.toLowerCase(),
      orElse: () => PostCategory.general,
    );
  }
}

/// Structured @mention in a post referencing an immutable User UUID and character range.
class PostMention {
  const PostMention({
    required this.userId,
    required this.start,
    required this.length,
    this.username,
    this.displayName,
    this.avatarUrl,
  });

  final String userId;
  final int start;
  final int length;
  final String? username;
  final String? displayName;
  final String? avatarUrl;

  String? get handle => username != null && username!.trim().isNotEmpty
      ? (username!.startsWith('@') ? username! : '@$username')
      : null;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'start': start,
        'length': length,
      };

  factory PostMention.fromJson(Map<String, dynamic> json) {
    return PostMention(
      userId: json['userId'] as String? ?? '',
      start: (json['start'] as num?)?.toInt() ?? 0,
      length: (json['length'] as num?)?.toInt() ?? 0,
      username: json['username'] as String?,
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

/// Pure domain entity representing a Post in the community feed.
class PostEntity {
  const PostEntity({
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
    this.images = const [],
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
  final List<PostImageEntity> images;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Whether this post has any attached images.
  bool get hasImages => images.isNotEmpty;

  /// Formatted handle e.g. '@sujeet'
  String? get authorHandle =>
      authorUsername != null && authorUsername!.trim().isNotEmpty
          ? (authorUsername!.trim().startsWith('@')
              ? authorUsername!.trim()
              : '@${authorUsername!.trim()}')
          : null;

  /// User-friendly display location summary for this post.
  String get locationDisplay {
    final effectiveLocality = locality ?? authorLocality;
    final effectiveCity = city ?? authorCity;
    if (neighborhood != null && effectiveLocality != null) {
      return '$neighborhood, $effectiveLocality';
    }
    if (effectiveLocality != null && effectiveCity != null) {
      return '$effectiveLocality, $effectiveCity';
    }
    if (effectiveLocality != null) return effectiveLocality;
    if (effectiveCity != null) return effectiveCity;
    return 'Nearby';
  }

  /// Relative or formatted date string for display.
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '${mins}m ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '${hours}h ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '${days}d ago';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  PostEntity copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorUsername,
    String? authorAvatarUrl,
    String? authorLocality,
    String? authorCity,
    String? content,
    PostCategory? category,
    String? locality,
    String? neighborhood,
    String? city,
    String? state,
    String? countryCode,
    int? likeCount,
    int? commentCount,
    bool? currentUserLiked,
    String? distance,
    int? distanceMeters,
    String? communityId,
    String? communityName,
    String? communitySlug,
    List<PostMention>? mentions,
    List<PostImageEntity>? images,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PostEntity(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorUsername: authorUsername ?? this.authorUsername,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      authorLocality: authorLocality ?? this.authorLocality,
      authorCity: authorCity ?? this.authorCity,
      content: content ?? this.content,
      category: category ?? this.category,
      locality: locality ?? this.locality,
      neighborhood: neighborhood ?? this.neighborhood,
      city: city ?? this.city,
      state: state ?? this.state,
      countryCode: countryCode ?? this.countryCode,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      currentUserLiked: currentUserLiked ?? this.currentUserLiked,
      distance: distance ?? this.distance,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      communityId: communityId ?? this.communityId,
      communityName: communityName ?? this.communityName,
      communitySlug: communitySlug ?? this.communitySlug,
      mentions: mentions ?? this.mentions,
      images: images ?? this.images,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
