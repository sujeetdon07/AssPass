import 'package:flutter/foundation.dart';

enum NotificationType {
  messageReceived('MESSAGE_RECEIVED'),
  postLiked('POST_LIKED'),
  postCommented('POST_COMMENTED'),
  commentReplied('COMMENT_REPLIED'),
  communityMembership('COMMUNITY_MEMBERSHIP'),
  marketplaceActivity('MARKETPLACE_ACTIVITY'),
  businessActivity('BUSINESS_ACTIVITY'),
  communityAnnouncement('COMMUNITY_ANNOUNCEMENT'),
  system('SYSTEM');

  const NotificationType(this.value);
  final String value;

  static NotificationType fromString(String val) {
    return NotificationType.values.firstWhere(
      (e) => e.value.toUpperCase() == val.toUpperCase(),
      orElse: () => NotificationType.system,
    );
  }
}

enum NotificationCategory {
  messages('MESSAGES'),
  social('SOCIAL'),
  community('COMMUNITY'),
  marketplace('MARKETPLACE'),
  business('BUSINESS'),
  system('SYSTEM');

  const NotificationCategory(this.value);
  final String value;

  static NotificationCategory fromString(String val) {
    return NotificationCategory.values.firstWhere(
      (e) => e.value.toUpperCase() == val.toUpperCase(),
      orElse: () => NotificationCategory.system,
    );
  }
}

enum NotificationFilter {
  all,
  unread,
  messages,
  social,
  community,
  marketplace,
  business,
  system,
}

@immutable
class NotificationSender {
  const NotificationSender({
    required this.id,
    this.displayName,
    this.avatarUrl,
    this.locality,
    this.city,
  });

  final String id;
  final String? displayName;
  final String? avatarUrl;
  final String? locality;
  final String? city;

  factory NotificationSender.fromJson(Map<String, dynamic> json) {
    return NotificationSender(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      locality: json['locality'] as String?,
      city: json['city'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'locality': locality,
      'city': city,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationSender &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

@immutable
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.recipientId,
    this.senderId,
    this.sender,
    required this.type,
    required this.category,
    required this.title,
    required this.body,
    this.data = const {},
    this.deepLink,
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final String recipientId;
  final String? senderId;
  final NotificationSender? sender;
  final NotificationType type;
  final NotificationCategory category;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final String? deepLink;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  NotificationItem copyWith({
    String? id,
    String? recipientId,
    String? senderId,
    NotificationSender? sender,
    NotificationType? type,
    NotificationCategory? category,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    String? deepLink,
    bool? isRead,
    DateTime? readAt,
    DateTime? createdAt,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      recipientId: recipientId ?? this.recipientId,
      senderId: senderId ?? this.senderId,
      sender: sender ?? this.sender,
      type: type ?? this.type,
      category: category ?? this.category,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      deepLink: deepLink ?? this.deepLink,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String? ?? '',
      recipientId: json['recipientId'] as String? ?? '',
      senderId: json['senderId'] as String?,
      sender: json['sender'] != null && json['sender'] is Map<String, dynamic>
          ? NotificationSender.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
      type: NotificationType.fromString(json['type'] as String? ?? ''),
      category:
          NotificationCategory.fromString(json['category'] as String? ?? ''),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      data: json['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['data'] as Map)
          : const {},
      deepLink: json['deepLink'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipientId': recipientId,
      'senderId': senderId,
      'sender': sender?.toJson(),
      'type': type.value,
      'category': category.value,
      'title': title,
      'body': body,
      'data': data,
      'deepLink': deepLink,
      'isRead': isRead,
      'readAt': readAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          isRead == other.isRead;

  @override
  int get hashCode => Object.hash(id, isRead);
}
