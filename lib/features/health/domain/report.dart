import 'package:intl/intl.dart';

import 'health.dart';

/// A plain-text summary a person can send to their doctor. It lists what was
/// recorded and says plainly that it is the user's own record.
String buildReport(List<HealthReading> all, DateTime now) {
  final date = DateFormat('d MMM y');
  final stamp = DateFormat('d MMM, h:mm a');
  final b = StringBuffer()
    ..writeln('FittArc health record')
    ..writeln('Prepared on ${date.format(now)}')
    ..writeln();

  final bp = homeBpSummary(all, now);
  if (bp.hasAverage) {
    b
      ..writeln('Home blood pressure, last 7 days')
      ..writeln(
        'Average ${bp.avgSystolic}/${bp.avgDiastolic} mmHg from ${bp.count} readings over ${bp.days} '
        '${bp.days == 1 ? 'day' : 'days'}: ${bp.rating!.label}'
        '${bp.complete ? '' : ' (fewer than ${bp.needed} readings, so only a rough guide)'}',
      )
      ..writeln();
  }

  for (final kind in ReadingKind.values) {
    final list = [
      for (final r in all.reversed)
        if (r.kind == kind) r,
    ].take(10).toList();
    if (list.isEmpty) continue;
    b.writeln('${kind.label} (${kind.unit}), latest ${list.length}');
    for (final r in list) {
      final extra = switch (kind) {
        ReadingKind.bloodPressure => r.pulse != null ? ', pulse ${r.pulse}' : '',
        ReadingKind.glucose => ', ${r.context?.label.toLowerCase() ?? 'other time'}',
        _ => '',
      };
      b.writeln('  ${stamp.format(r.at)}: ${r.display}$extra (${r.rating.label})');
    }
    b.writeln();
  }

  b.writeln(
    'These numbers were typed in or imported by the user from their own devices. FittArc does not measure them '
    'and this is not a diagnosis.',
  );
  return b.toString().trimRight();
}
