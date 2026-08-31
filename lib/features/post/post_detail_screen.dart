// lib/features/post/post_detail_screen.dart
// FR-6: preview, reactions, comments, share deep link, report, contact->chat invite.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong2.dart';
import 'package:intl/intl.dart' as intl;
import '../../core/constants.dart';
import '../../core/repository.dart';
import '../../core/supabase.dart';
import '../../models/post.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Post? _post;
  String? _ownerName;
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  final _commentCtrl = TextEditingController();
  bool _reacting = false;

  final _reactions = const [
    ('helpful', 'مفيد', Icons.thumb_up),
    ('hope', 'أمل', Icons.favorite),
    ('saw', 'شاهدته', Icons.visibility),
    ('boost', 'تعزيز', Icons.local_fire_department),
    ('pray', 'دعاء', Icons.volunteer_activism),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await Repository.getPost(widget.postId);
      final owner = await supabase
          .from('users')
          .select('name')
          .eq('id', p.userId)
          .maybeSingle();
      final comments = await supabase
          .from('comments')
          .select('id, body, created_at, users(name)')
          .eq('post_id', widget.postId)
          .order('created_at', ascending: true);
      if (mounted) {
        setState(() {
          _post = p;
          _ownerName = (owner as Map?) != null ? owner['name'] as String? : null;
          _comments = List<Map<String, dynamic>>.from(comments as List);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _react(String type) async {
    if (_reacting) return;
    setState(() => _reacting = true);
    try {
      await Repository.react(widget.postId, type);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل تفاعلك')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر: $e')));
    } finally {
      if (mounted) setState(() => _reacting = false);
    }
  }

  Future<void> _addComment() async {
    final t = _commentCtrl.text.trim();
    if (t.isEmpty) return;
    try {
      await Repository.comment(widget.postId, t);
      _commentCtrl.clear();
      await _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر: $e')));
    }
  }

  Future<void> _share() async {
    await Clipboard.setData(ClipboardData(text: 'https://rajaa.app/post/${widget.postId}'));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ رابط المشاركة')));
  }

  Future<void> _report() async {
    final reasons = ['scam', 'spam', 'stolen', 'offensive', 'other'];
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('إبلاغ عن هذا الإعلان'),
        children: reasons
            .map((r) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, r),
                  child: Text(r),
                ))
            .toList(),
      ),
    );
    if (reason != null) {
      await Repository.report(targetType: 'post', targetId: widget.postId, reason: reason);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('شكراً، تم تلقّي بلاغك')));
    }
  }

  Future<void> _contact() async {
    if (_post == null) return;
    try {
      final chatId = await Repository.createChat(_post!.id, _post!.userId);
      if (mounted) context.push('/chat/$chatId');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر فتح المحادثة: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _post == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final p = _post!;
    return Scaffold(
      appBar: AppBar(
        title: Text(p.isLost ? 'إعلان مفقود' : 'إعلان موجود'),
        actions: [
          IconButton(onPressed: _share, icon: const Icon(Icons.share)),
          IconButton(onPressed: _report, icon: const Icon(Icons.flag)),
        ],
      ),
      body: ListView(
        children: [
          if (p.images.isNotEmpty)
            SizedBox(
              height: 220,
              child: PageView(children: p.images.map((u) => Image.network(u, fit: BoxFit.cover)).toList()),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_pin,
                        color: p.isLost ? AppColors.lost : AppColors.found),
                    const SizedBox(width: 6),
                    Text(p.isLost ? 'مفقود' : 'موجود',
                        style: TextStyle(
                            color: p.isLost ? AppColors.lost : AppColors.found,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text(_ownerName ?? ''),
                  ],
                ),
                const SizedBox(height: 8),
                Text(p.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                if (p.description != null && p.description!.isNotEmpty)
                  Text(p.description!, style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 8),
                if (p.rewardType != RewardType.none)
                  Chip(
                    label: Text(
                      'مكافأة: ${p.rewardType.label}'
                      '${p.rewardAmount != null ? ' (${p.rewardAmount} ${p.currency})' : ''}',
                    ),
                    backgroundColor: AppColors.brand.withOpacity(0.15),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 160,
                  child: FlutterMap(
                    options: MapOptions(center: LatLng(p.lat, p.lng), zoom: 13, interactiveFlags: 0),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.rajaa.app',
                      ),
                      CircleLayer(circles: [
                        CircleMarker(
                          point: LatLng(p.lat, p.lng),
                          radius: p.radiusM.toDouble(),
                          useRadiusInMeter: true,
                          color: (p.isLost ? AppColors.lost : AppColors.found).withOpacity(0.18),
                          borderColor: p.isLost ? AppColors.lost : AppColors.found,
                          borderStrokeWidth: 1.5,
                        ),
                      ]),
                      MarkerLayer(markers: [
                        Marker(
                          point: LatLng(p.lat, p.lng),
                          width: 40,
                          height: 40,
                          child: Icon(Icons.location_pin,
                              color: p.isLost ? AppColors.lost : AppColors.found, size: 38),
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('تفاعل', style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 8,
                  children: _reactions
                      .map((r) => ActionChip(
                            avatar: Icon(r.$3, size: 18),
                            label: Text(r.$2),
                            onPressed: () => _react(r.$1),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _contact,
                  icon: const Icon(Icons.chat),
                  label: const Text('تواصل مع صاحب الإعلان'),
                ),
                const Divider(height: 24),
                const Text('التعليقات', style: TextStyle(fontWeight: FontWeight.bold)),
                ..._comments.map((c) {
                      final u = c['users'];
                      final name = u is List && u.isNotEmpty
                          ? u.first['name']
                          : (u is Map ? u['name'] : null);
                      return ListTile(
                        title: Text(c['body'] as String? ?? ''),
                        subtitle: Text(
                          '$name • '
                          '${intl.DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(c['created_at']))}',
                        ),
                      );
                    }),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentCtrl,
                        decoration: const InputDecoration(
                          hintText: 'أضف تعليقاً…',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(onPressed: _addComment, icon: const Icon(Icons.send)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
