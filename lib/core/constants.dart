// lib/core/constants.dart
// App-wide constants: theme colors (Arab-first palette), currencies, enums metadata.
import 'package:flutter/material.dart';

class AppColors {
  // Lost items -> amber. Found items -> green. Brand accent -> deep amber.
  static const Color brand = Color(0xFFC77700);
  static const Color lost = Color(0xFFFFB300); // amber
  static const Color found = Color(0xFF2E9E5B); // green
  static const Color bg = Color(0xFFFBF7F0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF1F1B16);
  static const Color muted = Color(0xFF8A8076);
  static const Color danger = Color(0xFFC0392B);
}

// Supported currencies per Arab countries (FR-2 / PRD §1). No Stripe, cash only.
const List<Map<String, String>> kCurrencies = [
  {'code': 'TND', 'symbol': 'د.ت', 'name': 'تونس'},
  {'code': 'EGP', 'symbol': 'ج.م', 'name': 'مصر'},
  {'code': 'AED', 'symbol': 'د.إ', 'name': 'الإمارات'},
  {'code': 'SAR', 'symbol': 'ر.س', 'name': 'السعودية'},
  {'code': 'LYD', 'symbol': 'ل.د', 'name': 'ليبيا'},
  {'code': 'MAD', 'symbol': 'د.م', 'name': 'المغرب'},
  {'code': 'DZD', 'symbol': 'د.ج', 'name': 'الجزائر'},
  {'code': 'JOD', 'symbol': 'د.أ', 'name': 'الأردن'},
  {'code': 'KWD', 'symbol': 'د.ك', 'name': 'الكويت'},
  {'code': 'QAR', 'symbol': 'ر.ق', 'name': 'قطر'},
  {'code': 'BHD', 'symbol': 'د.ب', 'name': 'البحرين'},
  {'code': 'OMR', 'symbol': 'ر.ع', 'name': 'عُمان'},
  {'code': 'ILS', 'symbol': '₪', 'name': 'فلسطين'},
  {'code': 'LBP', 'symbol': 'ل.ل', 'name': 'لبنان'},
  {'code': 'SYP', 'symbol': 'ل.س', 'name': 'سوريا'},
  {'code': 'YER', 'symbol': 'ر.ي', 'name': 'اليمن'},
  {'code': 'SDG', 'symbol': 'ج.س', 'name': 'السودان'},
  {'code': 'IQD', 'symbol': 'د.ع', 'name': 'العراق'},
];

const String kDefaultCurrency = 'TND';

// Supabase Storage bucket for post images. Create it (public) in Supabase dashboard.
const String kImageBucket = 'post-images';

// Deep link host used by go_router + AndroidManifest intent-filter.
const String kDeepLinkScheme = 'https';
const String kDeepLinkHost = 'rajaa.app';

// Zone agent Edge Function endpoint (invoked via supabase.functions.invoke).
const String kLocationPingFunction = 'location-ping';

// Distance (meters) of "significant movement" that triggers a zone ping (FR-5).
const double kZoneMoveThresholdM = 500.0;

// Reward type labels (Arabic).
const Map<String, String> kRewardTypeLabels = {
  'none': 'بدون مكافأة',
  'thanks': 'شكر فقط',
  'fixed': 'مبلغ محدد',
  'negotiable': 'قابل للتفاوض',
};

// Notification group labels (FR-10).
const Map<String, String> kNotificationGroups = {
  'zone': 'تنبيهات المناطق',
  'match': 'مطابقات',
  'chat': 'المحادثات',
  'verify': 'التحقق',
  'reward': 'المكافآت',
  'system': 'النظام',
};
