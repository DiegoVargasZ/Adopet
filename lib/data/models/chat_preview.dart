import 'shelter.dart';

class ChatPreview {
  final String id;
  final Shelter shelter;
  final String? lastMessage;
  final DateTime updatedAt;
  final int unreadCount;

  const ChatPreview({
    required this.id,
    required this.shelter,
    this.lastMessage,
    required this.updatedAt,
    this.unreadCount = 0,
  });
}