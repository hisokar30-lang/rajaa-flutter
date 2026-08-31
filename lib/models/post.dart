// lib/models/post.dart
// Maps public.posts. The geog column is parsed via lib/core/geo.dart so the map
// and distance sorting work regardless of how Supabase serializes it.
import 'package:latlong2/latlong.dart';
import '../core/geo.dart';

enum PostType { lost, found }

enum RewardType { none, thanks, fixed, negotiable }

enum PostStatus { open, inContact, verified, resolved, expired, removed }

extension PostTypeX on PostType {
  String get label => this == PostType.lost ? 'مفقود' : 'موجود';
}

extension RewardTypeX on RewardType {
  String get label {
    switch (this) {
      case RewardType.none:
        return 'بدون مكافأة';
      case RewardType.thanks:
        return 'شكر فقط';
      case RewardType.fixed:
        return 'مبلغ محدد';
      case RewardType.negotiable:
        return 'قابل للتفاوض';
    }
  }
}

class Post {
  final String id;
  final String userId;
  final PostType type;
  final int categoryId;
  final String title;
  final String? description;
  final List<String> images;
  final String? privateIdentifiersEnc; // client-side encrypted (security.dart)
  final double lat;
  final double lng;
  final int radiusM;
  final String precision; // 'exact' | 'approx' — PRD: exact by default
  final RewardType rewardType;
  final double? rewardAmount;
  final String currency;
  final PostStatus status;
  final int boostScore;
  final DateTime? expiresAt;
  final DateTime createdAt;

  // Populated client-side after we know the viewer's location (for feed sort).
  double? distanceM;

  const Post({
    required this.id,
    required this.userId,
    required this.type,
    required this.categoryId,
    required this.title,
    this.description,
    this.images = const [],
    this.privateIdentifiersEnc,
    required this.lat,
    required this.lng,
    this.radiusM = 2000,
    this.precision = 'exact',
    this.rewardType = RewardType.none,
    this.rewardAmount,
    this.currency = 'TND',
    this.status = PostStatus.open,
    this.boostScore = 0,
    this.expiresAt,
    required this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final geo = parseGeog(json['geog']);
    final lat = geo?.latitude ?? 0.0;
    final lng = geo?.longitude ?? 0.0;
    return Post(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: (json['type'] as String? ?? 'lost') == 'lost'
          ? PostType.lost
          : PostType.found,
      categoryId: json['category_id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      images: (json['images'] is List)
          ? (json['images'] as List).map((e) => e.toString()).toList()
          : const [],
      privateIdentifiersEnc: json['private_identifiers_enc'] as String?,
      lat: lat,
      lng: lng,
      radiusM: json['radius_m'] as int? ?? 2000,
      precision: json['precision'] as String? ?? 'exact',
      rewardType: _reward(json['reward_type'] as String?),
      rewardAmount: (json['reward_amount'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'TND',
      status: _status(json['status'] as String?),
      boostScore: json['boost_score'] as int? ?? 0,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsert() {
    return {
      'user_id': userId,
      'type': type == PostType.lost ? 'lost' : 'found',
      'category_id': categoryId,
      'title': title,
      'description': description,
      'images': images,
      'private_identifiers_enc': privateIdentifiersEnc,
      'geog': geogWkt(lat, lng), // WKT insert; RLS enforces ownership
      'radius_m': radiusM,
      'precision': precision,
      'reward_type': _rewardStr(rewardType),
      'reward_amount': rewardAmount,
      'currency': currency,
      'status': _statusStr(status),
    };
  }

  bool get isLost => type == PostType.lost;
}

RewardType _reward(String? v) {
  switch (v) {
    case 'thanks':
      return RewardType.thanks;
    case 'fixed':
      return RewardType.fixed;
    case 'negotiable':
      return RewardType.negotiable;
    default:
      return RewardType.none;
  }
}

PostStatus _status(String? v) {
  switch (v) {
    case 'in_contact':
      return PostStatus.inContact;
    case 'verified':
      return PostStatus.verified;
    case 'resolved':
      return PostStatus.resolved;
    case 'expired':
      return PostStatus.expired;
    case 'removed':
      return PostStatus.removed;
    default:
      return PostStatus.open;
  }
}

String _rewardStr(RewardType r) => r.name;
String _statusStr(PostStatus s) => s.name;
