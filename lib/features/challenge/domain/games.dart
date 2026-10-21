import 'dart:math' as math;

import '../../alarm/domain/challenge.dart';

enum GameKind { math, memory, order }

class MathProblem {
  const MathProblem(this.text, this.answer);

  final String text;
  final int answer;
}

/// Sums that need a moment of real thought, scaled by [level].
MathProblem mathProblem(ChallengeLevel level, math.Random rng) {
  int r(int lo, int hi) => lo + rng.nextInt(hi - lo + 1);
  switch (level) {
    case ChallengeLevel.easy:
      final a = r(12, 49), b = r(6, 39);
      return rng.nextBool() ? MathProblem('$a + $b', a + b) : MathProblem('${a + b} − $b', a);
    case ChallengeLevel.medium:
      if (rng.nextBool()) {
        final a = r(6, 14), b = r(4, 12);
        return MathProblem('$a × $b', a * b);
      }
      final a = r(25, 89), b = r(12, 49), c = r(5, 30);
      return MathProblem('$a + $b − $c', a + b - c);
    case ChallengeLevel.hard:
      final a = r(12, 24), b = r(6, 13), c = r(11, math.min(89, a * b - 1));
      return rng.nextBool() ? MathProblem('$a × $b + $c', a * b + c) : MathProblem('$a × $b − $c', a * b - c);
  }
}

/// How many sums to solve in a row.
int mathCount(ChallengeLevel level) => switch (level) {
  ChallengeLevel.easy => 3,
  ChallengeLevel.medium => 4,
  ChallengeLevel.hard => 5,
};

/// Memory grid: side length and the length of the first pattern. Each of
/// the two rounds adds one tile.
({int side, int length}) memorySpec(ChallengeLevel level) => switch (level) {
  ChallengeLevel.easy => (side: 3, length: 4),
  ChallengeLevel.medium => (side: 4, length: 5),
  ChallengeLevel.hard => (side: 4, length: 7),
};

const memoryRounds = 2;

/// A pattern of distinct tile indices.
List<int> memoryPattern(int side, int length, math.Random rng) {
  final tiles = List.generate(side * side, (i) => i)..shuffle(rng);
  return tiles.take(length).toList();
}

/// Number-order grid side: tap 1…n² in order.
int orderSide(ChallengeLevel level) => switch (level) {
  ChallengeLevel.easy => 3,
  ChallengeLevel.medium => 4,
  ChallengeLevel.hard => 5,
};

List<int> orderGrid(int side, math.Random rng) => List.generate(side * side, (i) => i + 1)..shuffle(rng);

/// The games to play, in order, for a challenge.
List<GameKind> gamesFor(AlarmChallenge c, math.Random rng) => switch (c) {
  AlarmChallenge.math => [GameKind.math],
  AlarmChallenge.memory => [GameKind.memory],
  AlarmChallenge.order => [GameKind.order],
  AlarmChallenge.mixed => [...GameKind.values]..shuffle(rng),
  AlarmChallenge.workout => const [],
};
