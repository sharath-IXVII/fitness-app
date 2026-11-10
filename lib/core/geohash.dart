/// Geohash: a short code for an area on the map. Places with the same first
/// letters are near each other, so a database can find "clubs near me".
const _b32 = '0123456789bcdefghjkmnpqrstuvwxyz';

String geohash(double lat, double lng, {int length = 4}) {
  var latR = (-90.0, 90.0), lngR = (-180.0, 180.0);
  final out = StringBuffer();
  var bit = 0, ch = 0, even = true;
  while (out.length < length) {
    if (even) {
      final mid = (lngR.$1 + lngR.$2) / 2;
      if (lng >= mid) {
        ch |= 1 << (4 - bit);
        lngR = (mid, lngR.$2);
      } else {
        lngR = (lngR.$1, mid);
      }
    } else {
      final mid = (latR.$1 + latR.$2) / 2;
      if (lat >= mid) {
        ch |= 1 << (4 - bit);
        latR = (mid, latR.$2);
      } else {
        latR = (latR.$1, mid);
      }
    }
    even = !even;
    if (bit < 4) {
      bit++;
    } else {
      out.write(_b32[ch]);
      bit = 0;
      ch = 0;
    }
  }
  return out.toString();
}

/// The cell for (lat, lng) and its 8 neighbours, so a search near a cell
/// edge still finds places just across it. Length 4 cells are about
/// 39 × 20 km.
Set<String> geohashNeighbours(double lat, double lng, {int length = 4}) {
  // Cell size in degrees for this length.
  final lngBits = (length * 5 / 2).ceil(), latBits = (length * 5 / 2).floor();
  final dLng = 360 / (1 << lngBits), dLat = 180 / (1 << latBits);
  return {
    for (final dy in [-1, 0, 1])
      for (final dx in [-1, 0, 1])
        geohash((lat + dy * dLat).clamp(-89.99, 89.99), ((lng + dx * dLng + 540) % 360) - 180, length: length),
  };
}
