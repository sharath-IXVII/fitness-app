import 'package:flutter/material.dart';

/// A festival look: a greeting on Today and a light sparkle of its colours
/// over every page. It switches on and off by date, with no app update.
class Festival {
  const Festival({
    required this.id,
    required this.name,
    required this.greeting,
    required this.line,
    required this.emoji,
    required this.colors,
  });

  final String id;
  final String name;

  /// "Happy Diwali".
  final String greeting;

  /// A short fitness line for the day.
  final String line;
  final String emoji;

  /// The festival's colours: the first two make the banner, all of them sparkle.
  final List<Color> colors;
}

const festivals = <String, Festival>{
  'newyear': Festival(
    id: 'newyear',
    name: 'New Year',
    greeting: 'Happy New Year',
    line: 'New year, new Arc. Start it with a workout today.',
    emoji: '🎉',
    colors: [Color(0xFF5B4BDB), Color(0xFFE94E9A), Color(0xFFFFC94A)],
  ),
  'sankranti': Festival(
    id: 'sankranti',
    name: 'Makar Sankranti',
    greeting: 'Happy Sankranti and Pongal',
    line: 'Fly high today. A morning walk in the sun is the best start.',
    emoji: '🪁',
    colors: [Color(0xFFF2A007), Color(0xFFE5533D), Color(0xFF2E9BD6)],
  ),
  'republic': Festival(
    id: 'republic',
    name: 'Republic Day',
    greeting: 'Happy Republic Day',
    line: 'A fit India starts with you. Move for 26 minutes today.',
    emoji: '🇮🇳',
    colors: [Color(0xFFFF9933), Color(0xFF138808), Color(0xFF1F3A93)],
  ),
  'holi': Festival(
    id: 'holi',
    name: 'Holi',
    greeting: 'Happy Holi',
    line: 'Play with colours, then drink extra water today.',
    emoji: '🎨',
    colors: [Color(0xFFE94E9A), Color(0xFF7B5CF0), Color(0xFF2EC4B6), Color(0xFFFFC94A)],
  ),
  'eid': Festival(
    id: 'eid',
    name: 'Eid',
    greeting: 'Eid Mubarak',
    line: 'Enjoy the feast, and take a gentle walk after meals.',
    emoji: '🌙',
    colors: [Color(0xFF0F7B6C), Color(0xFFD4AF37), Color(0xFFFFFFFF)],
  ),
  'independence': Festival(
    id: 'independence',
    name: 'Independence Day',
    greeting: 'Happy Independence Day',
    line: 'Freedom to move. Do 15 minutes of exercise today.',
    emoji: '🇮🇳',
    colors: [Color(0xFFFF9933), Color(0xFF138808), Color(0xFF1F3A93)],
  ),
  'ganesh': Festival(
    id: 'ganesh',
    name: 'Ganesh Chaturthi',
    greeting: 'Happy Ganesh Chaturthi',
    line: 'Enjoy the modaks, and keep your steps up this week.',
    emoji: '🌼',
    colors: [Color(0xFFF28C28), Color(0xFFD7263D), Color(0xFFFFD23F)],
  ),
  'dussehra': Festival(
    id: 'dussehra',
    name: 'Dussehra',
    greeting: 'Happy Dussehra',
    line: 'Good wins over lazy. Beat yesterday’s steps today.',
    emoji: '🏹',
    colors: [Color(0xFFE4572E), Color(0xFFF3A712), Color(0xFF8C1C13)],
  ),
  'diwali': Festival(
    id: 'diwali',
    name: 'Diwali',
    greeting: 'Happy Diwali',
    line: 'Light up your streak. A short workout before the sweets!',
    emoji: '🪔',
    colors: [Color(0xFFF59E0B), Color(0xFFB91C1C), Color(0xFFFDE68A)],
  ),
  'christmas': Festival(
    id: 'christmas',
    name: 'Christmas',
    greeting: 'Merry Christmas',
    line: 'Unwrap a workout today. Your future self says thanks.',
    emoji: '🎄',
    colors: [Color(0xFFC0392B), Color(0xFF1E7B4F), Color(0xFFF4D35E)],
  ),
};

/// One festival day, shown from [before] days earlier to [after] days later.
/// Moon-based dates can differ by a day between calendars, so the window
/// covers that.
class FestivalDate {
  const FestivalDate(this.id, this.day, {this.before = 1, this.after = 1});

  final String id;
  final DateTime day;
  final int before;
  final int after;

  bool covers(DateTime d) {
    final day0 = DateTime(day.year, day.month, day.day);
    final x = DateTime(d.year, d.month, d.day);
    return !x.isBefore(day0.subtract(Duration(days: before))) && !x.isAfter(day0.add(Duration(days: after)));
  }
}

