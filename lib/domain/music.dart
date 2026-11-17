import 'dart:math' as math;

enum GuitarString {
  first(1, 64),
  second(2, 59),
  third(3, 55),
  fourth(4, 50),
  fifth(5, 45),
  sixth(6, 40),
  seventh(7, 35);

  const GuitarString(this.number, this.openMidi);
  final int number;
  final int openMidi;

  static GuitarString fromNumber(int number) =>
      values.firstWhere((s) => s.number == number);
}

enum Finger {
  indexFinger(1),
  middle(2),
  ring(3),
  pinky(4);

  const Finger(this.number);
  final int number;

  static Finger fromNumber(int number) =>
      values.firstWhere((f) => f.number == number);
}

class SweepNote {
  const SweepNote({
    required this.string,
    required this.fret,
    required this.finger,
  });
  final GuitarString string;
  final int fret;
  final Finger finger;
}

enum PracticeMode {
  strict3nps('Strict 3NPS'),
  sweepArp('Sweep Arpeggio');

  const PracticeMode(this.label);
  final String label;
}

enum ChordQuality {
  maj('Major', [0, 2, 4, 5, 7, 9, 11], [0, 4, 7]),
  min('Minor', [0, 2, 3, 5, 7, 8, 10], [0, 3, 7]),
  dominant7('Dominant 7', [0, 2, 4, 5, 7, 9, 10], [0, 4, 7, 10]),
  minor7('Minor 7', [0, 2, 3, 5, 7, 9, 10], [0, 3, 7, 10]);

  const ChordQuality(this.label, this.scaleIntervals, this.chordToneIntervals);
  final String label;
  final List<int> scaleIntervals;
  final List<int> chordToneIntervals;
}

const noteNames = [
  'C',
  'C#',
  'D',
  'D#',
  'E',
  'F',
  'F#',
  'G',
  'G#',
  'A',
  'A#',
  'B',
];
const fretMin = 1;
const fretMax = 24;
const maxPatternSpan = 4;
const fretCount = fretMax - fretMin + 1;
const inlayFrets = {3, 5, 7, 9, 12, 15, 17, 19, 21, 24};

String noteNameAt(GuitarString string, int fret) =>
    noteNames[(string.openMidi + fret) % 12];
int midiForNote(SweepNote note) => note.string.openMidi + note.fret;
double midiToFreq(int midi) => 440 * math.pow(2, (midi - 69) / 12).toDouble();

Finger guessFinger(int fret, int patternMinFret) {
  final rel = fret - patternMinFret;
  if (rel <= 0) return Finger.indexFinger;
  if (rel == 1) return Finger.middle;
  if (rel == 2) return Finger.ring;
  return Finger.pinky;
}
