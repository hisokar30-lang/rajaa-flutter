// lib/core/geo.dart
// Helpers to parse the `geog geography(Point,4326)` column returned by Supabase
// (WKB hex, WKT, or GeoJSON) into a latlong2 LatLng, and to build a WKT string
// for inserts. Exact precision is preserved (no fuzzing) per PRD §decision 6.
import 'dart:convert';
import 'dart:math' show pi, sin, cos, asin, sqrt;
import 'dart:typed_data' show ByteData, Endian, Uint8List;
import 'package:crypto/crypto.dart' show hex;
import 'package:latlong2/latlong.dart';

/// Parse a PostGIS geography value (any of WKB-hex / WKT / GeoJSON) into LatLng(lat,lng).
LatLng? parseGeog(dynamic geog) {
  if (geog == null) return null;
  if (geog is LatLng) return geog;
  if (geog is! String) return null;
  final s = geog.trim();
  if (s.isEmpty) return null;

  // GeoJSON: {"type":"Point","coordinates":[lng,lat]}
  if (s.startsWith('{')) {
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      final coords = (j['coordinates'] as List?)?.cast<num>();
      if (coords != null && coords.length >= 2) {
        return LatLng(coords[1].toDouble(), coords[0].toDouble());
      }
    } catch (_) {}
    return null;
  }

  // WKT: POINT(lng lat) or POINT(lng,lat) or (lng lat)
  final wkt = s.startsWith('POINT') ? s.substring(s.indexOf('(') + 1, s.indexOf(')')) : s;
  if (wkt.contains(RegExp(r'[a-zA-Z]'))) {
    final parts = wkt.split(RegExp(r'[ ,]+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 2) {
      final x = double.tryParse(parts[0]);
      final y = double.tryParse(parts[1]);
      if (x != null && y != null) return LatLng(y, x); // LatLng(lat, lng)
    }
    return null;
  }

  // WKB hex (little/big endian): byte order + uint32 type + double x + double y
  try {
    final bytes = hex.decode(s);
    if (bytes.length >= 21) {
      final bd = ByteData.sublistView(Uint8List.fromList(bytes));
      final bo = bytes[0];
      final endian = bo == 0x00 ? Endian.big : Endian.little;
      final x = bd.getFloat64(5, endian);
      final y = bd.getFloat64(13, endian);
      return LatLng(y, x);
    }
  } catch (_) {}
  return null;
}

/// Build a WKT string for insert. PostGIS accepts 'POINT(lng lat)' for a
/// geography(Point,4326) column via Supabase/PostgREST.
String geogWkt(double lat, double lng) => 'POINT($lng $lat)';

/// Great-circle distance in meters (Haversine) for client-side feed sorting.
double distanceMeters(LatLng a, LatLng b) {
  const R = 6371000.0;
  final dLat = _rad(b.latitude - a.latitude);
  final dLng = _rad(b.longitude - a.longitude);
  final lat1 = _rad(a.latitude);
  final lat2 = _rad(b.latitude);
  final h = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
  return 2 * R * asin(sqrt(h));
}

double _rad(double deg) => deg * pi / 180.0;
