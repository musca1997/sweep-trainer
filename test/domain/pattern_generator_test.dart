import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_sweep_trainer/domain/music.dart';
import 'package:guitar_sweep_trainer/domain/pattern_generator.dart';

/// All "React parity" expectations below were verified by compiling the pure
/// pattern functions extracted from `src/components/Trainer.tsx` with tsc and
/// running them in node. The Dart port must produce identical output.
void main() {
  test('strict 3NPS returns non-empty mirrored pattern', () {
    final pattern = buildPattern(
      rootPc: noteNames.indexOf('A'),
      quality: ChordQuality.min,
      position: 5,
      mode: PracticeMode.strict3nps,
      sweepLowString: GuitarString.sixth,
    );

    expect(pattern, isNotEmpty);
    expect(pattern.every((n) => n.fret >= 0 && n.fret <= fretMax), isTrue);
    expect(
      pattern.first.string.number,
      greaterThanOrEqualTo(pattern.last.string.number),
    );
  });

  test(
    'sweep arpeggio returns React parity pattern for E minor position 12 strings 1-6',
    () {
      final pattern = buildPattern(
        rootPc: noteNames.indexOf('E'),
        quality: ChordQuality.min,
        position: 12,
        mode: PracticeMode.sweepArp,
        sweepLowString: GuitarString.sixth,
      );

      expect(pattern.map((n) => (n.string.number, n.fret, n.finger.number)), [
        (6, 12, 1),
        (5, 14, 3),
        (4, 14, 3),
        (3, 12, 1),
        (2, 12, 1),
        (1, 12, 1),
        (1, 15, 4),
        (1, 12, 1),
        (2, 12, 1),
        (3, 12, 1),
        (4, 14, 3),
        (5, 14, 3),
        (6, 12, 1),
        (6, 15, 4),
      ]);
    },
  );

  test(
    'strict 3NPS returns React parity pattern for A minor position 5 strings 1-6',
    () {
      final pattern = buildPattern(
        rootPc: noteNames.indexOf('A'),
        quality: ChordQuality.min,
        position: 5,
        mode: PracticeMode.strict3nps,
        sweepLowString: GuitarString.sixth,
      );

      expect(pattern.map((n) => (n.string.number, n.fret, n.finger.number)), [
        (6, 5, 1),
        (6, 7, 3),
        (6, 8, 4),
        (5, 5, 1),
        (5, 7, 3),
        (5, 8, 4),
        (4, 5, 1),
        (4, 7, 3),
        (4, 9, 4),
        (3, 5, 1),
        (3, 7, 3),
        (3, 9, 4),
        (2, 5, 1),
        (2, 6, 2),
        (2, 8, 4),
        (1, 5, 1),
        (1, 7, 3),
        (1, 8, 4),
        (1, 7, 3),
        (1, 5, 1),
        (2, 8, 4),
        (2, 6, 2),
        (2, 5, 1),
        (3, 9, 4),
        (3, 7, 3),
        (3, 5, 1),
        (4, 9, 4),
        (4, 7, 3),
        (4, 5, 1),
        (5, 8, 4),
        (5, 7, 3),
        (5, 5, 1),
        (6, 8, 4),
        (6, 7, 3),
      ]);
    },
  );

  test('sweep arpeggio supports seven-string range with React parity', () {
    // The real React code returns an empty pattern for E minor at position
    // 12 across 7 strings (its anchor/DP search finds no playable path), so
    // parity requires empty here too.
    final empty = buildPattern(
      rootPc: noteNames.indexOf('E'),
      quality: ChordQuality.min,
      position: 12,
      mode: PracticeMode.sweepArp,
      sweepLowString: GuitarString.seventh,
    );
    expect(empty, isEmpty);

    // Position 1 does produce a full 7-string sweep in the React app.
    final pattern = buildPattern(
      rootPc: noteNames.indexOf('E'),
      quality: ChordQuality.min,
      position: 1,
      mode: PracticeMode.sweepArp,
      sweepLowString: GuitarString.seventh,
    );
    expect(pattern.any((n) => n.string == GuitarString.seventh), isTrue);
    expect(pattern.map((n) => (n.string.number, n.fret, n.finger.number)), [
      (7, 5, 4),
      (6, 3, 2),
      (5, 2, 1),
      (4, 2, 1),
      (3, 4, 3),
      (2, 5, 4),
      (1, 3, 2),
      (2, 5, 4),
      (3, 4, 3),
      (4, 2, 1),
      (5, 2, 1),
      (6, 3, 2),
      (7, 5, 4),
    ]);
  });

  test(
    'sweep arpeggio returns React parity pattern for C major position 8 strings 1-5',
    () {
      final pattern = buildPattern(
        rootPc: noteNames.indexOf('C'),
        quality: ChordQuality.maj,
        position: 8,
        mode: PracticeMode.sweepArp,
        sweepLowString: GuitarString.fifth,
      );

      expect(pattern.map((n) => (n.string.number, n.fret, n.finger.number)), [
        (4, 10, 3),
        (3, 9, 2),
        (2, 8, 1),
        (1, 8, 1),
        (1, 12, 4),
        (1, 8, 1),
        (2, 8, 1),
        (3, 9, 2),
        (4, 10, 3),
      ]);
    },
  );

  test(
    'sweep arpeggio returns React parity pattern for G dominant 7 position 3 strings 1-4',
    () {
      final pattern = buildPattern(
        rootPc: noteNames.indexOf('G'),
        quality: ChordQuality.dominant7,
        position: 3,
        mode: PracticeMode.sweepArp,
        sweepLowString: GuitarString.fourth,
      );

      expect(pattern.map((n) => (n.string.number, n.fret, n.finger.number)), [
        (4, 5, 1),
        (3, 7, 3),
        (2, 6, 2),
        (1, 7, 3),
        (2, 6, 2),
        (3, 7, 3),
        (4, 5, 1),
      ]);
    },
  );
}
