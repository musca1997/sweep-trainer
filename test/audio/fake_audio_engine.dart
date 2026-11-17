import 'package:guitar_sweep_trainer/audio/audio_engine.dart';

/// In-memory [AudioEngine] fake for unit tests.
///
/// Records every call so tests can assert on what would have been played.
class FakeAudioEngine implements AudioEngine {
  bool initialized = false;
  final List<int> playedMidi = [];
  int clicks = 0;
  bool lastClickAccent = false;
  int stopCount = 0;
  bool disposed = false;

  @override
  Future<void> init() async {
    initialized = true;
  }

  @override
  Future<void> playGuitarMidi(int midi, {double velocity = 0.8}) async {
    playedMidi.add(midi);
  }

  @override
  Future<void> playClick({bool accent = false}) async {
    clicks += 1;
    lastClickAccent = accent;
  }

  @override
  Future<void> stopAll() async {
    stopCount += 1;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
