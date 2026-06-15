class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        chatId: json['chat_id'] as String,
        senderId: json['sender_id'] as String,
        content: json['content'] as String,
        isRead: json['is_read'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );

  Message copyWith({bool? isRead}) => Message(
        id:        id,
        chatId:    chatId,
        senderId:  senderId,
        content:   content,
        isRead:    isRead ?? this.isRead,
        createdAt: createdAt,
      );
}