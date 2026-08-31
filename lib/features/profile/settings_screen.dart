// lib/features/profile/settings_screen.dart
// Privacy, zone-alert prefs, blocked users, language, delete account (FR-1.4, FR-4/FR-5).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';
import '../../core/repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Map<String, dynamic> _s = {};
  @override
  void initState() { super.initState; _load(); }
  void _load() async {
    final p = await Repository.fetchProfile(supabase.auth.currentUser!.id);
    if (p != null && mounted) setState(() => _s = {...?p.settingsJson});
  }
  Future<void> _save() async => await Repository.updateSettings(_s);

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(children: [
        SwitchListTile(title: const Text('إخفاء الملف من الخريطة/القائمة'), value: _s['hide_profile'] == true,
          onChanged: (v) => setState(() { _s['hide_profile'] = v; _save(); })),
        SwitchListTile(title: const Text('تنبيهات المناطق'), value: _s['zone_alerts'] != false,
          onChanged: (v) => setState(() { _s['zone_alerts'] = v; _save(); })),
        ListTile(title: const Text('ساعات الصمت (مثال: 22:00–08:00)'),
          subtitle: Text('${_s['quiet_start'] ?? '22:00'} — ${_s['quiet_end'] ?? '08:00'}'),
          onTap: () {/* time pickers */ _save(); }),
        ListTile(title: const Text('أقصى عدد تنبيهات/يوم'), trailing: DropdownButton<int>(
          value: _s['max_alerts_day'] ?? 10, items: [5,10,20,50].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
          onChanged: (v) => setState(() { _s['max_alerts_day'] = v; _save(); }))),
        ListTile(title: const Text('اللغة'), trailing: DropdownButton<String>(
          value: _s['lang'] ?? 'ar', items: const [DropdownMenuItem(value: 'ar', child: Text('العربية')), DropdownMenuItem(value: 'en', child: Text('English'))],
          onChanged: (v) => setState(() { _s['lang'] = v; _save(); }))),
        ListTile(leading: const Icon(Icons.block), title: const Text('المستخدمون المحظورون'), onTap: () {}),
        ListTile(leading: const Icon(Icons.delete_forever, color: Colors.red), title: const Text('حذف الحساب'), onTap: () async {
          final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('حذف الحساب؟'), content: const Text('لا يمكن التراجع.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف'))]));
          if (ok == true) await supabase.rpc('delete_account'); // Edge fn or RLS-guarded
        }),
      ]));
  }
}
