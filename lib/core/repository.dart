// lib/core/repository.dart
// Centralized DB access. Every write goes through here so InputGuard validation,
// RLS-friendly inserts, and private-identifier encryption happen in ONE place.
// SECURITY: we only ever use the anon client (supabase). RLS is the real guard.
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/post.dart';
import '../models/category.dart';
import '../models/user_profile.dart';
import '../models/chat.dart';
import '../models/message.dart';
import 'supabase.dart';
import 'security.dart';
import 'constants.dart';
import 'geo.dart';

class Repository {
  const Repository._();

  static String get _uid {
    final u = supabase.auth.currentUser;
    if (u == null) throw Exception('غير مسجّل الدخول');
    return u.id;
  }

  // ---------- User profile ----------
  static Future<UserProfile?> fetchProfile(String id) async {
    final res = await supabase
        .from('users')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (res == null) return null;
    return UserProfile.fromJson(res as Map<String, dynamic>);
  }

  /// Upsert the current user's profile (RLS: auth.uid() = id).
  static Future<UserProfile> upsertProfile(UserProfile p) async {
    final res = await supabase
        .from('users')
        .upsert(p.toJson(), onConflict: 'id')
        .select()
        .single();
    return UserProfile.fromJson(res as Map<String, dynamic>);
  }

  static Future<void> updateSettings(Map<String, dynamic> settings) async {
    await supabase.from('users').update({'settings_json': settings}).eq('id', _uid);
  }

  /// Persist the FCM device token inside settings_json (no dedicated column in
  /// the schema; settings_json is jsonb and is the right place). Only updates
  /// when a profile row already exists (onboarding creates it).
  static Future<void> registerDeviceToken(String token) async {
    final cur = await fetchProfile(_uid);
    if (cur == null) return; // onboarding will register it
    final s = <String, dynamic>{...?cur.settingsJson};
    s['fcm_token'] = token;
    await updateSettings(s);
  }

