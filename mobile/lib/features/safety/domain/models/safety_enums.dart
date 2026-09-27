/// Supported content and entity types that can be reported.
///
/// Matches the `SafetyReportTargetType` enum on the backend.
enum ReportTargetType {
  user('user', 'User Profile'),
  post('post', 'Post'),
  comment('comment', 'Comment'),
  listing('listing', 'Listing'),
  business('business', 'Business'),
  service('service', 'Service'),
  conversation('conversation', 'Conversation'),
  message('message', 'Message');

  const ReportTargetType(this.value, this.label);

  /// Backend enum string value.
  final String value;

  /// Human-readable label for UI display.
  final String label;

  static ReportTargetType fromString(String val) {
    return ReportTargetType.values.firstWhere(
      (e) => e.value == val.toLowerCase(),
      orElse: () => ReportTargetType.post,
    );
  }
}

/// Controlled report reason categories for the Trust & Safety system.
///
/// Matches the `SafetyReportReason` enum on the backend.
enum ReportReason {
  spam('spam', 'Spam or commercial advertising'),
  harassment('harassment', 'Harassment or bullying'),
  hateOrAbuse('hate_or_abuse', 'Hate speech or abuse'),
  threats('threats', 'Threats of violence'),
  scamOrFraud('scam_or_fraud', 'Scam, fraud, or phishing'),
  sexualContent('sexual_content', 'Sexual or explicit content'),
  violence('violence', 'Violence or dangerous acts'),
  illegalActivity('illegal_activity', 'Illegal goods or activities'),
  misinformation('misinformation', 'False or misleading information'),
  impersonation('impersonation', 'Impersonation or fake account'),
  privacyViolation('privacy_violation', 'Sharing private personal info'),
  inappropriateContent('inappropriate_content', 'Inappropriate or offensive content'),
  other('other', 'Other safety concerns'),

  // Backward-compatible aliases
  fraud('fraud', 'Scam or fraud'),
  illegalContent('illegal_content', 'Illegal content'),
  misleading('misleading', 'Misleading information'),
  inappropriate('inappropriate', 'Inappropriate content');

  const ReportReason(this.value, this.label);

  final String value;
  final String label;

  static ReportReason fromString(String val) {
    return ReportReason.values.firstWhere(
      (e) => e.value == val.toLowerCase(),
      orElse: () => ReportReason.other,
    );
  }
}

/// Moderation lifecycle status for a report.
enum ReportStatus {
  pending('pending', 'Pending Review'),
  reviewing('reviewing', 'In Review'),
  actioned('actioned', 'Action Taken'),
  dismissed('dismissed', 'Dismissed'),
  duplicate('duplicate', 'Duplicate');

  const ReportStatus(this.value, this.label);

  final String value;
  final String label;

  static ReportStatus fromString(String val) {
    return ReportStatus.values.firstWhere(
      (e) => e.value == val.toLowerCase(),
      orElse: () => ReportStatus.pending,
    );
  }
}
