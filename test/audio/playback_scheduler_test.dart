import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_sweep_trainer/app/subdivision.dart';
import 'package:guitar_sweep_trainer/audio/playback_scheduler.dart';

void main() {
  test('120 bpm sixteenth interval is 125ms', () {
    expect(
      stepDuration(120, Subdivision.sixteenth),
      const Duration(milliseconds: 125),
    );
  });

  test('120 bpm eighth triplet interval is about 166.667ms', () {
    expect(
      stepDuration(120, Subdivision.eighthTriplet).inMicroseconds,
      closeTo(166667, 2),
    );
  });

  test('120 bpm sixteenth triplet interval is about 83.333ms', () {
    expect(
      stepDuration(120, Subdivision.sixteenthTriplet).inMicroseconds,
      closeTo(83333, 2),
    );
  });

  test('quarter duration at 120 bpm is 500ms', () {
    expect(quarterDuration(120), const Duration(milliseconds: 500));
  });

  test('stepsPerQuarter matches subdivision math', () {
    expect(stepsPerQuarter(Subdivision.sixteenth), 4);
    expect(stepsPerQuarter(Subdivision.eighthTriplet), 3);
    expect(stepsPerQuarter(Subdivision.sixteenthTriplet), 6);
  });

  test('scheduler cycles through pattern steps', () {
    final scheduler = PlaybackScheduler(patternLength: 4);
    expect(scheduler.next(stepsPerQuarter: 4).patternStep, 0);
    expect(scheduler.next(stepsPerQuarter: 4).patternStep, 1);
    expect(scheduler.next(stepsPerQuarter: 4).patternStep, 2);
    expect(scheduler.next(stepsPerQuarter: 4).patternStep, 3);
    expect(scheduler.next(stepsPerQuarter: 4).patternStep, 0);
  });

  test('scheduler flags quarter-note clicks', () {
    final scheduler = PlaybackScheduler(patternLength: 8);
    // Beats land on ticks 0, 4, 8, ... (4 steps per quarter).
    expect(scheduler.next(stepsPerQuarter: 4).shouldClick, isTrue);
    expect(scheduler.next(stepsPerQuarter: 4).shouldClick, isFalse);
    expect(scheduler.next(stepsPerQuarter: 4).shouldClick, isFalse);
    expect(scheduler.next(stepsPerQuarter: 4).shouldClick, isFalse);
    expect(scheduler.next(stepsPerQuarter: 4).shouldClick, isTrue);
    expect(scheduler.next(stepsPerQuarter: 4).shouldClick, isFalse);
  });

  test('scheduler flags round boundary on last pattern step', () {
    final scheduler = PlaybackScheduler(patternLength: 8);
    for (var i = 0; i < 7; i++) {
      final tick = scheduler.next(stepsPerQuarter: 4);
      expect(tick.isRoundBoundary, isFalse);
    }
    final last = scheduler.next(stepsPerQuarter: 4);
    expect(last.isRoundBoundary, isTrue);
    expect(last.patternStep, 7);

    // Wraps around: tick 8 is step 0 again, not a boundary.
    final wrapped = scheduler.next(stepsPerQuarter: 4);
    expect(wrapped.patternStep, 0);
    expect(wrapped.isRoundBoundary, isFalse);
    expect(wrapped.shouldClick, isTrue);
  });

  test('reset restarts the sequence from step 0', () {
    final scheduler = PlaybackScheduler(patternLength: 4);
    scheduler.next(stepsPerQuarter: 4);
    scheduler.next(stepsPerQuarter: 4);
    scheduler.reset();
    expect(scheduler.next(stepsPerQuarter: 4).patternStep, 0);
  });
}
