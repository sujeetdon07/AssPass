import '../../../feed/data/models/post_model.dart';
import '../../../feed/domain/entities/post_entity.dart';

/// Paginated nearby discovery result model.
class NearbyPageModel {
  const NearbyPageModel({
    required this.posts,
    this.nextCursor,
    required this.hasMore,
    this.radiusKm = 5,
  });

  final List<PostEntity> posts;
  final String? nextCursor;
  final bool hasMore;
  final int radiusKm;

  factory NearbyPageModel.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] ?? json['posts']) as List<dynamic>? ?? [];
    return NearbyPageModel(
      posts: rawItems
          .map(
            (item) =>
                PostModel.fromJson(item as Map<String, dynamic>).toEntity(),
          )
          .toList(),
      nextCursor: json['nextCursor'] as String?,
      hasMore: json['hasMore'] as bool? ?? false,
      radiusKm: (json['radiusKm'] as num?)?.toInt() ?? 5,
    );
  }
}
