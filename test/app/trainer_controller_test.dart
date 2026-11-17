import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_sweep_trainer/app/subdivision.dart';
import 'package:guitar_sweep_trainer/app/trainer_controller.dart';
import 'package:guitar_sweep_trainer/domain/music.dart';

void main() {
  randomizeTests();
  test('defaults match React trainer', () {
    final c = TrainerController();
    expect(c.root, 'E');
    expect(c.quality, ChordQuality.min);
    expect(c.position, 12);
    expect(c.mode, PracticeMode.sweepArp);
    expect(c.sweepLowString, GuitarString.sixth);
    expect(c.bpm, 150);
    expect(c.subdivision, Subdivision.sixteenth);
    expect(c.metronomeOn, isTrue);
    expect(c.showNoteNames, isTrue);
    expect(c.autoRampOn, isFalse);
    expect(c.rampEveryRounds, 2);
    expect(c.rampStep, 5);
    expect(c.targetBpm, 170);
    expect(c.completedRounds, 0);
    expect(c.isRunning, isFalse);
    expect(c.activeStep, isNull);
  });

  test('changing parameters regenerates pattern', () {
    final c = TrainerController();
    final before = c.pattern;
    c.setRoot('A');
    c.setPosition(5);
    final after = c.pattern;
    expect(after, isNotEmpty);
    expect(after, isNot(equals(before)));
  });

  test('advanceStep increments completed rounds and auto ramps', () {
    final c = TrainerController();
    c.autoRampOn = true;
    c.rampEveryRounds = 1;
    c.rampStep = 5;
    c.targetBpm = 160;
    c.bpm = 150;

    for (var i = 0; i < c.pattern.length; i++) {
      c.advanceStep();
    }

    expect(c.completedRounds, 1);
    expect(c.bpm, 155);
  });

  test('startStateOnly and stopStateOnly manage running state', () {
    final c = TrainerController();
    c.startStateOnly();
    expect(c.isRunning, isTrue);
    expect(c.activeStep, isNull);

    c.advanceStep();
    expect(c.activeStep, 0);

    c.stopStateOnly();
    expect(c.isRunning, isFalse);
    expect(c.activeStep, isNull);
  });

  test('setters clamp to React slider ranges', () {
    final c = TrainerController();
    c.bpm = 999;
    expect(c.bpm, 220);
    c.bpm = 1;
    expect(c.bpm, 60);
    c.setPosition(99);
    expect(c.position, 20);
    c.targetBpm = 0;
    expect(c.targetBpm, 80);
    c.rampStep = 100;
    expect(c.rampStep, 15);
    c.rampEveryRounds = 0;
    expect(c.rampEveryRounds, 1);
  });
}

void randomizeTests() {
  test('randomize picks a playable root/quality/position combination', () {
    final c = TrainerController();
    c.randomize(random: math.Random(42));
    expect(c.pattern, isNotEmpty);
    expect(noteNames, contains(c.root));
    expect(
      c.position,
      inInclusiveRange(
        TrainerController.positionMin,
        TrainerController.positionMax,
      ),
    );
  });

  test('randomize keeps mode and string range untouched', () {
    final c = TrainerController();
    c.mode = PracticeMode.strict3nps;
    c.sweepLowString = GuitarString.fifth;
    c.randomize(random: math.Random(7));
    expect(c.mode, PracticeMode.strict3nps);
    expect(c.sweepLowString, GuitarString.fifth);
    expect(c.pattern, isNotEmpty);
  });

  test('randomize notifies listeners', () {
    final c = TrainerController();
    var notified = 0;
    c.addListener(() => notified += 1);
    c.randomize(random: math.Random(1));
    expect(notified, greaterThan(0));
  });
}
