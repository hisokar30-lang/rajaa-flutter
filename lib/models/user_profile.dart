// lib/models/user_profile.dart
// Maps the public.users table. Security: RLS restricts writes to self (auth.uid() = id).
class UserProfile {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? avatar;
  final String? bio;
  final String? city;
  final bool isVerifiedId;
  final int finderPoints;
  final double ratingAvg;
  final int ratingCount;
  final Map<String, dynamic>? settingsJson;
  final DateTime? createdAt;

  const UserProfile({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.avatar,
    this.bio,
    this.city,
    this.isVerifiedId = false,
    this.finderPoints = 0,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.settingsJson,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'مستخدم',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      avatar: json['avatar'] as String?,
      bio: json['bio'] as String?,
      city: json['city'] as String?,
      isVerifiedId: json['is_verified_id'] as bool? ?? false,
      finderPoints: json['finder_points'] as int? ?? 0,
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
      ratingCount: json['rating_count'] as int? ?? 0,
      settingsJson: json['settings_json'] is Map
          ? Map<String, dynamic>.from(json['settings_json'] as Map)
          : null,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'avatar': avatar,
        'bio': bio,
        'city': city,
        'is_verified_id': isVerifiedId,
        'finder_points': finderPoints,
        'rating_avg': ratingAvg,
        'rating_count': ratingCount,
        'settings_json': settingsJson,
        'created_at': createdAt?.toIso8601String(),
      };

  UserProfile copyWith({
    String? name,
    String? avatar,
    String? bio,
    String? city,
    Map<String, dynamic>? settingsJson,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      email: email,
      phone: phone,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      city: city ?? this.city,
      isVerifiedId: isVerifiedId,
      finderPoints: finderPoints,
      ratingAvg: ratingAvg,
      ratingCount: ratingCount,
      settingsJson: settingsJson ?? this.settingsJson,
      createdAt: createdAt,
    );
  }
}
