/// Practice subdivisions and their timing math.
///
/// Mirrors the SUBDIVISIONS list in `src/components/Trainer.tsx`:
/// - 16th (4 per quarter)
/// - 8th triplet (3 per quarter)
/// - 16th triplet (6 per quarter)
library;

enum Subdivision {
  sixteenth('16th'),
  eighthTriplet('Triplet'),
  sixteenthTriplet('6-let');

  const Subdivision(this.label);
  final String label;
}

/// Time between consecutive steps at [bpm] for [subdivision].
Duration stepDuration(int bpm, Subdivision subdivision) {
  final quarterMs = 60000 / bpm;
  final ms = switch (subdivision) {
    Subdivision.sixteenth => quarterMs / 4,
    Subdivision.eighthTriplet => quarterMs / 3,
    Subdivision.sixteenthTriplet => quarterMs / 6,
  };
  return Duration(microseconds: (ms * 1000).round());
}

/// Duration of one quarter note at [bpm].
Duration quarterDuration(int bpm) =>
    Duration(microseconds: ((60000 / bpm) * 1000).round());
