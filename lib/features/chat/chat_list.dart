// lib/features/chat/chat_list.dart
// FR-7: list of the current user's chats (RLS: chat_participants).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/repository.dart';
import '../../models/chat.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Chat> _chats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final chats = await Repository.getChats();
      if (mounted) setState(() => _chats = chats);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المحادثات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
              ? const Center(child: Text('لا محادثات بعد. افتح محادثة من تفاصيل إعلان.'))
              : ListView.separated(
                  itemCount: _chats.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final c = _chats[i];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.chat_bubble_outline)),
                      title: Text(c.otherUserName ?? 'محادثة'),
                      subtitle: Text(c.status == ChatStatus.active ? 'نشطة' : 'بانتظار القبول'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => context.push('/chat/${c.id}'),
                    );
                  },
                ),
    );
  }
}
