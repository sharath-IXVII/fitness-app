/// Muscle areas shown on the body map.
enum Muscle {
  chest('Chest'),
  shoulders('Shoulders'),
  biceps('Biceps'),
  triceps('Triceps'),
  forearms('Forearms'),
  abs('Abs'),
  obliques('Obliques'),
  upperBack('Upper back'),
  lowerBack('Lower back'),
  glutes('Glutes'),
  hipFlexors('Hip flexors'),
  quads('Quads'),
  innerThighs('Inner thighs'),
  hamstrings('Hamstrings'),
  calves('Calves');

  const Muscle(this.label);

  final String label;
}

/// The muscles in a description such as "Chest, triceps, shoulders" or
/// "Legs, cardio". Unknown words are ignored.
Set<Muscle> musclesIn(String text) {
  final out = <Muscle>{};
  for (final raw in text.toLowerCase().split(RegExp(r'[,/&]| and '))) {
    final w = raw.trim();
    if (w.isEmpty) continue;
    out.addAll(switch (w) {
      _ when w.contains('full body') => Muscle.values,
      _ when w.contains('core') => const [Muscle.abs, Muscle.obliques, Muscle.lowerBack],
      _ when w.contains('oblique') => const [Muscle.obliques],
      _ when w.contains('abs') => const [Muscle.abs],
      _ when w.contains('chest') => const [Muscle.chest],
      _ when w.contains('shoulder') => const [Muscle.shoulders],
      _ when w.contains('bicep') => const [Muscle.biceps],
      _ when w.contains('tricep') => const [Muscle.triceps],
      _ when w.contains('forearm') => const [Muscle.forearms],
      _ when w.contains('arms') => const [Muscle.biceps, Muscle.triceps],
      _ when w.contains('lower back') => const [Muscle.lowerBack],
      _ when w.contains('upper back') => const [Muscle.upperBack],
      _ when w == 'back' || w.contains('spine') => const [Muscle.upperBack, Muscle.lowerBack],
      _ when w.contains('glute') => const [Muscle.glutes],
      _ when w.contains('hip flexor') => const [Muscle.hipFlexors],
      _ when w.contains('hips') => const [Muscle.hipFlexors, Muscle.glutes],
      _ when w.contains('quad') => const [Muscle.quads],
      _ when w.contains('inner thigh') => const [Muscle.innerThighs],
      _ when w.contains('hamstring') => const [Muscle.hamstrings],
      _ when w.contains('calf') || w.contains('calves') => const [Muscle.calves],
      _ when w.contains('legs') => const [Muscle.quads, Muscle.hamstrings, Muscle.glutes, Muscle.calves],
      _ => const <Muscle>[],
    });
  }
  return out;
}
