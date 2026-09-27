import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/models/blocked_user_record.dart';
import '../../domain/models/safety_enums.dart';
import '../../domain/models/safety_report_item.dart';

final safetyRemoteDataSourceProvider = Provider<SafetyRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return SafetyRemoteDataSource(dio);
});

/// Remote data source for all Trust & Safety API calls.
///
/// All calls go to `/api/v1/safety/` — no calls to module-level report
/// endpoints. This is the single point of contact for Phase 10 safety actions.
class SafetyRemoteDataSource {
  SafetyRemoteDataSource(this._dio);

  final Dio _dio;

  // ── Block management ─────────────────────────────────────────────────────────

  /// Block a user by their ID.
  Future<void> blockUser(String userId) async {
    await _dio.post<Map<String, dynamic>>(
      '/safety/blocks',
      data: {'userId': userId},
    );
  }

  /// Unblock a previously blocked user.
  Future<void> unblockUser(String userId) async {
    await _dio.delete<Map<String, dynamic>>('/safety/blocks/$userId');
  }

  /// Fetch the paginated list of users blocked by the current user.
  Future<({List<BlockedUserRecord> items, String? nextCursor, bool hasMore})>
      getBlockedUsers({int limit = 20, String? cursor}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/safety/blocks',
      queryParameters: {
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    final rawItems = data['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .map((e) => BlockedUserRecord.fromJson(e as Map<String, dynamic>))
        .toList();

    return (
      items: items,
      nextCursor: data['nextCursor'] as String?,
      hasMore: data['hasMore'] as bool? ?? false,
    );
  }

  // ── Content reporting ────────────────────────────────────────────────────────

  /// Submit a content report for any supported target type.
  Future<void> submitReport({
    required ReportTargetType targetType,
    required String targetId,
    required ReportReason reason,
    String? details,
    String? secondaryId,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/safety/reports',
      data: {
        'targetType': targetType.value,
        'targetId': targetId,
        'reason': reason.value,
        if (details != null && details.isNotEmpty) 'details': details,
        if (secondaryId != null && secondaryId.isNotEmpty)
          'secondaryId': secondaryId,
      },
    );
  }

  /// Fetch the paginated report history for the current user.
  Future<({List<SafetyReportItem> items, String? nextCursor, bool hasMore})>
      getMyReports({int limit = 20, String? cursor}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/safety/reports/me',
      queryParameters: {
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    final rawItems = data['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .map((e) => SafetyReportItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return (
      items: items,
      nextCursor: data['nextCursor'] as String?,
      hasMore: data['hasMore'] as bool? ?? false,
    );
  }
}
