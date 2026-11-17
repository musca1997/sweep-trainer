import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_sweep_trainer/domain/music.dart';

void main() {
  test('standard and seven string open MIDI values match baseline', () {
    expect(GuitarString.seventh.openMidi, 35);
    expect(GuitarString.sixth.openMidi, 40);
    expect(GuitarString.first.openMidi, 64);
  });

  test('noteNameAt returns expected note names', () {
    expect(noteNameAt(GuitarString.sixth, 0), 'E');
    expect(noteNameAt(GuitarString.fifth, 0), 'A');
    expect(noteNameAt(GuitarString.first, 12), 'E');
  });

  test('midiToFreq maps A4 to 440Hz', () {
    expect(midiToFreq(69), closeTo(440, 0.001));
  });

  test('midiForNote adds fret to open string midi', () {
    expect(
      midiForNote(
        const SweepNote(
          string: GuitarString.sixth,
          fret: 12,
          finger: Finger.indexFinger,
        ),
      ),
      52,
    );
  });
}
