// lib/features/post/create_post_wizard.dart
// FR-3: lost/found wizard. Step1 type, Step2 category/title/desc/photos/private
// ids, Step3 pin drop + radius (1-5km). Images uploaded + private ids encrypted
// client-side before insert (Repository enforces this).
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants.dart';
import '../../core/repository.dart';
import '../../core/security.dart';
import '../../core/geo.dart';
import '../../models/post.dart';
import '../../models/category.dart';

class CreatePostWizard extends StatefulWidget {
  const CreatePostWizard({super.key});

  @override
  State<CreatePostWizard> createState() => _CreatePostWizardState();
}

class _CreatePostWizardState extends State<CreatePostWizard> {
  final _page = PageController();
  int _step = 0;

  PostType _type = PostType.lost;
  Category? _category;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _privCtrl = TextEditingController();
  List<XFile> _photos = [];
  String _currency = kDefaultCurrency;

  LatLng _pin = const LatLng(36.8065, 10.1815);
  int _radiusM = 2000;
  bool _geoReady = false;

  @override
  void initState() {
    super.initState();
    _initGeo();
  }

  Future<void> _initGeo() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (mounted) setState(() => _pin = LatLng(pos.latitude, pos.longitude));
    } catch (_) {}
    if (mounted) setState(() => _geoReady = true);
  }

  Future<void> _pickPhotos() async {
    final imgs = await ImagePicker().pickMultiImage(limit: 5);
    if (imgs.isNotEmpty) setState(() => _photos = _photos + imgs..take(5 - _photos.length));
  }

  void _removePhoto(int i) => setState(() => _photos.removeAt(i));

  Future<void> _submit() async {
    if (_category == null) return _err('اختر الفئة');
    final tErr = InputGuard.validateTitle(_titleCtrl.text);
    if (tErr != null) return _err(tErr);
    if (!_geoReady) return _err('جارٍ تحديد الموقع…');

    try {
      final post = await Repository.createPost(
        type: _type,
        categoryId: _category!.id,
        title: _titleCtrl.text,
        description: _descCtrl.text,
        photos: _photos,
        privateIdentifiers: _privCtrl.text,
        lat: _pin.latitude,
        lng: _pin.longitude,
        radiusM: _radiusM,
        currency: _currency,
      );
      if (mounted) context.go('/post/${post.id}');
    } catch (e) {
      _err('تعذّر النشر: $e');
    }
  }

  void _err(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعلان جديد')),
      body: PageView(
        controller: _page,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _step1(),
          _step2(),
          _step3(),
        ],
      ),
      bottomNavigationBar: _navBar(),
    );
  }

  Widget _navBar() => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (_step > 0)
              TextButton(onPressed: _back, child: const Text('السابق')),
            const Spacer(),
            FilledButton(
              onPressed: _step < 2 ? _next : _submit,
              child: Text(_step < 2 ? 'التالي' : 'نشر'),
            ),
          ],
        ),
      );

  void _next() {
    if (_step == 1) {
      final t = InputGuard.validateTitle(_titleCtrl.text);
      if (t != null) return _err(t);
      if (_category == null) return _err('اختر الفئة');
    }
    _page.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
    setState(() => _step++);
  }

  void _back() {
    _page.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
    setState(() => _step--);
  }

  Widget _step1() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('هل فقدت شيئاً أم وجدته؟', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SegmentedButton<PostType>(
              segments: const [
                ButtonSegment(value: PostType.lost, icon: Icon(Icons.search_off), label: Text('مفقود')),
                ButtonSegment(value: PostType.found, icon: Icon(Icons.search), label: Text('موجود')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
          ],
        ),
      );

  Widget _step2() => FutureBuilder<List<Category>>(
        future: Repository.getCategories(),
        builder: (ctx, snap) {
          final cats = snap.data ?? [];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الفئة', style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 8,
                  children: cats
                      .map((c) => ChoiceChip(
                            label: Text('${c.icon ?? ''} ${c.localizedName}'),
                            selected: _category?.id == c.id,
                            onSelected: (_) => setState(() => _category = c),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'العنوان', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'الوصف', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _privCtrl,
                  decoration: const InputDecoration(
                    labelText: 'معرّفات خاصة (سرية، تُشفّر)',
                    hintText: 'رقم تسلسلي، علامة مميزة… يراها المالك فقط عند التحقق',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('العملة:'),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _currency,
                      items: kCurrencies
                          .map((c) => DropdownMenuItem(value: c['code']!, child: Text('${c['name']} (${c['symbol']})')))
                          .toList(),
                      onChanged: (v) => setState(() => _currency = v!),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('صور (حتى 5)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._photos.asMap().entries.map((e) => Stack(
                          children: [
                            Image.file(File(e.value.path), width: 80, height: 80, fit: BoxFit.cover),
                            Positioned(
                              top: -6,
                              left: -6,
                              child: IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.red),
                                onPressed: () => _removePhoto(e.key),
                              ),
                            ),
                          ],
                        )),
                    InkWell(
                      onTap: _pickPhotos,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.muted),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add_a_photo),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );

  Widget _step3() => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text('حدّد الموقع على الخريطة واختر نطاق التنبيه'),
            Expanded(
              child: FlutterMap(
                options: MapOptions(
                  center: _pin,
                  zoom: 13,
                  onTap: (_, p) => setState(() => _pin = p),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.rajaa.app',
                  ),
                  CircleLayer(circles: [
                    CircleMarker(
                      point: _pin,
                      radius: _radiusM.toDouble(),
                      useRadiusInMeter: true,
                      color: (_type == PostType.lost ? AppColors.lost : AppColors.found).withOpacity(0.18),
                      borderColor: _type == PostType.lost ? AppColors.lost : AppColors.found,
                      borderStrokeWidth: 1.5,
                    ),
                  ]),
                  MarkerLayer(markers: [
                    Marker(
                      point: _pin,
                      width: 40,
                      height: 40,
                      child: Icon(Icons.location_pin,
                          color: _type == PostType.lost ? AppColors.lost : AppColors.found, size: 38),
                    ),
                  ]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text('النطاق:'),
                  Expanded(
                    child: Slider(
                      min: 1000,
                      max: 5000,
                      divisions: 8,
                      label: '${(_radiusM / 1000).toStringAsFixed(1)} كم',
                      value: _radiusM.toDouble(),
                      onChanged: (v) => setState(() => _radiusM = v.round()),
                    ),
                  ),
                  Text('${(_radiusM / 1000).toStringAsFixed(1)} كم'),
                ],
              ),
            ),
          ],
        ),
      );
}
