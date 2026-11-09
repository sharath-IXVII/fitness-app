import 'dart:ui' show Color;

import 'package:fitalarm/features/festivals/domain/festival.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? on(int y, int m, int d, {List<FestivalDate> extra = const []}) =>
      festivalOn(DateTime(y, m, d), extra: extra)?.id;

  test('Diwali runs from Dhanteras to Bhai Dooj, in every built-in year', () {
    expect(on(2026, 11, 6), 'diwali');
    expect(on(2026, 11, 10), 'diwali');
    expect(on(2026, 11, 11), isNull);
    expect(on(2027, 10, 29), 'diwali');
    expect(on(2032, 11, 2), 'diwali');
  });

  test('fixed-date festivals come every year, including New Year’s Eve', () {
    expect(on(2026, 12, 25), 'christmas');
    expect(on(2026, 12, 31), 'newyear');
    expect(on(2031, 1, 1), 'newyear');
    expect(on(2035, 1, 26), 'republic');
    expect(on(2029, 8, 15), 'independence');
    expect(on(2030, 1, 14), 'sankranti');
    expect(on(2026, 6, 10), isNull);
  });

  test('moon-based festivals allow a day either side', () {
    expect(on(2027, 3, 21), 'holi');
    expect(on(2027, 3, 23), 'holi');
    expect(on(2028, 2, 28), 'eid');
    expect(on(2028, 8, 25), 'ganesh');
  });

  test('dates from the console add or replace built-in ones', () {
    final cfg = parseFestivalConfig({
      'dates': [
        {'id': 'diwali', 'day': '2027-10-30', 'before': 0, 'after': 0},
        {'id': 'onam', 'day': '2027-09-12'},
      ],
      'custom': [
        {
          'id': 'onam',
          'name': 'Onam',
          'greeting': 'Happy Onam',
          'emoji': '🌸',
          'colors': ['#F2C14E', '#1E7B4F'],
        },
      ],
    });
    expect(festivalOn(DateTime(2027, 10, 29), extra: cfg.dates, custom: cfg.custom), isNull); // replaced
    expect(festivalOn(DateTime(2027, 10, 30), extra: cfg.dates, custom: cfg.custom)?.id, 'diwali');
    final onam = festivalOn(DateTime(2027, 9, 12), extra: cfg.dates, custom: cfg.custom)!;
    expect(onam.greeting, 'Happy Onam');
    expect(onam.colors.first, const Color(0xFFF2C14E));
    expect(parseFestivalConfig(null).dates, isEmpty);
    expect(
      parseFestivalConfig({
        'dates': [
          'junk',
          {'id': 'x'},
        ],
      }).dates,
      isEmpty,
    );
  });
}
