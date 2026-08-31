# راجع (Rajaa) — Lost & Found App (Android MVP)

Lost & found app for the Arab world. Flutter (Android) + Supabase (Postgres + PostGIS) + Mapbox-free OSM map.

## Architecture
- **Client:** Flutter Android. State: flutter_riverpod. Routing: go_router. Map: flutter_map (OSM tiles).
- **Backend:** Supabase project `jxdjecujxlvitrrfgkjf`. Auth, Postgres+PostGIS, Realtime, Storage.
- **Zone Agent:** Supabase Edge Functions (`zone-agent`, `location-ping`) — server-side location match via `match_zones()` + FCM push.

## Prerequisites
- Flutter SDK >= 3.3
- Android SDK (minSdk 21, target 34)
- A Firebase project (for FCM push) — `firebase_core` + `firebase_messaging`
- Supabase project already created (schema applied: `rajaa_supabase_schema.sql`)

## Setup
1. `flutter pub get`
2. Create Storage bucket `post-images` (public) in Supabase dashboard.
3. Firebase: drop `google-services.json` into `android/app/`.
4. Supabase secrets (dashboard → Edge Functions → env):
   - `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`
   - `FCM_SERVER_KEY` (Firebase legacy server key or v1 via service account)
5. Deploy Edge Functions:
   ```
   supabase functions deploy zone-agent
   supabase functions deploy location-ping
   ```

## Android permissions (AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.CAMERA" />
```

## Run
```
flutter run
```

## Security notes
- Client uses the **anon** key only. RLS is the real guard (enabled on all tables).
- Inputs validated via `InputGuard` before insert.
- Private identifiers encrypted client-side before insert.
- Chat contact info masked; fraud keywords flagged + reportable.
- **Never** put the service_role key in client code or commit it.

## What's implemented (P1 MVP)
Auth (email/OTP/Google), onboarding, home (map/feed), create-post wizard (3 steps + zone draw),
post detail (reactions/comments/share/report/contact), chat + verify flow, profile/settings,
notifications, zone-agent client + Edge Functions.

## Not in MVP (deferred)
iOS, Stripe escrow, AI visual matching, business accounts, image moderation API (hook point ready).
