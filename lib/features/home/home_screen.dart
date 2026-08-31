// lib/features/home/home_screen.dart
// FR-4: Map/Feed toggle. Map uses flutter_map with custom pins (amber=lost,
// green=found), lightweight client-side clustering, and a translucent zone circle.
// Feed lists posts sorted by distance then recency. Reads via supabase RLS.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';
import '../../core/constants.dart';
import '../../core/repository.dart';
import '../../core/geo.dart';
import '../../models/post.dart';
import '../../models/category.dart';
import '../post/post_detail_screen.dart';
import '../chat/chat_list.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _mapView = true;
  List<Post> _posts = [];
  List<Category> _cats = [];
  Map<int, Category> get _catMap => {for (final c in _cats) c.id: c};
  LatLng _center = const LatLng(36.8065, 10.1815); // Tunis default
  final _mapCtrl = MapController();
  bool _loading = true;
  Post? _preview;
  RealtimeChannel? _sub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadLocation();
    await _load();
    _subscribe();
  }

  Future<void> _loadLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
      _center = LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      // Permission denied or unavailable: keep default center.
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final posts = await Repository.getOpenPosts();
      final cats = await Repository.getCategories();
      // attach distance from current center
      for (final p in posts) {
        p.distanceM = distanceMeters(_center, LatLng(p.lat, p.lng));
      }
      posts.sort((a, b) => (a.distanceM ?? 1e9).compareTo(b.distanceM ?? 1e9));
      if (mounted) {
        setState(() {
          _posts = posts;
          _cats = cats;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribe() {
    _sub = supabase
        .channel('public:posts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'posts',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _sub?.unsubscribe();
    super.dispose();
  }

  List<Marker> get _markers {
    final markers = <Marker>[];
    // Lightweight grid clustering (~2km cells).
    final Map<String, List<Post>> cells = {};
    for (final p in _posts) {
      final k = '${(p.lat / 0.02).floor()}_${(p.lng / 0.02).floor()}';
      cells.putIfAbsent(k, () => []).add(p);
    }
    for (final entry in cells.entries) {
      final list = entry.value;
      if (list.length == 1) {
        final p = list.first;
        markers.add(Marker(
          point: LatLng(p.lat, p.lng),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => _openPreview(p),
            child: Icon(
              Icons.location_pin,
              color: p.isLost ? AppColors.lost : AppColors.found,
              size: 38,
            ),
          ),
        ));
      } else {
        // cluster bubble
        final lat = list.map((e) => e.lat).reduce((a, b) => a + b) / list.length;
        final lng = list.map((e) => e.lng).reduce((a, b) => a + b) / list.length;
        markers.add(Marker(
          point: LatLng(lat, lng),
          width: 56,
          height: 56,
          child: GestureDetector(
            onTap: () => _mapCtrl.move(LatLng(lat, lng), 14),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.brand.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('${list.length}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ));
      }
    }
    return markers;
  }

  void _openPreview(Post p) => setState(() => _preview = p);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('راجع'),
        actions: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, icon: Icon(Icons.map), label: Text('الخريطة')),
              ButtonSegment(value: false, icon: Icon(Icons.list), label: Text('القائمة')),
            ],
            selected: {_mapView},
            onSelectionChanged: (s) => setState(() => _mapView = s.first),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _mapView
              ? Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapCtrl,
                      options: MapOptions(
                        center: _center,
                        zoom: 12,
                        onTap: (_, __) => setState(() => _preview = null),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.rajaa.app',
                          maxZoom: 19,
                        ),
                        if (_preview != null)
                          CircleLayer(circles: [
                            CircleMarker(
                              point: LatLng(_preview!.lat, _preview!.lng),
                              radius: _preview!.radiusM.toDouble(),
                              useRadiusInMeter: true,
                              color: (_preview!.isLost ? AppColors.lost : AppColors.found)
                                  .withOpacity(0.18),
                              borderColor: _preview!.isLost ? AppColors.lost : AppColors.found,
                              borderStrokeWidth: 1.5,
                            ),
                          ]),
                        MarkerLayer(markers: _markers),
                      ],
                    ),
                    if (_preview != null) _PreviewCard(post: _preview!, catName: _catMap[_preview!.categoryId]?.localizedName),
                  ],
                )
              : _FeedList(posts: _posts, catMap: _catMap, center: _center),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/post/new'),
        icon: const Icon(Icons.add),
        label: const Text('نشر إعلان'),
      ),
      bottomNavigationBar: _BottomNav(),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final Post post;
  final String? catName;
  const _PreviewCard({required this.post, this.catName});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Row(
          children: [
            Icon(Icons.location_pin,
                color: post.isLost ? AppColors.lost : AppColors.found),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${post.isLost ? 'مفقود' : 'موجود'} • ${catName ?? ''}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.push('/post/${post.id}'),
              child: const Text('التفاصيل'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedList extends StatelessWidget {
  final List<Post> posts;
  final Map<int, Category> catMap;
  final LatLng center;
  const _FeedList({required this.posts, required this.catMap, required this.center});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Center(child: Text('لا توجد إعلانات قريبة بعد.'));
    }
    return ListView.separated(
      itemCount: posts.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final p = posts[i];
        final d = p.distanceM != null ? (p.distanceM! / 1000).toStringAsFixed(1) : '؟';
        return ListTile(
          leading: Icon(Icons.location_pin,
              color: p.isLost ? AppColors.lost : AppColors.found, size: 32),
          title: Text(p.title),
          subtitle: Text('${p.isLost ? 'مفقود' : 'موجود'} • ${catMap[p.categoryId]?.localizedName ?? ''} • $d كم'),
          trailing: p.rewardType != null && p.rewardType != RewardType.none
              ? const Icon(Icons.paid, color: AppColors.brand)
              : null,
          onTap: () => context.push('/post/${p.id}'),
        );
      },
    );
  }
}

class _BottomNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: 0,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home), label: 'الرئيسية'),
        NavigationDestination(icon: Icon(Icons.chat), label: 'المحادثات'),
        NavigationDestination(icon: Icon(Icons.notifications), label: 'الإشعارات'),
        NavigationDestination(icon: Icon(Icons.person), label: 'حسابي'),
      ],
      onDestinationSelected: (i) {
        switch (i) {
          case 1:
            context.go('/chat');
            break;
          case 2:
            context.go('/notifications');
            break;
          case 3:
            context.go('/profile');
            break;
        }
      },
    );
  }
}
