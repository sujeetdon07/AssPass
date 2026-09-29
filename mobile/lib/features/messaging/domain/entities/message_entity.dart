enum MessageStatus {
  sending,
  sent,
  failed,
}

class MessageEntity {
  const MessageEntity({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.clientMessageId,
    required this.content,
    this.messageType = 'TEXT',
    this.status = MessageStatus.sent,
    required this.createdAt,
    this.readAt,
    this.isMe = false,
    this.mediaUrl,
    this.mediaThumbnailUrl,
    this.mediaWidth,
    this.mediaHeight,
    this.mediaSize,
    this.mediaMimeType,
    this.localImagePath,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String clientMessageId;
  final String content;
  final String messageType;
  final MessageStatus status;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isMe;

  // Media attachment metadata
  final String? mediaUrl;
  final String? mediaThumbnailUrl;
  final int? mediaWidth;
  final int? mediaHeight;
  final int? mediaSize;
  final String? mediaMimeType;
  final String? localImagePath;

  bool get isRead => readAt != null;
  bool get isSending => status == MessageStatus.sending;
  bool get isFailed => status == MessageStatus.failed;
  bool get isSent => status == MessageStatus.sent;

  bool get isImage =>
      messageType == 'IMAGE' ||
      (mediaUrl != null && mediaUrl!.isNotEmpty) ||
      (localImagePath != null && localImagePath!.isNotEmpty);

  bool get hasCaption =>
      content.trim().isNotEmpty && content != 'Photo' && content != '[Image]';

  MessageEntity copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? clientMessageId,
    String? content,
    String? messageType,
    MessageStatus? status,
    DateTime? createdAt,
    DateTime? readAt,
    bool? isMe,
    String? mediaUrl,
    String? mediaThumbnailUrl,
    int? mediaWidth,
    int? mediaHeight,
    int? mediaSize,
    String? mediaMimeType,
    String? localImagePath,
  }) {
    return MessageEntity(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      isMe: isMe ?? this.isMe,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaThumbnailUrl: mediaThumbnailUrl ?? this.mediaThumbnailUrl,
      mediaWidth: mediaWidth ?? this.mediaWidth,
      mediaHeight: mediaHeight ?? this.mediaHeight,
      mediaSize: mediaSize ?? this.mediaSize,
      mediaMimeType: mediaMimeType ?? this.mediaMimeType,
      localImagePath: localImagePath ?? this.localImagePath,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageEntity &&
          runtimeType == other.runtimeType &&
          clientMessageId == other.clientMessageId;

  @override
  int get hashCode => clientMessageId.hashCode;
}
