/// Abstraction over the low-latency audio backend used by the trainer.
///
/// Kept free of Flutter UI imports (and of any concrete backend such as
/// `flutter_soloud`) so it can be faked in unit tests and swapped for a
/// different backend later.
abstract class AudioEngine {
  /// Initializes the engine and preloads its sound sources.
  ///
  /// Must be idempotent: implementations should no-op when already
  /// initialized, and `play*` methods may call this defensively.
  Future<void> init();

  /// Plays a short guitar-like pluck at the given MIDI pitch.
  ///
  /// [velocity] is the loudness in the range 0.0-1.0.
  Future<void> playGuitarMidi(int midi, {double velocity = 0.8});

  /// Plays a metronome click; [accent] marks the first beat of a bar
  /// and should be noticeably louder.
  Future<void> playClick({bool accent = false});

  /// Stops all currently playing voices immediately.
  Future<void> stopAll();

  /// Releases all resources. The engine must not be used afterwards.
  Future<void> dispose();
}
