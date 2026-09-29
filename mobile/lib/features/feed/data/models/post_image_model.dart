import '../../../../core/services/app_media_service.dart';
import '../../domain/entities/post_image_entity.dart';

/// DTO model for post image attachments.
class PostImageModel {
  const PostImageModel({
    required this.id,
    required this.url,
    required this.thumbnailUrl,
    this.mediumUrl,
    this.width,
    this.height,
    this.mimeType,
    this.size,
    this.sortOrder = 0,
  });

  final String id;
  final String url;
  final String thumbnailUrl;
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

  factory PostImageModel.fromJson(Map<String, dynamic> json) {
    return PostImageModel(
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

  factory PostImageModel.fromMediaUploadResult(
    MediaUploadResult result, {
    int sortOrder = 0,
  }) {
    return PostImageModel(
      id: '',
      url: result.url,
      thumbnailUrl: result.thumbnailUrl,
      mediumUrl: result.mediumUrl,
      width: result.width > 0 ? result.width : null,
      height: result.height > 0 ? result.height : null,
      mimeType: result.mimeType,
      size: result.size > 0 ? result.size : null,
      sortOrder: sortOrder,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'url': url,
        'thumbnailUrl': thumbnailUrl,
        if (mediumUrl != null) 'mediumUrl': mediumUrl,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (mimeType != null) 'mimeType': mimeType,
        if (size != null) 'size': size,
        'sortOrder': sortOrder,
      };

  PostImageEntity toEntity() {
    return PostImageEntity(
      id: id,
      url: url,
      thumbnailUrl: thumbnailUrl,
      mediumUrl: mediumUrl,
      width: width,
      height: height,
      mimeType: mimeType,
      size: size,
      sortOrder: sortOrder,
    );
  }
}
