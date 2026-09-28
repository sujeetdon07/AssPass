import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../network/api_client.dart';

/// Metadata for an uploaded media image.
class MediaUploadResult {
  const MediaUploadResult({
    required this.url,
    required this.thumbnailUrl,
    this.mediumUrl,
    required this.width,
    required this.height,
    required this.size,
    required this.mimeType,
    this.type,
  });

  final String url;
  final String thumbnailUrl;
  final String? mediumUrl;
  final int width;
  final int height;
  final int size;
  final String mimeType;
  final String? type;

  factory MediaUploadResult.fromJson(Map<String, dynamic> json) {
    return MediaUploadResult(
      url: json['url'] as String? ?? '',
      thumbnailUrl: (json['thumbnailUrl'] as String?) ?? (json['url'] as String? ?? ''),
      mediumUrl: json['mediumUrl'] as String?,
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 0,
      mimeType: json['mimeType'] as String? ?? 'image/webp',
      type: json['type'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'thumbnailUrl': thumbnailUrl,
        'mediumUrl': mediumUrl,
        'width': width,
        'height': height,
        'size': size,
        'mimeType': mimeType,
        'type': type,
      };
}

/// Service providing unified gallery image selection and server upload.
class AppMediaService {
  AppMediaService(this._dio);

  final Dio _dio;
  final ImagePicker _picker = ImagePicker();

  /// Opens the modern Android gallery/photo picker for selecting a single image.
  /// Applies client-side resize and compression before upload.
  Future<File?> pickSingleImage({
    ImageSource source = ImageSource.gallery,
    double maxWidth = 2048,
    double maxHeight = 2048,
    int imageQuality = 85,
  }) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );
      if (picked == null) return null;
      return File(picked.path);
    } catch (e) {
      debugPrint('[AppMediaService] Failed to pick image: $e');
      return null;
    }
  }

  /// Opens the Android gallery/photo picker for multi-image selection.
  Future<List<File>> pickMultipleImages({
    double maxWidth = 2048,
    double maxHeight = 2048,
    int imageQuality = 85,
    int? limit,
  }) async {
    try {
      final pickedList = await _picker.pickMultiImage(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
        limit: limit,
      );
      if (pickedList.isEmpty) return [];
      return pickedList.map((x) => File(x.path)).toList();
    } catch (e) {
      debugPrint('[AppMediaService] Failed to pick multiple images: $e');
      return [];
    }
  }

  /// Uploads a single image file via multipart/form-data to the backend media API.
  Future<MediaUploadResult> uploadImage(
    File file, {
    String type = 'content',
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
      ),
    });

    final response = await _dio.post<Map<String, dynamic>>(
      '/media/images',
      queryParameters: {'type': type},
      data: formData,
      onSendProgress: onSendProgress,
    );

    final raw = response.data;
    if (raw == null) {
      throw Exception('Server returned an empty upload response.');
    }

    final data = (raw['data'] is Map<String, dynamic>)
        ? raw['data'] as Map<String, dynamic>
        : raw;

    return MediaUploadResult.fromJson(data);
  }

  /// Uploads multiple image files sequentially with progress reporting.
  Future<List<MediaUploadResult>> uploadMultipleImages(
    List<File> files, {
    String type = 'content',
    void Function(int completed, int total)? onProgress,
  }) async {
    final results = <MediaUploadResult>[];
    for (int i = 0; i < files.length; i++) {
      onProgress?.call(i, files.length);
      final res = await uploadImage(files[i], type: type);
      results.add(res);
    }
    onProgress?.call(files.length, files.length);
    return results;
  }
}

/// Riverpod provider for [AppMediaService].
final appMediaServiceProvider = Provider<AppMediaService>((ref) {
  final dio = ref.watch(dioProvider);
  return AppMediaService(dio);
});
