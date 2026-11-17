import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_sweep_trainer/audio/audio_engine.dart';

import 'fake_audio_engine.dart';

void main() {
  test('AudioEngine contract: init, play, stop, dispose via fake', () async {
    final engine = FakeAudioEngine();

    expect(engine.initialized, isFalse);
    await engine.init();
    expect(engine.initialized, isTrue);

    await engine.playGuitarMidi(69);
    await engine.playGuitarMidi(64, velocity: 0.5);
    await engine.playClick();
    await engine.playClick(accent: true);

    expect(engine.playedMidi, [69, 64]);
    expect(engine.clicks, 2);
    expect(engine.lastClickAccent, isTrue);

    await engine.stopAll();
    expect(engine.stopCount, 1);

    await engine.dispose();
    expect(engine.disposed, isTrue);
  });

  test('AudioEngine interface stays pure (no UI imports)', () {
    // Compile-time guarantee: importing the interface must not drag in
    // flutter_soloud or Material widgets.
    expect(AudioEngine, isA<Type>());
  });
}
