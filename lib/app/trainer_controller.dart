import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../domain/music.dart';
import '../domain/pattern_generator.dart';
import 'subdivision.dart';

/// Mutable trainer state, mirroring the settings and playback bookkeeping
/// of `src/components/Trainer.tsx`.
///
/// Owns no audio and no timers: playback is driven externally by
/// `TrainerPlaybackService` through [startStateOnly], [stopStateOnly],
/// [advanceStep] and [setActiveStep]. The pattern is derived from the
/// musical settings and regenerated when they change.
class TrainerController extends ChangeNotifier {
  static const int positionMin = 1;
  static const int positionMax = 20;
  static const int bpmMin = 60;
  static const int bpmMax = 220;
  static const int targetBpmMin = 80;
  static const int targetBpmMax = 240;
  static const int rampStepMin = 1;
  static const int rampStepMax = 15;
  static const int rampEveryRoundsMin = 1;
  static const int rampEveryRoundsMax = 8;

  String _root = 'E';
  ChordQuality _quality = ChordQuality.min;
  int _position = 12;
  PracticeMode _mode = PracticeMode.sweepArp;
  GuitarString _sweepLowString = GuitarString.sixth;
  int _bpm = 150;
  Subdivision _subdivision = Subdivision.sixteenth;
  bool _metronomeOn = true;
  bool _showNoteNames = true;
  bool _autoRampOn = false;
  int _rampEveryRounds = 2;
  int _rampStep = 5;
  int _targetBpm = 170;
  int _completedRounds = 0;
  bool _isRunning = false;
  int? _activeStep;
  int _step = 0;
  List<SweepNote>? _patternCache;

  String get root => _root;
  int get rootPc => noteNames.indexOf(_root);
  ChordQuality get quality => _quality;
  int get position => _position;
  PracticeMode get mode => _mode;
  GuitarString get sweepLowString => _sweepLowString;
  int get bpm => _bpm;
  Subdivision get subdivision => _subdivision;
  bool get metronomeOn => _metronomeOn;
  bool get showNoteNames => _showNoteNames;
  bool get autoRampOn => _autoRampOn;
  int get rampEveryRounds => _rampEveryRounds;
  int get rampStep => _rampStep;
  int get targetBpm => _targetBpm;
  int get completedRounds => _completedRounds;
  bool get isRunning => _isRunning;
  int? get activeStep => _activeStep;

  /// Current pattern for the active musical settings, cached until a
  /// pattern-affecting setting changes.
  List<SweepNote> get pattern => _patternCache ??= buildPattern(
    rootPc: rootPc,
    quality: _quality,
    position: _position,
    mode: _mode,
    sweepLowString: _sweepLowString,
  );

  void setRoot(String value) {
    if (!noteNames.contains(value)) {
      throw ArgumentError.value(value, 'root', 'must be a chromatic note name');
    }
    if (_root == value) return;
    _root = value;
    _patternCache = null;
    notifyListeners();
  }

  void setPosition(int value) {
    final clamped = value.clamp(positionMin, positionMax);
    if (_position == clamped) return;
    _position = clamped;
    _patternCache = null;
    notifyListeners();
  }

  set quality(ChordQuality value) {
    if (_quality == value) return;
    _quality = value;
    _patternCache = null;
    notifyListeners();
  }

  set mode(PracticeMode value) {
    if (_mode == value) return;
    _mode = value;
    _patternCache = null;
    notifyListeners();
  }

  set sweepLowString(GuitarString value) {
    if (_sweepLowString == value) return;
    _sweepLowString = value;
    _patternCache = null;
    notifyListeners();
  }

  set bpm(int value) {
    final clamped = value.clamp(bpmMin, bpmMax);
    if (_bpm == clamped) return;
    _bpm = clamped;
    notifyListeners();
  }

  set subdivision(Subdivision value) {
    if (_subdivision == value) return;
    _subdivision = value;
    notifyListeners();
  }

  set metronomeOn(bool value) {
    if (_metronomeOn == value) return;
    _metronomeOn = value;
    notifyListeners();
  }

  set showNoteNames(bool value) {
    if (_showNoteNames == value) return;
    _showNoteNames = value;
    notifyListeners();
  }

  set autoRampOn(bool value) {
    if (_autoRampOn == value) return;
    _autoRampOn = value;
    notifyListeners();
  }

  set rampEveryRounds(int value) {
    final clamped = value.clamp(rampEveryRoundsMin, rampEveryRoundsMax);
    if (_rampEveryRounds == clamped) return;
    _rampEveryRounds = clamped;
    notifyListeners();
  }

  set rampStep(int value) {
    final clamped = value.clamp(rampStepMin, rampStepMax);
    if (_rampStep == clamped) return;
    _rampStep = clamped;
    notifyListeners();
  }

  set targetBpm(int value) {
    final clamped = value.clamp(targetBpmMin, targetBpmMax);
    if (_targetBpm == clamped) return;
    _targetBpm = clamped;
    notifyListeners();
  }

  /// Rolls a random root + chord quality + position combination that
  /// produces a playable pattern for the current mode/string range.
  ///
  /// Mode and sweep string range are left untouched (they are usually set
  /// deliberately); [random] is injectable for tests.
  void randomize({math.Random? random}) {
    final rng = random ?? math.Random();
    for (var attempt = 0; attempt < 64; attempt++) {
      final candidateRoot = noteNames[rng.nextInt(noteNames.length)];
      final candidateQuality =
          ChordQuality.values[rng.nextInt(ChordQuality.values.length)];
      final candidatePosition =
          positionMin + rng.nextInt(positionMax - positionMin + 1);

      _root = candidateRoot;
      _quality = candidateQuality;
      _position = candidatePosition;
      _patternCache = null;

      if (pattern.isNotEmpty) {
        notifyListeners();
        return;
      }
    }
    // Extremely unlikely fallback: nothing rolled produced a pattern;
    // keep whatever settings are currently applied.
    notifyListeners();
  }

  /// Marks playback as running and resets per-run counters (matches the
  /// React trainer, which resets rounds on START).
  void startStateOnly() {
    _isRunning = true;
    _step = 0;
    _activeStep = null;
    _completedRounds = 0;
    notifyListeners();
  }

  /// Marks playback as stopped and clears playback-only state.
  void stopStateOnly() {
    _isRunning = false;
    _step = 0;
    _activeStep = null;
    notifyListeners();
  }

  /// Highlights [step] as the currently sounding pattern note.
  void setActiveStep(int? step) {
    if (_activeStep == step) return;
    _activeStep = step;
    notifyListeners();
  }

  /// Advances one step through the pattern: highlights the step, counts a
  /// completed round at the pattern boundary, and applies auto-ramp when
  /// the round count crosses the configured ramp interval.
  ///
  /// Mirrors the scheduled callback in the React trainer's
  /// `startPlayback`. Stops playback when the pattern is empty.
  void advanceStep() {
    if (pattern.isEmpty) {
      stopStateOnly();
      return;
    }

    final step = _step % pattern.length;
    _activeStep = step;
    _step += 1;

    if (step == pattern.length - 1) {
      _completedRounds += 1;
      _maybeAutoRamp();
    }

    notifyListeners();
  }

  void _maybeAutoRamp() {
    if (!_autoRampOn || _rampEveryRounds <= 0) return;
    if (_completedRounds % _rampEveryRounds != 0) return;
    if (_bpm >= _targetBpm) return;

    final nextBpm = math.min(_bpm + _rampStep, _targetBpm);
    if (nextBpm > _bpm) {
      _bpm = nextBpm;
    }
  }
}
