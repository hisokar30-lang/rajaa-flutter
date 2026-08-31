// lib/core/providers.dart
// Riverpod providers for auth state, current user profile, and categories.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../models/category.dart';
import 'supabase.dart';
import 'repository.dart';

/// Streams the current Supabase auth user (null when signed out).
final authStateProvider = StreamProvider<User?>((ref) {
  return supabase.auth.onAuthStateChange.map((s) => s.session?.user);
});

/// The current user's public profile row (null until the profile row exists).
final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return null;
  return Repository.fetchProfile(user.id);
});

/// Seeded categories (world-readable).
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  return Repository.getCategories();
});

/// True once the current user has a profile row (past onboarding).
final hasProfileProvider = FutureProvider<bool>((ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return false;
  final p = await Repository.fetchProfile(user.id);
  return p != null;
});

/// Force a refresh helper used after profile edits.
void invalidateUserProfile(Ref ref) =>
    ref.invalidate(currentUserProfileProvider);
