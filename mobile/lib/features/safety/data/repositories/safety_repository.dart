import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/blocked_user_record.dart';
import '../../domain/models/safety_enums.dart';
import '../../domain/models/safety_report_item.dart';
import '../datasources/safety_remote_data_source.dart';

final safetyRepositoryProvider = Provider<SafetyRepository>((ref) {
  final dataSource = ref.watch(safetyRemoteDataSourceProvider);
  return SafetyRepository(dataSource);
});

/// Repository for Trust & Safety operations.
class SafetyRepository {
  SafetyRepository(this._dataSource);

  final SafetyRemoteDataSource _dataSource;

  Future<void> blockUser(String userId) => _dataSource.blockUser(userId);

  Future<void> unblockUser(String userId) => _dataSource.unblockUser(userId);

  Future<({List<BlockedUserRecord> items, String? nextCursor, bool hasMore})>
      getBlockedUsers({int limit = 20, String? cursor}) =>
          _dataSource.getBlockedUsers(limit: limit, cursor: cursor);

  Future<void> submitReport({
    required ReportTargetType targetType,
    required String targetId,
    required ReportReason reason,
    String? details,
    String? secondaryId,
  }) =>
      _dataSource.submitReport(
        targetType: targetType,
        targetId: targetId,
        reason: reason,
        details: details,
        secondaryId: secondaryId,
      );

  Future<({List<SafetyReportItem> items, String? nextCursor, bool hasMore})>
      getMyReports({int limit = 20, String? cursor}) =>
          _dataSource.getMyReports(limit: limit, cursor: cursor);
}
