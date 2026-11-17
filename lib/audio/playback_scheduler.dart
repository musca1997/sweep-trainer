import '../app/subdivision.dart';

/// One step of a scheduled playback sequence.
class PlaybackTick {
  const PlaybackTick({
    required this.patternStep,
    required this.shouldClick,
    required this.isRoundBoundary,
  });

  /// Index into the pattern for this tick.
  final int patternStep;

  /// True when this tick falls on a metronome beat (quarter note).
  final bool shouldClick;

  /// True when this tick is the last step of the pattern (round boundary).
  final bool isRoundBoundary;
}

/// Pure-Dart sequence math for the playback loop: cycles through the
/// pattern and marks beat/round boundaries. No timers, no audio — fully
/// unit-testable.
class PlaybackScheduler {
  PlaybackScheduler({required this.patternLength});

  final int patternLength;
  int _tick = 0;

  /// Returns the next tick and advances the internal counter.
  PlaybackTick next({required int stepsPerQuarter}) {
    final step = _tick % patternLength;
    final tick = PlaybackTick(
      patternStep: step,
      shouldClick: _tick % stepsPerQuarter == 0,
      isRoundBoundary: step == patternLength - 1,
    );
    _tick += 1;
    return tick;
  }

  /// Restarts the sequence from step 0 / tick 0.
  void reset() => _tick = 0;
}

/// Steps per quarter note for a subdivision.
int stepsPerQuarter(Subdivision subdivision) => switch (subdivision) {
  Subdivision.sixteenth => 4,
  Subdivision.eighthTriplet => 3,
  Subdivision.sixteenthTriplet => 6,
};
