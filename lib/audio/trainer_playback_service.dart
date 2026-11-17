import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app/subdivision.dart';
import '../app/trainer_controller.dart';
import '../domain/music.dart';
import 'audio_engine.dart';
import 'playback_scheduler.dart';

/// Signature of the timer-creation function, matching `Timer.periodic`.
/// Injectable so tests can drive ticks manually without real timers.
typedef TimerFactory =
    Timer Function(Duration duration, void Function(Timer) callback);

/// Connects [TrainerController] state to an [AudioEngine] via a
/// [PlaybackScheduler].
///
/// Owns the playback loop: each tick plays the current pattern note (and a
/// metronome click on quarter boundaries when enabled), highlights the step
/// in the controller, and lets the controller count rounds / apply auto-ramp.
///
/// BPM or subdivision changes while running are picked up from controller
/// notifications and the timer is rescheduled with the new step duration.
class TrainerPlaybackService {
  TrainerPlaybackService({
    required this.controller,
    required this.engine,
    TimerFactory? timerFactory,
  }) : _timerFactory = timerFactory ?? Timer.periodic;

  final TrainerController controller;
  final AudioEngine engine;
  final TimerFactory _timerFactory;

  Timer? _timer;
  PlaybackScheduler? _scheduler;
  bool _started = false;
  bool _disposed = false;
  int _lastBpm = 0;
  Subdivision? _lastSubdivision;
  void Function()? _controllerListener;

  bool get isRunning => _started;

  /// Starts playback: initializes the engine (no-op if already done),
  /// marks the controller running, and schedules the tick loop.
  ///
  /// Refuses to start when the pattern is empty or playback already runs,
  /// so repeated START taps cannot create duplicate timers.
  Future<void> start() async {
    if (_started || _disposed) return;
    if (controller.pattern.isEmpty) return;
    await engine.init();
    _started = true;
    _lastBpm = controller.bpm;
    _lastSubdivision = controller.subdivision;
    _scheduler = PlaybackScheduler(patternLength: controller.pattern.length);
    _controllerListener = _onControllerChanged;
    controller.addListener(_controllerListener!);
    controller.startStateOnly();
    _startTimer();
  }

  /// Stops playback immediately: cancels the timer, clears scheduler and
  /// controller playback state, and silences the engine. Idempotent and
  /// safe to call when not running (e.g. from app lifecycle callbacks).
  Future<void> stop() async {
    _started = false;
    _timer?.cancel();
    _timer = null;
    _scheduler = null;
    if (_controllerListener != null) {
      controller.removeListener(_controllerListener!);
      _controllerListener = null;
    }
    controller.stopStateOnly();
    await engine.stopAll();
  }

  /// Stops playback and releases the engine. The service must not be used
  /// afterwards.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    await engine.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = _timerFactory(
      stepDuration(controller.bpm, controller.subdivision),
      _onTick,
    );
  }

  void _onTick(Timer _) {
    unawaited(tickOnce());
  }

  /// Advances the scheduler and plays the note (and click) for the current
  /// step. Exposed for tests so ticks can be driven without real timers.
  @visibleForTesting
  Future<void> tickOnce() async {
    final pattern = controller.pattern;
    if (pattern.isEmpty) {
      await stop();
      return;
    }
    // Recreate the scheduler if the pattern changed while running so the
    // tick sequence restarts with the new length.
    if (_scheduler == null || _scheduler!.patternLength != pattern.length) {
      _scheduler = PlaybackScheduler(patternLength: pattern.length);
    }
    final tick = _scheduler!.next(
      stepsPerQuarter: stepsPerQuarter(controller.subdivision),
    );
    final note = pattern[tick.patternStep];

    await engine.playGuitarMidi(midiForNote(note));
    if (controller.metronomeOn && tick.shouldClick) {
      await engine.playClick(accent: tick.patternStep == 0);
    }

    controller.advanceStep();
    // Ensure the highlighted step always matches the scheduler, even after
    // a mid-run pattern change.
    controller.setActiveStep(tick.patternStep);
  }

  void _onControllerChanged() {
    if (!_started) return;
    if (controller.bpm != _lastBpm ||
        controller.subdivision != _lastSubdivision) {
      _lastBpm = controller.bpm;
      _lastSubdivision = controller.subdivision;
      _startTimer();
    }
  }
}