/// Festivals on the same date every year: (id, month, day, before, after).
const _fixed = [
  ('newyear', 1, 1, 1, 1),
  ('sankranti', 1, 14, 1, 1),
  ('republic', 1, 26, 0, 0),
  ('independence', 8, 15, 0, 0),
  ('christmas', 12, 25, 1, 1),
];

/// Moon-based festivals, by year. Diwali covers Dhanteras to Bhai Dooj.
/// More can be added, or a date corrected, from Firestore (config/festivals)
/// without an app update.
final _lunar = <FestivalDate>[
  for (final (y, m, d) in [
    (2026, 11, 8),
    (2027, 10, 29),
    (2028, 10, 17),
    (2029, 11, 5),
    (2030, 10, 26),
    (2031, 11, 14),
    (2032, 11, 2),
  ])
    FestivalDate('diwali', DateTime(y, m, d), before: 2, after: 2),
  for (final (y, m, d) in [(2027, 3, 22), (2028, 3, 11), (2029, 3, 1), (2030, 3, 20), (2031, 3, 9), (2032, 2, 27)])
    FestivalDate('holi', DateTime(y, m, d), before: 1, after: 1),
  for (final (y, m, d) in [(2027, 3, 10), (2028, 2, 27), (2029, 2, 15), (2030, 2, 5), (2031, 1, 25), (2032, 1, 14)])
    FestivalDate('eid', DateTime(y, m, d), before: 1, after: 2),
  for (final (y, m, d) in [(2027, 9, 4), (2028, 8, 24), (2029, 9, 13), (2030, 9, 2), (2031, 8, 24), (2032, 9, 11)])
    FestivalDate('ganesh', DateTime(y, m, d), before: 1, after: 2),
  for (final (y, m, d) in [
    (2027, 10, 10),
    (2028, 9, 28),
    (2029, 10, 17),
    (2030, 10, 6),
    (2031, 10, 25),
    (2032, 10, 13),
  ])
    FestivalDate('dussehra', DateTime(y, m, d), before: 1, after: 1),
];

/// Every festival date that covers [year], built in.
List<FestivalDate> builtInDates(int year) => [
  for (final (id, m, d, b, a) in _fixed) ...[
    FestivalDate(id, DateTime(year, m, d), before: b, after: a),
    // New Year's Eve belongs to next year's New Year.
    if (id == 'newyear') FestivalDate(id, DateTime(year + 1, m, d), before: b, after: a),
  ],
  ..._lunar.where((f) => f.day.year == year || f.day.year == year + 1),
];

/// The festival on [day], if any. [extra] (from Firestore) wins over the
/// built-in dates: an entry for a festival in a year replaces the built-in
/// date for that year.
Festival? festivalOn(DateTime day, {List<FestivalDate> extra = const [], Map<String, Festival> custom = const {}}) {
  final all = {...festivals, ...custom};
  final replaced = {for (final e in extra) '${e.id}/${e.day.year}'};
  final dates = [
    ...extra,
    for (final f in builtInDates(day.year))
      if (!replaced.contains('${f.id}/${f.day.year}')) f,
  ];
  for (final f in dates) {
    if (f.covers(day) && all[f.id] != null) return all[f.id];
  }
  return null;
}

/// Reads config/festivals: {dates: [{id, day: "2027-10-29", before?, after?}],
/// custom: [{id, name, greeting, line, emoji, colors: ["#F59E0B", ...]}]}.
({List<FestivalDate> dates, Map<String, Festival> custom}) parseFestivalConfig(Map<String, dynamic>? j) {
  final dates = <FestivalDate>[];
  final custom = <String, Festival>{};
  if (j == null) return (dates: dates, custom: custom);
  for (final d in (j['dates'] as List<dynamic>? ?? const [])) {
    if (d is! Map) continue;
    final day = DateTime.tryParse('${d['day']}');
    final id = d['id'];
    if (day == null || id is! String) continue;
    dates.add(
      FestivalDate(id, day, before: (d['before'] as num?)?.toInt() ?? 1, after: (d['after'] as num?)?.toInt() ?? 1),
    );
  }
  for (final c in (j['custom'] as List<dynamic>? ?? const [])) {
    if (c is! Map || c['id'] is! String || c['greeting'] is! String) continue;
    final colors = [
      for (final h in (c['colors'] as List<dynamic>? ?? const []))
        if (int.tryParse('$h'.replaceFirst('#', ''), radix: 16) case final v?) Color(0xFF000000 | v),
    ];
    custom[c['id'] as String] = Festival(
      id: c['id'] as String,
      name: '${c['name'] ?? c['greeting']}',
      greeting: c['greeting'] as String,
      line: '${c['line'] ?? ''}',
      emoji: '${c['emoji'] ?? '✨'}',
      colors: colors.length >= 2 ? colors : const [Color(0xFFF59E0B), Color(0xFFE94E9A)],
    );
  }
  return (dates: dates, custom: custom);
}
