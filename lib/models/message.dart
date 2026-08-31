// lib/models/message.dart
// Maps public.messages. Includes realtime delivery + read-receipt state that is
// tracked in-memory (the schema has no persisted read column; we use a Realtime
// broadcast 'read' event instead). Outgoing text is masked via InputGuard.maskContactInfo.
enum MessageType { text, image, voice, pin, offer, verify }

class ChatMessage {
  final int id;
  final String chatId;
  final String senderId;
  final MessageType type;
  final String? body;
  final String? mediaUrl;
  final DateTime createdAt;

  // Local-only UI state (not persisted).
  bool delivered = true;
  bool seen = false;

  ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.type = MessageType.text,
    this.body,
    this.mediaUrl,
    required this.createdAt,
    this.delivered = true,
    this.seen = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int,
      chatId: json['chat_id'] as String,
      senderId: json['sender_id'] as String,
      type: _type(json['type'] as String?),
      body: json['body'] as String?,
      mediaUrl: json['media_url'] as String?,
      createdAt: json['created_at'] == null
          ? DateTime.now()
          : DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsert() => {
        'chat_id': chatId,
        'sender_id': senderId,
        'type': _typeStr(type),
        'body': body,
        'media_url': mediaUrl,
      };

  bool get isMine => senderId == _currentUid;
  static String? _currentUid;
  static void setCurrentUser(String? uid) => _currentUid = uid;

  static MessageType _type(String? v) {
    switch (v) {
      case 'image':
        return MessageType.image;
      case 'voice':
        return MessageType.voice;
      case 'pin':
        return MessageType.pin;
      case 'offer':
        return MessageType.offer;
      case 'verify':
        return MessageType.verify;
      default:
        return MessageType.text;
    }
  }

  static String _typeStr(MessageType t) => t.name;
}
