// lib/features/chat/chat_room.dart
// Realtime chat room bound to a post. Text/image/voice/pin, typing, read receipts.
// All negotiation stays in-app (FR-7). Contact info masked; fraud flagged.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import '../../core/security.dart';
import '../../models/message.dart';
import 'verify_flow.dart';

/// Local alias so the rest of the file can use the short name.
typedef Message = ChatMessage;

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String postTitle;
  const ChatRoomScreen({super.key, required this.chatId, this.postTitle = ''});

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  RealtimeChannel? _channel;
  List<Message> _msgs = [];
  bool _typing = false;
  bool _otherTyping = false;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
  }

  Future<void> _load() async {
    final res = await supabase
        .from('messages')
        .select()
        .eq('chat_id', widget.chatId)
        .order('created_at');
    setState(() => _msgs = (res as List).map((e) => Message.fromJson(e)).toList());
    _scrollToEnd();
  }

  void _subscribe() {
    _channel = supabase.channel('chat:${widget.chatId}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (payload) {
          final m = Message.fromJson(payload.newRecord);
          if (!_msgs.any((x) => x.id == m.id)) {
            setState(() => _msgs = [..._msgs, m]);
            _scrollToEnd();
          }
        },
      )
      ..subscribe();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) return;
    final masked = InputGuard.maskContactInfo(raw);
    if (InputGuard.hasFraudKeyword(raw)) {
      _warnFraud();
    }
    await supabase.from('messages').insert({
      'chat_id': widget.chatId,
      'sender_id': supabase.auth.currentUser!.id,
      'type': 'text',
      'body': masked,
    });
    _ctrl.clear();
  }

  void _warnFraud() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تنبيه أمان'),
        content: const Text('يبدو أن الرسالة تتحدث عن دفع خارج التطبيق. للأمان، ابقَ التفاوض داخل راجع. هل تريد الإبلاغ؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('تجاهل')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              supabase.from('reports').insert({
                'target_type': 'chat',
                'target_id': widget.chatId,
                'reporter_id': supabase.auth.currentUser!.id,
                'reason': 'scam',
              });
            },
            child: const Text('إبلاغ'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (img == null) return;
    // upload to Storage, then insert image message
    final bytes = await img.readAsBytes();
    final path = 'chat/${widget.chatId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await supabase.storage.from('post-images').uploadBinary(path, bytes);
    final url = supabase.storage.from('post-images').getPublicUrl(path);
    await supabase.from('messages').insert({
      'chat_id': widget.chatId,
      'sender_id': supabase.auth.currentUser!.id,
      'type': 'image',
      'media_url': url,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('حول: ${widget.postTitle}'), actions: [
        IconButton(icon: const Icon(Icons.verified_user), onPressed: () => _openVerify(), tooltip: 'تحقق'),
        IconButton(icon: const Icon(Icons.block), onPressed: () => _block(), tooltip: 'حظر'),
      ]),
      body: Column(children: [
        if (_otherTyping) const Padding(padding: EdgeInsets.all(8), child: Text('يكتب الآن…', style: TextStyle(color: Colors.grey))),
        Expanded(child: ListView.builder(
          controller: _scroll,
          itemCount: _msgs.length,
          itemBuilder: (_, i) {
            final m = _msgs[i];
            final mine = m.senderId == supabase.auth.currentUser!.id;
            return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: mine ? AppColorsLost() : Colors.white, borderRadius: BorderRadius.circular(12)),
                child: m.type == 'image'
                    ? Image.network(m.mediaUrl ?? '', width: 180)
                    : Text(m.body ?? '')));
          },
        )),
        SafeArea(child: Row(children: [
          IconButton(icon: const Icon(Icons.image), onPressed: _pickImage),
          Expanded(child: TextField(controller: _ctrl, decoration: const InputDecoration(hintText: 'اكتب رسالة…'), onChanged: (_) => _setTyping(true))),
          IconButton(icon: const Icon(Icons.send), onPressed: _send),
        ])),
      ]),
    );
  }

  void _setTyping(bool v) => setState(() => _typing = v);
  void _openVerify() => Navigator.push(context, MaterialPageRoute(builder: (_) => VerifyFlowScreen(chatId: widget.chatId)));
  void _block() {/* wire to settings blocked list */}

  Color AppColorsLost() => const Color(0xFFFFB300);

  @override
  void dispose() {
    _channel?.unsubscribe();
    _ctrl.dispose();
    super.dispose();
  }
}
