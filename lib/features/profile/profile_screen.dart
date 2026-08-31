// lib/features/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';
import '../../core/providers.dart';
import '../profile/settings_screen.dart';
import '../../models/user_profile.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prof = ref.watch(profileProvider);
    return Scaffold(appBar: AppBar(title: const Text('الملف الشخصي'),
      actions: [IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())))]),
      body: prof.when(data: (p) {
        if (p == null) return const Center(child: Text('لا يوجد ملف'));
        return ListView(padding: const EdgeInsets.all(16), children: [
          CircleAvatar(backgroundImage: p.avatar != null ? NetworkImage(p.avatar!) : null, radius: 36, child: p.avatar == null ? const Icon(Icons.person) : null),
          const SizedBox(height: 12),
          Text(p.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(p.city ?? '', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Chip(label: Text('⭐ ${(p.ratingAvg).toStringAsFixed(1)}  (${p.ratingCount})')),
          Chip(label: Text('نقاط: ${p.finderPoints}')),
          if (p.isVerifiedId) const Chip(label: Text('✓ موثّق')),
          const Divider(),
          ListTile(leading: const Icon(Icons.edit), title: const Text('تعديل الملف'), onTap: () {}),
          ListTile(leading: const Icon(Icons.logout), title: const Text('تسجيل الخروج'), onTap: () async => await supabase.auth.signOut()),
        ]);
      }, loading: () => const Center(child: CircularProgressIndicator()), error: (e, _) => Center(child: Text('خطأ: $e'))));
  }
}
