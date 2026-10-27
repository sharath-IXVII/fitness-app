import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// The notification channels name these files. A missing one would only show
/// up on a phone, so check they are there and sound sensible.
void main() {
  const res = 'android/app/src/main/res';

  for (final name in ['fittarc_routine', 'fittarc_water', 'fittarc_workout']) {
    test('$name.wav is a valid, short, un-clipped sound', () {
      final f = File('$res/raw/$name.wav');
      expect(f.existsSync(), isTrue);
      final b = f.readAsBytesSync();
      final d = ByteData.sublistView(b);
      expect(String.fromCharCodes(b.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(b.sublist(8, 12)), 'WAVE');
      final rate = d.getUint32(24, Endian.little);
      final bits = d.getUint16(34, Endian.little);
      final dataBytes = d.getUint32(40, Endian.little);
      expect(bits, 16);
      final seconds = dataBytes / 2 / rate;
      expect(seconds, inInclusiveRange(0.6, 3.0), reason: 'a notification sound should be short');
      var peak = 0;
      for (var i = 44; i + 1 < b.length; i += 2) {
        final v = d.getInt16(i, Endian.little).abs();
        if (v > peak) peak = v;
      }
      expect(peak / 32767, inInclusiveRange(0.5, 0.97), reason: 'loud enough, but not clipping');
      expect(b.length, lessThan(300 * 1024), reason: 'keep the app small');
    });
  }

  test('the status-bar icon exists at every density, and the large logo is there', () {
    for (final d in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      expect(File('$res/drawable-$d/ic_stat_notify.png').existsSync(), isTrue, reason: d);
    }
    expect(File('$res/drawable-nodpi/notif_large.png').existsSync(), isTrue);
  });
}
