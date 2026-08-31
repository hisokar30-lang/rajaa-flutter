// lib/core/supabase.dart
// Central Supabase client. Uses the publishable (anon) key only — NEVER service_role in client.
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const url = 'https://jxdjecujxlvitrrfgkjf.supabase.co';
  // Publishable key (anon) — safe for client.
  static const anonKey =
      'sb_publishable_pbgJuKQCH1HlBED8QEfdbQ_1Uiboffu';
}

final supabase = Supabase.instance.client;

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
}
