// lib/features/zones/zone_agent_client.dart
// Sends location ping to Edge Function on significant movement; handles FCM zone pushes.
// FR-5.2 hybrid: server-side match is the reliable path (works without background permission).
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';
import '../../core/constants.dart';

class ZoneAgentClient {
  LatLng? _last;
  StreamSubscription<Position>? _sub;
  final void Function(Map<String, dynamic> match) onMatch;
  ZoneAgentClient(this.onMatch);

  Future<void> start() async {
    final perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied) return;
    _sub = Geolocator.getPositionStream(distanceFilter: 500, accuracy: LocationAccuracy.low).listen(_onPos);
    // also do an immediate ping
    final p = await Geolocator.getCurrentPosition();
    await _ping(p.latitude, p.longitude);
  }

  void _onPos(Position p) async {
    if (_last != null) {
      final d = _dist(_last!.latitude, _last!.longitude, p.latitude, p.longitude);
      if (d < kZoneMoveThresholdM) return; // not significant enough
    }
    _last = LatLng(p.latitude, p.longitude);
    await _ping(p.latitude, p.longitude);
  }

  Future<void> _ping(double lat, double lng) async {
    try {
      final res = await supabase.functions.invoke(kLocationPingFunction, body: {'lat': lat, 'lng': lng});
      final data = res.data;
      if (data is Map && data['matches'] is List) {
        for (final m in data['matches']) onMatch(m as Map<String, dynamic>);
      }
    } catch (_) { /* silent: zone agent is best-effort */ }
  }

  double _dist(double la1, double lo1, double la2, double lo2) {
    // rough haversine in meters
    const R = 6371000;
    final dLa = (la2 - la1) * pi / 180, dLo = (lo2 - lo1) * pi / 180;
    final a = sin(dLa / 2) * sin(dLa / 2) + cos(la1 * pi / 180) * cos(la2 * pi / 180) * sin(dLo / 2) * sin(dLo / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  void dispose() => _sub?.cancel();
}

class LatLng { final double latitude, longitude; LatLng(this.latitude, this.longitude); }
