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

  bool get isRead => readAt != null;
  bool get isSending => status == MessageStatus.sending;
  bool get isFailed => status == MessageStatus.failed;
  bool get isSent => status == MessageStatus.sent;

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
