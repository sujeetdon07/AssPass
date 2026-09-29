/// Pure domain entity representing an attached image in a Feed post.
class PostImageEntity {
  const PostImageEntity({
    required this.id,
    required this.url,
    this.thumbnailUrl,
    this.mediumUrl,
    this.width,
    this.height,
    this.mimeType,
    this.size,
    this.sortOrder = 0,
  });

  final String id;
  final String url;
  final String? thumbnailUrl;
  final String? mediumUrl;
  final int? width;
  final int? height;
  final String? mimeType;
  final int? size;
  final int sortOrder;

  /// Aspect ratio if width and height are available, else null.
  double? get aspectRatio => (width != null && height != null && height! > 0)
      ? width! / height!
      : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'thumbnailUrl': thumbnailUrl,
        if (mediumUrl != null) 'mediumUrl': mediumUrl,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (mimeType != null) 'mimeType': mimeType,
        if (size != null) 'size': size,
        'sortOrder': sortOrder,
      };

  factory PostImageEntity.fromJson(Map<String, dynamic> json) {
    return PostImageEntity(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      thumbnailUrl: (json['thumbnailUrl'] as String?) ??
          (json['url'] as String? ?? ''),
      mediumUrl: json['mediumUrl'] as String?,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      mimeType: json['mimeType'] as String?,
      size: (json['size'] as num?)?.toInt(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}
