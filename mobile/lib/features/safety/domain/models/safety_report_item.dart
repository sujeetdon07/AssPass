import 'safety_enums.dart';

/// Domain model for an item in the user's report history.
class SafetyReportItem {
  const SafetyReportItem({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.details,
  });

  factory SafetyReportItem.fromJson(Map<String, dynamic> json) {
    return SafetyReportItem(
      id: json['id'] as String? ?? '',
      targetType: ReportTargetType.fromString(json['targetType'] as String? ?? ''),
      targetId: json['targetId'] as String? ?? '',
      reason: ReportReason.fromString(json['reason'] as String? ?? ''),
      status: ReportStatus.fromString(json['status'] as String? ?? ''),
      details: json['details'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  final String id;
  final ReportTargetType targetType;
  final String targetId;
  final ReportReason reason;
  final ReportStatus status;
  final String? details;
  final DateTime createdAt;
}
