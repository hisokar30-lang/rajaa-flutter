// lib/models/category.dart
// Maps public.categories (10 seeded rows, world-readable via RLS).
class Category {
  final int id;
  final String nameAr;
  final String nameEn;
  final String? icon;
  final int sortOrder;
  final bool isActive;

  const Category({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.icon,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      nameAr: json['name_ar'] as String,
      nameEn: json['name_en'] as String,
      icon: json['icon'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name_ar': nameAr,
        'name_en': nameEn,
        'icon': icon,
        'sort_order': sortOrder,
        'is_active': isActive,
      };

  String get localizedName => nameAr; // Arabic-first (PRD §1).
}
