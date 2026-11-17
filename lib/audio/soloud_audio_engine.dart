import 'dart:math' as math;

import 'package:flutter_soloud/flutter_soloud.dart';

import '../domain/music.dart';
import 'audio_engine.dart';
import 'generated_wav.dart';

/// [AudioEngine] backed by flutter_soloud for low-latency playback.
///
/// Sound sources are generated in memory (see `generated_wav.dart`), so no
/// binary assets are required. Guitar notes are played from a single A4
/// pluck sample and pitched via relative playback speed.
///
/// NOTE: This class must not be constructed inside unit tests — the
/// flutter_soloud native library is opened when `SoLoud.instance` is first
/// accessed, which fails in the `flutter test` host environment. It is
/// verified via `flutter analyze` and manual device smoke testing instead.
class SoLoudAudioEngine implements AudioEngine {
  SoLoudAudioEngine({SoLoud? soloud}) : _soloud = soloud ?? SoLoud.instance;

  /// Reference pitch of the generated pluck sample (A4).
  static const int _referenceMidi = 69;

  final SoLoud _soloud;
  AudioSource? _click;
  AudioSource? _pluck;
  final Set<SoundHandle> _activeHandles = {};
  bool _initialized = false;
  bool _disposed = false;

  @override
  Future<void> init() async {
    if (_initialized || _disposed) return;
    await _soloud.init(sampleRate: 44100, bufferSize: 512);
    _click = await _soloud.loadMem(
      'click.wav',
      generateClickWav(),
      mode: LoadMode.memory,
    );
    _pluck = await _soloud.loadMem(
      'pluck_a4.wav',
      generatePluckWav(frequency: midiToFreq(_referenceMidi)),
      mode: LoadMode.memory,
    );
    _initialized = true;
  }

  @override
  Future<void> playGuitarMidi(int midi, {double velocity = 0.8}) async {
    if (_disposed) return;
    await init();
    final pluck = _pluck!;
    final handle = await _soloud.play(pluck, volume: velocity);
    _activeHandles.add(handle);
    // Pitch shift by relative playback speed from the A4 reference sample.
    final speed = math.pow(2, (midi - _referenceMidi) / 12).toDouble();
    _soloud.setRelativePlaySpeed(handle, speed);
  }

  @override
  Future<void> playClick({bool accent = false}) async {
    if (_disposed) return;
    await init();
    final handle = await _soloud.play(_click!, volume: accent ? 0.45 : 0.25);
    _activeHandles.add(handle);
  }

  @override
  Future<void> stopAll() async {
    if (!_initialized) return;
    for (final handle in _activeHandles.toList()) {
      await _soloud.stop(handle);
    }
    _activeHandles.clear();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _initialized = false;
    if (_soloud.isInitialized) {
      // Stops all voices, unloads all sources, and shuts the engine down.
      _soloud.deinit();
    }
    _click = null;
    _pluck = null;
    _activeHandles.clear();
  }
}
