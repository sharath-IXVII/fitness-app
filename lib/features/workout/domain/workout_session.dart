import 'rep_counter.dart';
import 'routine.dart';

enum SessionEvent { none, rep, stepDone, finished }

/// Walks through a routine's steps, one rep counter at a time.
class WorkoutSession {
  WorkoutSession(this.routine) : assert(routine.steps.isNotEmpty) {
    counter = RepCounter.of(current.exercise);
  }

  final Routine routine;
  int stepIndex = 0;
  late RepCounter counter;
  bool finished = false;

  /// Reps (or seconds) achieved per completed step.
  final results = <int>[];

  RoutineStep get current => routine.steps[stepIndex];
  RoutineStep? get next => stepIndex + 1 < routine.steps.length ? routine.steps[stepIndex + 1] : null;
  double get stepProgress => (counter.progress / current.target).clamp(0.0, 1.0);
  double get overallProgress => finished ? 1 : (stepIndex + stepProgress) / routine.steps.length;

  SessionEvent update(Landmarks? landmarks, Duration now) {
    if (finished) return SessionEvent.none;
    final counted = counter.update(landmarks, now);
    if (counter.progress >= current.target) return _advance();
    return counted ? SessionEvent.rep : SessionEvent.none;
  }

  /// Moves on without finishing the step (practice mode only).
  SessionEvent skip() => _advance();

  SessionEvent _advance() {
    results.add(counter.progress);
    if (stepIndex + 1 >= routine.steps.length) {
      finished = true;
      return SessionEvent.finished;
    }
    stepIndex++;
    counter = RepCounter.of(current.exercise);
    return SessionEvent.stepDone;
  }
}
