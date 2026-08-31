// lib/models/chat.dart
// Maps public.chats + public.chat_participants. RLS: only participants can read.
enum ChatStatus { pending, active, closed }

class Chat {
  final String id;
  final String postId;
  final ChatStatus status;
  final DateTime createdAt;
  final List<String> participantIds;
  final String? otherUserName; // filled by the chat list query

  const Chat({
    required this.id,
    required this.postId,
    this.status = ChatStatus.pending,
    required this.createdAt,
    this.participantIds = const [],
    this.otherUserName,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      status: _status(json['status'] as String?),
      createdAt: json['created_at'] == null
          ? DateTime.now()
          : DateTime.parse(json['created_at'] as String),
      participantIds: (json['participant_ids'] is List)
          ? (json['participant_ids'] as List).map((e) => e.toString()).toList()
          : const [],
      otherUserName: json['other_user_name'] as String?,
    );
  }

  static ChatStatus _status(String? v) {
    switch (v) {
      case 'active':
        return ChatStatus.active;
      case 'closed':
        return ChatStatus.closed;
      default:
        return ChatStatus.pending;
    }
  }
}
