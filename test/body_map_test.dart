import 'package:fitalarm/features/training/domain/move.dart';
import 'package:fitalarm/features/training/domain/muscles.dart';
import 'package:fitalarm/features/training/widgets/body_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('muscle words map to body areas', () {
    expect(musclesIn('Chest, triceps, shoulders'), {Muscle.chest, Muscle.triceps, Muscle.shoulders});
    expect(musclesIn('Glutes, hamstrings'), {Muscle.glutes, Muscle.hamstrings});
    expect(musclesIn('Whole core'), {Muscle.abs, Muscle.obliques, Muscle.lowerBack});
    expect(musclesIn('Legs, cardio'), {Muscle.quads, Muscle.hamstrings, Muscle.glutes, Muscle.calves});
    expect(musclesIn('Full body'), Muscle.values.toSet());
    expect(musclesIn('Lower back, glutes'), {Muscle.lowerBack, Muscle.glutes});
    expect(musclesIn('Upper back, shoulders'), {Muscle.upperBack, Muscle.shoulders});
    expect(musclesIn('Biceps, forearms'), {Muscle.biceps, Muscle.forearms});
  });

  test('every guided move lights up at least one area (warm-ups aside)', () {
    for (final m in Moves.all) {
      if (m.muscles == 'Warm-up') continue;
      expect(musclesIn(m.muscles), isNotEmpty, reason: '${m.name}: ${m.muscles}');
    }
  });

  testWidgets('the body map draws and names the muscles', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Center(child: BodyMap(muscles: {Muscle.chest, Muscle.triceps})),
      ),
    );
    expect(t.takeException(), isNull);
    expect(find.text('Chest'), findsOneWidget);
    expect(find.text('Front'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
  });
}
