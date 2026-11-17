import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_sweep_trainer/app/trainer_controller.dart';
import 'package:guitar_sweep_trainer/audio/trainer_playback_service.dart';
import 'package:guitar_sweep_trainer/domain/music.dart';

import 'fake_audio_engine.dart';

void main() {
  late TrainerController controller;
  late FakeAudioEngine engine;
  late TrainerPlaybackService service;
  Timer? pendingTimer;
  final scheduledDurations = <Duration>[];

  /// Timer factory that records the requested interval but never fires,
  /// so tests drive ticks manually via `service.tickOnce()`.
  TrainerPlaybackService buildService({
    TrainerController? withController,
    bool metronomeOn = true,
  }) {
    controller = withController ?? TrainerController();
    controller.metronomeOn = metronomeOn;
    engine = FakeAudioEngine();
    service = TrainerPlaybackService(
      controller: controller,
      engine: engine,
      timerFactory: (duration, callback) {
        scheduledDurations.add(duration);
        pendingTimer = Timer(const Duration(days: 1), () {});
        return pendingTimer!;
      },
    );
    return service;
  }

  tearDown(() async {
    pendingTimer?.cancel();
    pendingTimer = null;
    scheduledDurations.clear();
    await service.dispose();
  });

  test(
    'start initializes engine, marks controller running, schedules ticks',
    () async {
      final service = buildService();
      await service.start();

      expect(engine.initialized, isTrue);
      expect(controller.isRunning, isTrue);
      expect(scheduledDurations, isNotEmpty);
      // 150 BPM 16th notes = 100 ms per step.
      expect(scheduledDurations.first, const Duration(milliseconds: 100));
      // No audio before the first tick.
      expect(engine.playedMidi, isEmpty);
      expect(engine.clicks, 0);
    },
  );

  test('start refuses to run twice (no duplicate timers)', () async {
    final service = buildService();
    await service.start();
    await service.start();
    expect(scheduledDurations.length, 1);
  });

  test('tick plays the current pattern note midi', () async {
    final service = buildService();
    await service.start();
    await service.tickOnce();

    // E minor, position 12, sweep arpeggio: first note is string 6 fret 12.
    expect(engine.playedMidi, [52]);
    expect(controller.activeStep, 0);
  });

  test('click plays on quarter boundaries with accent on beat one', () async {
    final service = buildService();
    await service.start();

    // Ticks 0..3: first tick is a beat (accented), the rest are not.
    for (var i = 0; i < 4; i++) {
      await service.tickOnce();
    }
    expect(engine.clicks, 1);
    expect(engine.lastClickAccent, isTrue);

    // Ticks 4..7: second beat, not accented.
    for (var i = 0; i < 4; i++) {
      await service.tickOnce();
    }
    expect(engine.clicks, 2);
    expect(engine.lastClickAccent, isFalse);
    expect(engine.playedMidi.length, 8);
  });

  test('no click when metronome is disabled', () async {
    final service = buildService(metronomeOn: false);
    await service.start();
    for (var i = 0; i < 4; i++) {
      await service.tickOnce();
    }
    expect(engine.playedMidi.length, 4);
    expect(engine.clicks, 0);
  });

  test('stop silences engine, clears active step, and is idempotent', () async {
    final service = buildService();
    await service.start();
    await service.tickOnce();
    await service.stop();

    expect(engine.stopCount, 1);
    expect(controller.isRunning, isFalse);
    expect(controller.activeStep, isNull);

    await service.stop();
    expect(engine.stopCount, 2); // safe to stop again
  });

  test('auto-ramp raises BPM after a completed round', () async {
    final rampController = TrainerController()
      ..autoRampOn = true
      ..rampEveryRounds = 1
      ..rampStep = 5
      ..targetBpm = 160
      ..bpm = 150;
    final service = buildService(withController: rampController);

    await service.start();
    for (var i = 0; i < rampController.pattern.length; i++) {
      await service.tickOnce();
    }

    expect(rampController.completedRounds, 1);
    expect(rampController.bpm, 155);
  });

  test('empty pattern refuses start and plays nothing', () async {
    final emptyController = _EmptyPatternController();
    final service = buildService(withController: emptyController);

    await service.start();
    expect(engine.initialized, isFalse);
    expect(emptyController.isRunning, isFalse);
    expect(engine.playedMidi, isEmpty);
    expect(engine.clicks, 0);
  });

  test('dispose releases the engine and stops playback', () async {
    final service = buildService();
    await service.start();
    await service.tickOnce();
    await service.dispose();

    expect(engine.disposed, isTrue);
    expect(service.isRunning, isFalse);
  });
}

/// Controller that yields no pattern, to exercise the empty-pattern guard.
class _EmptyPatternController extends TrainerController {
  @override
  List<SweepNote> get pattern => const [];
}
