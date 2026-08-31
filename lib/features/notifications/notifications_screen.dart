// lib/features/notifications/notifications_screen.dart
// Grouped inbox (FR-10). Toggleable per group via users.settings_json.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';
import '../../core/constants.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _items = [];
  Map<String, dynamic> _prefs = {};
  @override
  void initState() { super.initState; _load(); }
  void _load() async {
    final res = await supabase.from('notifications').select().order('created_at', ascending: false).limit(50);
    final prof = await supabase.from('users').select('settings_json').eq('id', supabase.auth.currentUser!.id).maybeSingle();
    setState(() { _items = res as List; _prefs = {...?(prof?['settings_json'] as Map? ?? {}).cast<String, dynamic>(); });
  }
  void _toggle(String group, bool v) async {
    _prefs['notif_$group'] = v;
    await supabase.from('users').update({'settings_json': _prefs}).eq('id', supabase.auth.currentUser!.id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('الإشعارات')),
      body: ListView(children: [
        ...kNotificationGroups.entries.map((e) => SwitchListTile(
          title: Text(e.value), value: _prefs['notif_${e.key}'] != false,
          onChanged: (v) => _toggle(e.key, v))),
        const Divider(),
        ..._items.map((n) => ListTile(title: Text((n['payload_json']?['title'] ?? 'إشعار')?.toString() ?? 'إشعار'),
          subtitle: Text(n['type'] ?? ''), trailing: n['read_at'] == null ? const Icon(Icons.circle, size: 10, color: Colors.amber) : null)),
      ]));
  }
}
