// lib/screens/chat_bot/models/chat_message.dart
class ChatMessage {
  final String message;
  final bool isUser;
  final DateTime timestamp;
  final String? friendId; // 친구 ID 추가
  final bool? isNotice; // 공지사항 여부 추가

  ChatMessage({
    required this.message,
    required this.isUser,
    DateTime? timestamp,
    this.friendId, // 친구 ID (선택 사항)
    this.isNotice, // 공지사항 여부 (선택 사항)
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'ChatMessage(isUser: $isUser, time: $timestamp, friendId: $friendId, isNotice: $isNotice, message: ${message.substring(0, message.length > 20 ? 20 : message.length)}...)';
  }
}
