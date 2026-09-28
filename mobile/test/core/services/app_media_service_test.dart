import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/core/services/app_media_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaUploadResult', () {
    test('fromJson correctly parses complete backend payload', () {
      final json = {
        'url': 'http://localhost:3000/api/v1/media/files/img_standard.webp',
        'thumbnailUrl': 'http://localhost:3000/api/v1/media/files/img_thumb.webp',
        'mediumUrl': 'http://localhost:3000/api/v1/media/files/img_medium.webp',
        'width': 1920,
        'height': 1080,
        'size': 204800,
        'mimeType': 'image/webp',
        'type': 'content',
      };

      final result = MediaUploadResult.fromJson(json);

      expect(result.url, 'http://localhost:3000/api/v1/media/files/img_standard.webp');
      expect(result.thumbnailUrl, 'http://localhost:3000/api/v1/media/files/img_thumb.webp');
      expect(result.mediumUrl, 'http://localhost:3000/api/v1/media/files/img_medium.webp');
      expect(result.width, 1920);
      expect(result.height, 1080);
      expect(result.size, 204800);
      expect(result.mimeType, 'image/webp');
      expect(result.type, 'content');
    });

    test('fromJson falls back to url when thumbnailUrl is missing', () {
      final json = {
        'url': 'https://example.com/photo.jpg',
        'width': 800,
        'height': 600,
        'size': 50000,
      };

      final result = MediaUploadResult.fromJson(json);

      expect(result.url, 'https://example.com/photo.jpg');
      expect(result.thumbnailUrl, 'https://example.com/photo.jpg');
      expect(result.mediumUrl, isNull);
      expect(result.mimeType, 'image/webp');
    });

    test('toJson produces expected map', () {
      const result = MediaUploadResult(
        url: 'https://example.com/standard.webp',
        thumbnailUrl: 'https://example.com/thumb.webp',
        mediumUrl: 'https://example.com/med.webp',
        width: 1024,
        height: 1024,
        size: 98000,
        mimeType: 'image/webp',
        type: 'profile',
      );

      final map = result.toJson();
      expect(map['url'], 'https://example.com/standard.webp');
      expect(map['thumbnailUrl'], 'https://example.com/thumb.webp');
      expect(map['mediumUrl'], 'https://example.com/med.webp');
      expect(map['width'], 1024);
      expect(map['height'], 1024);
      expect(map['size'], 98000);
      expect(map['mimeType'], 'image/webp');
      expect(map['type'], 'profile');
    });
  });

  group('AppMediaService Upload Tests', () {
    test('uploadImage posts multipart form data and parses response data wrapper', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        expect(options.path, '/media/images');
        expect(options.queryParameters['type'], 'profile');
        expect(options.data, isA<FormData>());

        return ResponseBody.fromString(
          '{"success": true, "data": {"url": "http://server/avatar.webp", "thumbnailUrl": "http://server/avatar_thumb.webp", "width": 1024, "height": 1024, "size": 85000, "mimeType": "image/webp", "type": "profile"}}',
          201,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final service = AppMediaService(dio);
      // Create a temporary file
      final tempDir = await Directory.systemTemp.createTemp('media_test');
      final testFile = File('${tempDir.path}/avatar.jpg');
      await testFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);

      try {
        final result = await service.uploadImage(testFile, type: 'profile');

        expect(result.url, 'http://server/avatar.webp');
        expect(result.thumbnailUrl, 'http://server/avatar_thumb.webp');
        expect(result.width, 1024);
        expect(result.height, 1024);
        expect(result.type, 'profile');
      } finally {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('uploadImage handles raw response without data envelope', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        return ResponseBody.fromString(
          '{"url": "http://server/item.webp", "thumbnailUrl": "http://server/item_thumb.webp", "width": 800, "height": 600, "size": 45000, "mimeType": "image/webp"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final service = AppMediaService(dio);
      final tempDir = await Directory.systemTemp.createTemp('media_test2');
      final testFile = File('${tempDir.path}/item.jpg');
      await testFile.writeAsBytes([0x89, 0x50, 0x4E, 0x47]);

      try {
        final result = await service.uploadImage(testFile);

        expect(result.url, 'http://server/item.webp');
        expect(result.width, 800);
        expect(result.height, 600);
      } finally {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('uploadMultipleImages notifies progress for each uploaded file', () async {
      final dio = Dio();
      int callCount = 0;
      dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        callCount++;
        return ResponseBody.fromString(
          '{"data": {"url": "http://server/img_$callCount.webp", "thumbnailUrl": "http://server/thumb_$callCount.webp", "width": 1200, "height": 800, "size": 60000, "mimeType": "image/webp"}}',
          201,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final service = AppMediaService(dio);
      final tempDir = await Directory.systemTemp.createTemp('media_test3');
      final file1 = File('${tempDir.path}/img1.jpg')..writeAsBytesSync([1, 2, 3]);
      final file2 = File('${tempDir.path}/img2.jpg')..writeAsBytesSync([4, 5, 6]);

      final progressEvents = <int>[];

      try {
        final results = await service.uploadMultipleImages(
          [file1, file2],
          onProgress: (done, total) {
            progressEvents.add(done);
          },
        );

        expect(results.length, 2);
        expect(results[0].url, 'http://server/img_1.webp');
        expect(results[1].url, 'http://server/img_2.webp');
        expect(progressEvents, containsAll([0, 1, 2]));
      } finally {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    });
  });
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  _MockHttpClientAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}