  // ---------- Categories ----------
  static Future<List<Category>> getCategories() async {
    final res = await supabase
        .from('categories')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return (res as List)
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------- Posts ----------
  static Future<List<Post>> getOpenPosts() async {
    final res = await supabase
        .from('posts')
        .select()
        .eq('status', 'open')
        .order('created_at', ascending: false);
    return (res as List)
        .map((e) => Post.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Post> getPost(String id) async {
    final res =
        await supabase.from('posts').select().eq('id', id).single();
    return Post.fromJson(res as Map<String, dynamic>);
  }

  /// Upload up to 5 photos to Storage (public bucket) and return URLs.
  /// Images are uploaded BEFORE the post insert (security: no temp rows).
  static Future<List<String>> uploadPhotos(List<XFile> photos) async {
    final urls = <String>[];
    for (final photo in photos.take(5)) {
      final file = File(photo.path);
      final ext = photo.path.split('.').last;
      final path = '$_uid/${DateTime.now().microsecondsSinceEpoch}_${urls.length}.$ext';
      await supabase.storage.from(kImageBucket).upload(path, file);
      urls.add(supabase.storage.from(kImageBucket).getPublicUrl(path));
    }
    return urls;
  }

  /// Create a post. Validates inputs (InputGuard) and encrypts private
  /// identifiers client-side before insert. Returns the created Post.
  static Future<Post> createPost({
    required PostType type,
    required int categoryId,
    required String title,
    String? description,
    required List<XFile> photos,
    String? privateIdentifiers,
    required double lat,
    required double lng,
    required int radiusM,
    RewardType rewardType = RewardType.none,
    double? rewardAmount,
    required String currency,
  }) async {
    // SECURITY: validate inputs before any insert.
    final titleErr = InputGuard.validateTitle(title);
    if (titleErr != null) throw Exception(titleErr);
    final descErr = InputGuard.validateDescription(description);
    if (descErr != null) throw Exception(descErr);

    final images = await uploadPhotos(photos);

    // SECURITY: private identifiers encrypted client-side (field-level). The
    // session key would normally come from an Edge Function (/crypto/key); the
    // security.dart envelopePrivate placeholder is used here pending that.
    final enc = privateIdentifiers == null || privateIdentifiers.isEmpty
        ? null
        : envelopePrivate(privateIdentifiers, 'rajaa-local-placeholder-$_uid');

    final post = Post(
      id: '', // assigned by DB
      userId: _uid,
      type: type,
      categoryId: categoryId,
      title: title.trim(),
      description: description?.trim(),
      images: images,
      privateIdentifiersEnc: enc,
      lat: lat,
      lng: lng,
      radiusM: radiusM,
      precision: 'exact', // PRD decision: exact pin precision
      rewardType: rewardType,
      rewardAmount: rewardAmount,
      currency: currency,
      status: PostStatus.open,
      createdAt: DateTime.now(),
    );

    final res = await supabase
        .from('posts')
        .insert(post.toInsert())
        .select()
        .single();
    return Post.fromJson(res as Map<String, dynamic>);
  }

  // ---------- Reactions / Comments ----------
  static Future<void> react(String postId, String type) async {
    await supabase.from('reactions').insert({
      'post_id': postId,
      'user_id': _uid,
      'type': type,
    });
  }

  static Future<void> comment(String postId, String body) async {
    final err = InputGuard.validateDescription(body);
    if (err != null) throw Exception(err);
    // SECURITY: mask contact info even in comments.
    final safe = InputGuard.maskContactInfo(body.trim());
    await supabase.from('comments').insert({
      'post_id': postId,
      'user_id': _uid,
      'body': safe,
    });
  }

  static Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
  }) async {
    await supabase.from('reports').insert({
      'target_type': targetType,
      'target_id': targetId,
      'reporter_id': _uid,
      'reason': reason,
    });
  }

  // ---------- Chat ----------
  /// Create (or reuse) a chat for a post. Inserts chat + both participants.
  /// NOTE: requires an INSERT policy on chat_participants (see README backend note).
  static Future<String> createChat(String postId, String ownerId) async {
    // If the post owner is the current user, we can't start a chat with ourselves.
    if (ownerId == _uid) throw Exception('لا يمكن فتح محادثة مع نفسك');

    final existing = await supabase
        .from('chats')
        .select('id')
        .eq('post_id', postId)
        .limit(1);
    if (existing is List && existing.isNotEmpty) {
      return (existing.first as Map)['id'] as String;
    }

    final chatRes = await supabase
        .from('chats')
        .insert({'post_id': postId, 'status': 'pending'}).select().single();
    final chatId = (chatRes as Map)['id'] as String;

    await supabase.from('chat_participants').insert([
      {'chat_id': chatId, 'user_id': ownerId, 'role': 'owner'},
      {'chat_id': chatId, 'user_id': _uid, 'role': 'claimer'},
    ]);
    return chatId;
  }

  static Future<List<Chat>> getChats() async {
    final res = await supabase
        .from('chats')
        .select('id, post_id, status, created_at')
        .order('created_at', ascending: false);
    final list = (res as List).cast<Map<String, dynamic>>();
    final out = <Chat>[];
    for (final c in list) {
      final parts = await supabase
          .from('chat_participants')
          .select('user_id')
          .eq('chat_id', c['id']);
      final ids = (parts as List)
          .map((e) => (e as Map)['user_id'] as String)
          .toList();
      final other = ids.where((id) => id != _uid).toList();
      String? otherName;
      if (other.isNotEmpty) {
        final u = await supabase
            .from('users')
            .select('name')
            .eq('id', other.first)
            .maybeSingle();
        otherName = (u as Map?) != null ? u['name'] as String? : null;
      }
      out.add(Chat(
        id: c['id'] as String,
        postId: c['post_id'] as String,
        status: ChatStatus.values.firstWhere(
            (s) => s.name == (c['status'] as String? ?? 'pending'),
            orElse: () => ChatStatus.pending),
        createdAt: DateTime.parse(c['created_at'] as String),
        participantIds: ids,
        otherUserName: otherName,
      ));
    }
    return out;
  }

  static Future<List<ChatMessage>> getMessages(String chatId) async {
    final res = await supabase
        .from('messages')
        .select()
        .eq('chat_id', chatId)
        .order('created_at', ascending: true);
    return (res as List)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<ChatMessage> sendMessage(ChatMessage msg) async {
    // SECURITY: mask contact info in any text body.
    final body = msg.body == null ? null : InputGuard.maskContactInfo(msg.body!);
    final res = await supabase
        .from('messages')
        .insert({
          'chat_id': msg.chatId,
          'sender_id': _uid,
          'type': msg.type.name,
          'body': body,
          'media_url': msg.mediaUrl,
        })
        .select()
        .single();
    return ChatMessage.fromJson(res as Map<String, dynamic>);
  }

  // ---------- Verification flow ----------
  static Future<void> submitVerification({
    required String chatId,
    required String method, // 'photo' | 'serial' | 'detail'
    required List<String> proofUrls,
    String? detailQuestion,
  }) async {
    await supabase.from('verifications').insert({
      'chat_id': chatId,
      'proof_media': proofUrls,
      'method': method,
      'result': null, // pending
    });
    // Also drop a 'verify' message into the chat so the other party sees it.
    await supabase.from('messages').insert({
      'chat_id': chatId,
      'sender_id': _uid,
      'type': 'verify',
      'body': detailQuestion ?? method,
    });
  }

  static Future<void> decideVerification({
    required String chatId,
    required int verificationId,
    required bool accept,
  }) async {
    await supabase.from('verifications').update({
      'result': accept ? 'verified' : 'rejected',
      'decided_by': _uid,
      'decided_at': DateTime.now().toIso8601String(),
    }).eq('id', verificationId);
    if (accept) {
      await supabase
          .from('chats')
          .update({'status': 'active'}).eq('id', chatId);
    }
  }

  // ---------- Notifications ----------
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final res = await supabase
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(100);
    return (res as List).cast<Map<String, dynamic>>();
  }

  static Future<void> markNotificationRead(int id) async {
    await supabase
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()}).eq('id', id);
  }
}
