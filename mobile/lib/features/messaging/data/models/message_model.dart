import '../../domain/entities/message_entity.dart';

class MessageModel extends MessageEntity {
  const MessageModel({
    required super.id,
    required super.conversationId,
    required super.senderId,
    required super.clientMessageId,
    required super.content,
    super.messageType = 'TEXT',
    super.status = MessageStatus.sent,
    required super.createdAt,
    super.readAt,
    super.isMe = false,
    super.mediaUrl,
    super.mediaThumbnailUrl,
    super.mediaWidth,
    super.mediaHeight,
    super.mediaSize,
    super.mediaMimeType,
    super.localImagePath,
  });

  factory MessageModel.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final senderId = json['senderId'] as String? ?? '';
    final createdAtStr = json['createdAt'] as String?;
    final readAtStr = json['readAt'] as String?;

    return MessageModel(
      id: json['id'] as String? ?? '',
      conversationId: json['conversationId'] as String? ?? '',
      senderId: senderId,
      clientMessageId: json['clientMessageId'] as String? ?? '',
      content: json['content'] as String? ?? '',
      messageType: json['messageType'] as String? ?? 'TEXT',
      status: MessageStatus.sent,
      createdAt: createdAtStr != null
          ? DateTime.tryParse(createdAtStr) ?? DateTime.now()
          : DateTime.now(),
      readAt: readAtStr != null ? DateTime.tryParse(readAtStr) : null,
      isMe: currentUserId != null && senderId == currentUserId,
      mediaUrl: json['mediaUrl'] as String?,
      mediaThumbnailUrl: json['mediaThumbnailUrl'] as String?,
      mediaWidth: (json['mediaWidth'] as num?)?.toInt(),
      mediaHeight: (json['mediaHeight'] as num?)?.toInt(),
      mediaSize: (json['mediaSize'] as num?)?.toInt(),
      mediaMimeType: json['mediaMimeType'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'clientMessageId': clientMessageId,
      'content': content,
      'messageType': messageType,
      'createdAt': createdAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (mediaThumbnailUrl != null) 'mediaThumbnailUrl': mediaThumbnailUrl,
      if (mediaWidth != null) 'mediaWidth': mediaWidth,
      if (mediaHeight != null) 'mediaHeight': mediaHeight,
      if (mediaSize != null) 'mediaSize': mediaSize,
      if (mediaMimeType != null) 'mediaMimeType': mediaMimeType,
    };
  }
}
