// lib/features/auth/onboarding.dart
// FR-1 onboarding: 3 screens + permission requests (location/notifications/camera).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import '../../core/repository.dart';
import '../../core/constants.dart';
import '../../models/user_profile.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _idx = 0;
  bool _busy = false;

  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  Future<void> _requestPermissions() async {
    // Location (geolocator). Notifications (FCM). Camera (permission_handler).
    await Geolocator.requestPermission();
    await FirebaseMessaging.instance.requestPermission();
    await Permission.camera.request();
  }

  Future<void> _finish() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      // Create the profile row (RLS: auth.uid() = id). Onboarding completes here.
      await Repository.upsertProfile(UserProfile(
        id: user.id,
        name: _nameCtrl.text.trim().isEmpty
            ? (user.email?.split('@').first ?? 'مستخدم')
            : _nameCtrl.text.trim(),
        email: user.email,
        phone: user.phone,
        city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
      ));
      // Store FCM token now that the profile exists.
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await Repository.registerDeviceToken(token);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذّر الحفظ: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعداد حسابك')),
      body: PageView(
        controller: _page,
        onPageChanged: (i) => setState(() => _idx = i),
        children: [
          _Page(
            icon: Icons.search_rounded,
            title: 'مرحباً بك في راجع',
            body: 'حوّل كل شخص قريب منك إلى مساعد في العثور على أغراضك المفقودة.',
          ),
          _Page(
            icon: Icons.location_on,
            title: 'الموقع',
            body: 'نحتاج موقعك لإشعارك بالأغراض المفقودة والموجودة القريبة منك. '
                'موقعك يبقى خاصاً ولا يُنشر أبداً.',
            action: ElevatedButton(
              onPressed: _requestPermissions,
              child: const Text('اسمح بالموقع'),
            ),
          ),
          _Page(
            icon: Icons.notifications_active,
            title: 'الإشعارات والكاميرا',
            body: 'فعّل الإشعارات لتنبيهات المناطق، والكاميرا لإضافة صور ومستندات.',
            action: ElevatedButton(
              onPressed: _requestPermissions,
              child: const Text('اسمح بالإشعارات والكاميرا'),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: _idx < 2
            ? FilledButton(
                onPressed: () => _page.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.ease,
                ),
                child: const Text('متابعة'),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم العرض',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _cityCtrl,
                    decoration: const InputDecoration(
                      labelText: 'مدينتك (اختياري)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _busy
                      ? const CircularProgressIndicator()
                      : FilledButton(
                          onPressed: _finish,
                          child: const Text('إنهاء وبدء الاستخدام'),
                        ),
                ],
              ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  const _Page({required this.icon, required this.title, required this.body, this.action});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 96, color: AppColors.brand),
            const SizedBox(height: 24),
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(body, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      );
}

/// Lightweight profile stub used only to create the row during onboarding.
/// (We just use UserProfile directly; the stub is removed to avoid an extends bug.)
