import 'package:flutter/foundation.dart';

@immutable
class NotificationPreferences {
  const NotificationPreferences({
    required this.userId,
    this.messagesEnabled = true,
    this.socialEnabled = true,
    this.communityEnabled = true,
    this.marketplaceEnabled = true,
    this.businessEnabled = true,
    this.systemEnabled = true,
    this.pushEnabled = true,
    this.emailEnabled = false,
    this.smsEnabled = false,
    this.updatedAt,
  });

  final String userId;
  final bool messagesEnabled;
  final bool socialEnabled;
  final bool communityEnabled;
  final bool marketplaceEnabled;
  final bool businessEnabled;
  final bool systemEnabled;
  final bool pushEnabled;
  final bool emailEnabled;
  final bool smsEnabled;
  final DateTime? updatedAt;

  NotificationPreferences copyWith({
    String? userId,
    bool? messagesEnabled,
    bool? socialEnabled,
    bool? communityEnabled,
    bool? marketplaceEnabled,
    bool? businessEnabled,
    bool? systemEnabled,
    bool? pushEnabled,
    bool? emailEnabled,
    bool? smsEnabled,
    DateTime? updatedAt,
  }) {
    return NotificationPreferences(
      userId: userId ?? this.userId,
      messagesEnabled: messagesEnabled ?? this.messagesEnabled,
      socialEnabled: socialEnabled ?? this.socialEnabled,
      communityEnabled: communityEnabled ?? this.communityEnabled,
      marketplaceEnabled: marketplaceEnabled ?? this.marketplaceEnabled,
      businessEnabled: businessEnabled ?? this.businessEnabled,
      systemEnabled: systemEnabled ?? this.systemEnabled,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      smsEnabled: smsEnabled ?? this.smsEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      userId: json['userId'] as String? ?? '',
      messagesEnabled: json['messagesEnabled'] as bool? ?? true,
      socialEnabled: json['socialEnabled'] as bool? ?? true,
      communityEnabled: json['communityEnabled'] as bool? ?? true,
      marketplaceEnabled: json['marketplaceEnabled'] as bool? ?? true,
      businessEnabled: json['businessEnabled'] as bool? ?? true,
      systemEnabled: json['systemEnabled'] as bool? ?? true,
      pushEnabled: json['pushEnabled'] as bool? ?? true,
      emailEnabled: json['emailEnabled'] as bool? ?? false,
      smsEnabled: json['smsEnabled'] as bool? ?? false,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'messagesEnabled': messagesEnabled,
      'socialEnabled': socialEnabled,
      'communityEnabled': communityEnabled,
      'marketplaceEnabled': marketplaceEnabled,
      'businessEnabled': businessEnabled,
      'systemEnabled': systemEnabled,
      'pushEnabled': pushEnabled,
      'emailEnabled': emailEnabled,
      'smsEnabled': smsEnabled,
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationPreferences &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          messagesEnabled == other.messagesEnabled &&
          socialEnabled == other.socialEnabled &&
          communityEnabled == other.communityEnabled &&
          marketplaceEnabled == other.marketplaceEnabled &&
          businessEnabled == other.businessEnabled &&
          systemEnabled == other.systemEnabled &&
          pushEnabled == other.pushEnabled &&
          emailEnabled == other.emailEnabled &&
          smsEnabled == other.smsEnabled;

  @override
  int get hashCode => Object.hash(
        userId,
        messagesEnabled,
        socialEnabled,
        communityEnabled,
        marketplaceEnabled,
        businessEnabled,
        systemEnabled,
        pushEnabled,
      );
}
