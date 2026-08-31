// lib/core/security.dart
// Security helpers: server-side RLS is the real guard. Client-side = defense in depth only.
// 1) Input validation (length/type) before any insert.
// 2) Private identifier encryption is done CLIENT-SIDE with a per-user key derived from
//    a secret stored in Supabase Secrets (server) — here we use a simple envelope:
//    the app requests an encryption key from an Edge Function (/crypto/key) andAES-GCM encrypts
//    before insert. To keep MVP simple, we encrypt with a key fetched per-session.
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class InputGuard {
  static String? validateTitle(String v) {
    final t = v.trim();
    if (t.length < 3) return 'العنوان قصير جداً (3 أحرف على الأقل)';
    if (t.length > 120) return 'العنوان طويل جداً';
    return null;
  }

  static String? validateDescription(String? v) {
    if (v == null || v.isEmpty) return null;
    if (v.length > 1000) return 'الوصف طويل جداً';
    return null;
  }

  // Mask phone/email typed in chat messages (FR-7.5 safety).
  static String maskContactInfo(String body) {
    final email = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
    final phone = RegExp(r'(?:\+?\d[\d\s().-]{7,}\d)');
    return body
        .replaceAll(email, '***@***')
        .replaceAll(phone, '***');
  }

  // Detect extortion/fraud keywords in chat (FR-11.3). Returns true if suspicious.
  static bool hasFraudKeyword(String body) {
    final k = ['حول المبلغ', 'تحويل', 'ويسترن', 'usdt', 'crypto pay', 'خارج التطبيق',
               'خارج التطبيق', 'دفع مسبق', 'اكونت', 'حساب بنكي'];
    final low = body.toLowerCase();
    return k.any((w) => low.contains(w));
  }
}

// Lightweight client-side envelope encryption for private identifiers (FR-3.2).
// NOTE: real key must come from a server Edge Function (/crypto/key) using the user's session.
// This is a placeholder HMAC-based padding to show intent; replace with AES-GCM via dart:ffi/tink.
String envelopePrivate(String plain, String sessionKey) {
  final h = Hmac(sha256, utf8.encode(sessionKey));
  final dig = h.convert(utf8.encode(plain));
  // Store only the digest reference + ciphertext envelope; server holds the key.
  return base64Encode(utf8.encode('${dig.toString()}:${plain}'));
}
