import 'package:fitalarm/features/health/domain/live_hr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Heart Rate Measurement packets', () {
    test('one-byte rate', () {
      final m = parseHeartRateMeasurement([0x00, 72])!;
      expect(m.bpm, 72);
      expect(m.contactLost, isFalse);
    });

    test('two-byte rate, little endian', () {
      // 0x0101 = 257 is too high to be real; 0x00B4 = 180 is fine.
      expect(parseHeartRateMeasurement([0x01, 0xB4, 0x00])!.bpm, 180);
      expect(parseHeartRateMeasurement([0x01, 0x01, 0x01]), isNull);
    });

    test('a strap that lost skin contact is flagged', () {
      // flags: contact supported (bit 2) but not detected (bit 1 clear).
      final m = parseHeartRateMeasurement([0x04, 0])!;
      expect(m.contactLost, isTrue);
      expect(m.bpm, 0);
      // Detected.
      expect(parseHeartRateMeasurement([0x06, 80])!.contactLost, isFalse);
    });

    test('short or silly packets are ignored', () {
      expect(parseHeartRateMeasurement([]), isNull);
      expect(parseHeartRateMeasurement([0x00]), isNull);
      expect(parseHeartRateMeasurement([0x01, 70]), isNull);
      expect(parseHeartRateMeasurement([0x00, 10]), isNull);
      expect(parseHeartRateMeasurement([0x00, 255]), isNull);
    });
  });

  group('zones', () {
    test('top heart rate falls with age', () {
      expect(maxHeartRate(20), 194);
      expect(maxHeartRate(40), 180);
      expect(maxHeartRate(60), 166);
    });

    test('zone edges at a top rate of 180', () {
      expect(zoneFor(80, 180), HrZone.rest); // 44%
      expect(zoneFor(90, 180), HrZone.warm); // 50%
      expect(zoneFor(108, 180), HrZone.steady); // 60%
      expect(zoneFor(126, 180), HrZone.push); // 70%
      expect(zoneFor(153, 180), HrZone.peak); // 85%
      expect(zoneFor(200, 180), HrZone.peak);
    });

    test('moderate minutes count once, hard minutes twice, rest never', () {
      expect(HrZone.rest.arcPerMinute, 0);
      expect(HrZone.warm.arcPerMinute, 1);
      expect(HrZone.steady.arcPerMinute, 1);
      expect(HrZone.push.arcPerMinute, 2);
      expect(HrZone.peak.arcPerMinute, 2);
    });
  });

  group('session', () {
    final t0 = DateTime(2026, 10, 27, 7);

    test('time in each zone becomes Arc minutes', () {
      final s = HrSession(maxBpm: 180);
      // 2 minutes steady (120), 1 minute pushing (140), 1 minute resting (70).
      for (var i = 0; i <= 120; i++) {
        s.add(120, t0.add(Duration(seconds: i)));
      }
      for (var i = 121; i <= 180; i++) {
        s.add(140, t0.add(Duration(seconds: i)));
      }
      for (var i = 181; i <= 240; i++) {
        s.add(70, t0.add(Duration(seconds: i)));
      }
      expect(s.secondsIn(HrZone.steady), closeTo(121, 0.01));
      expect(s.secondsIn(HrZone.push), closeTo(60, 0.01));
      expect(s.secondsIn(HrZone.rest), closeTo(59, 0.01));
      // 121 s x 1 + 60 s x 2 = 241 s-weighted = about 4 Arc minutes.
      expect(s.arcMinutes, closeTo(241 / 60, 0.01));
      expect(s.top, 140);
      expect(s.zone, HrZone.rest);
      expect(s.average, inInclusiveRange(110, 115));
    });

    test('a dropped link earns nothing for the gap', () {
      final s = HrSession(maxBpm: 180);
      s.add(150, t0);
      s.add(150, t0.add(const Duration(seconds: 1)));
      // Ten minutes of silence, then it reconnects.
      s.add(150, t0.add(const Duration(minutes: 10)));
      s.add(150, t0.add(const Duration(minutes: 10, seconds: 1)));
      expect(s.seconds, closeTo(2, 0.01));
      expect(s.arcMinutes, closeTo(2 * 2 / 60, 0.01));
    });

    test('nothing yet', () {
      final s = HrSession(maxBpm: 180);
      expect(s.arcMinutes, 0);
      expect(s.average, 0);
      expect(s.zone, isNull);
    });
  });

  test('the week adds up the last seven days only', () {
    final today = DateTime(2026, 10, 27);
    final byDay = {
      '2026-10-27': 20.0,
      '2026-10-21': 30.0, // 6 days ago: counts
      '2026-10-20': 99.0, // 7 days ago: does not
    };
    expect(weekArcMinutes(byDay, today), 50);
    expect(dayKey(DateTime(2026, 3, 5)), '2026-03-05');
  });
}
