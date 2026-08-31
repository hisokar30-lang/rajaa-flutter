// lib/main.dart
// App entry: RTL Arabic-first, go_router, Supabase + Firebase init, FCM token.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/supabase.dart';
import 'core/providers.dart';
import 'core/repository.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/onboarding.dart';
import 'features/home/home_screen.dart';
import 'features/post/create_post_wizard.dart';
import 'features/post/post_detail_screen.dart';
import 'features/chat/chat_list.dart';
import 'features/chat/chat_room.dart';
import 'features/profile/profile_screen.dart';
import 'features/profile/settings_screen.dart';
import 'features/notifications/notifications_screen.dart';

// Top-level background handler for FCM (required by firebase_messaging on Android).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Zone-alert pushes are handled in the app; nothing to persist here.
  debugPrint('[FCM] background: ${message.messageId}');
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildRouter(WidgetRef ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    // Re-evaluate redirects whenever auth state changes.
    refreshListenable: GoRouterRefreshStream(
      supabase.auth.onAuthStateChange.map((e) => e.session?.user),
    ),
    redirect: (BuildContext context, GoRouterState state) {
      final user = supabase.auth.currentUser;
      final loc = state.matchedLocation;
      if (user == null) {
        return loc == '/login' ? null : '/login';
      }
      // Authenticated: must finish onboarding (profile row) before using the app.
      final hasProfile = ref.read(hasProfileProvider).valueOrNull ?? false;
      if (!hasProfile && loc != '/onboarding') return '/onboarding';
      if (hasProfile && loc == '/onboarding') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
      GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
      GoRoute(path: '/post/new', builder: (c, s) => const CreatePostWizard()),
      GoRoute(
        path: '/post/:id',
        builder: (c, s) => PostDetailScreen(postId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/chat', builder: (c, s) => const ChatListScreen()),
      GoRoute(
        path: '/chat/:id',
        builder: (c, s) => ChatRoomScreen(chatId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
      GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
      GoRoute(
        path: '/notifications',
        builder: (c, s) => const NotificationsScreen(),
      ),
    ],
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Supabase (anon key only — never service_role in client).
  await initSupabase();

  // 2) Firebase + FCM. OPTIONAL: if no google-services.json is present the app
  // still builds & runs; zone alerts degrade to in-app until Firebase is wired.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    final token = await messaging.getToken();
    if (token != null) await Repository.registerDeviceToken(token);
    FirebaseMessaging.onMessage.listen((msg) {
      debugPrint('[FCM] foreground: ${msg.notification?.title}');
    });
  } catch (e) {
    debugPrint('[Firebase] not configured (running without push): $e');
  }

  // 3) Riverpod + router.
  final container = ProviderContainer();
  final router = buildRouter(container);

  runApp(UncontrolledProviderScope(container: container, child: MyApp(router: router)));
}

class MyApp extends StatelessWidget {
  final GoRouter router;
  const MyApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'راجع',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      // Arabic-first RTL.
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFFC77700),
        scaffoldBackgroundColor: const Color(0xFFFBF7F0),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC77700),
          primary: const Color(0xFFC77700),
        ),
        fontFamily: 'Cairo',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Color(0xFFFBF7F0),
          foregroundColor: Color(0xFF1F1B16),
          elevation: 0,
        ),
      ),
      // Guarantee RTL regardless of locale resolution.
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
    );
  }
}
