import 'dart:math' as math;

import 'music.dart';

/// Pure-Dart port of the pattern generation logic from
/// `src/components/Trainer.tsx` (the React reference implementation).
///
/// The algorithms, constants and scoring below mirror the TypeScript source
/// function-for-function so pattern output stays bit-for-bit identical to
/// the web app. This file must remain free of Flutter imports so it is
/// fully unit-testable on the VM.
///
/// Reference functions ported:
/// - `listMatchingFrets`
/// - `getFretsForStringStrict3Nps`
/// - `getChordToneCandidatesInBox`
/// - `getChordToneCandidatesRelaxed`
/// - `getSeventhInterval`
/// - `buildRequiredChordTonePitchClasses`
/// - `generateFretboardPattern`
/// - `getNextHigherChordToneFret`
/// - `buildPattern`

/// All frets on [stringNo] whose pitch class is in [pitchClasses].
/// Mirrors `listMatchingFrets` (fret range 0..24).
List<int> listMatchingFrets(GuitarString stringNo, Set<int> pitchClasses) {
  final openMidi = stringNo.openMidi;
  final matchingFrets = <int>[];

  for (var fret = 0; fret <= fretMax; fret += 1) {
    final pitchClass = (openMidi + fret) % 12;
    if (pitchClasses.contains(pitchClass)) matchingFrets.add(fret);
  }

  return matchingFrets;
}

/// Picks up to three scale tones per string for a strict 3NPS box.
/// Mirrors `getFretsForStringStrict3Nps`.
List<int> getFretsForStringStrict3Nps(
  GuitarString stringNo,
  Set<int> scalePitchClasses,
  int position,
) {
  final matchingFrets = listMatchingFrets(stringNo, scalePitchClasses);

  final inBox = matchingFrets
      .where((f) => f >= position && f <= position + maxPatternSpan)
      .toList();
  if (inBox.length >= 3) return inBox.sublist(0, 3);

  List<int>? best;
  var bestScore = double.infinity;

  for (var i = 0; i < matchingFrets.length - 2; i += 1) {
    for (var j = i + 1; j < matchingFrets.length - 1; j += 1) {
      for (var k = j + 1; k < matchingFrets.length; k += 1) {
        final trio = [matchingFrets[i], matchingFrets[j], matchingFrets[k]];
        final span = trio[2] - trio[0];
        if (span > maxPatternSpan) continue;

        final center = (trio[0] + trio[1] + trio[2]) / 3;
        final score = (center - (position + 2)).abs();
        if (score < bestScore) {
          bestScore = score;
          best = trio;
        }
      }
    }
  }

  if (best != null) return best;
  return matchingFrets.take(3).toList();
}

/// Chord-tone frets strictly inside the position box. Mirrors
/// `getChordToneCandidatesInBox`.
List<int> getChordToneCandidatesInBox(
  GuitarString stringNo,
  Set<int> chordTonePitchClasses,
  int position,
) {
  final minFret = position;
  final maxFret = position + maxPatternSpan;
  return listMatchingFrets(
    stringNo,
    chordTonePitchClasses,
  ).where((f) => f >= minFret && f <= maxFret).toList();
}

/// Chord-tone frets in the box, falling back to a slightly widened window
/// (position - 2 .. position + 6). Mirrors `getChordToneCandidatesRelaxed`.
List<int> getChordToneCandidatesRelaxed(
  GuitarString stringNo,
  Set<int> chordTonePitchClasses,
  int position,
) {
  final strict = getChordToneCandidatesInBox(
    stringNo,
    chordTonePitchClasses,
    position,
  );
  if (strict.isNotEmpty) return strict;

  final minFret = math.max(fretMin, position - 2);
  final maxFret = math.min(fretMax, position + maxPatternSpan + 2);
  return listMatchingFrets(
    stringNo,
    chordTonePitchClasses,
  ).where((f) => f >= minFret && f <= maxFret).toList();
}

/// Seventh interval above the root for a quality: major 7 for `maj`,
/// minor 7 (b7) for everything else. Mirrors `getSeventhInterval`.
int getSeventhInterval(ChordQuality quality) {
  if (quality == ChordQuality.maj) return 11;
  return 10;
}

/// Pitch classes that must be covered by a complete pattern: the triad for
/// triadic qualities, the full four-note chord for dominant/minor 7.
/// Mirrors `buildRequiredChordTonePitchClasses`.
Set<int> buildRequiredChordTonePitchClasses(int rootPc, ChordQuality quality) {
  final triad = [
    rootPc,
    (rootPc + quality.chordToneIntervals[1]) % 12,
    (rootPc + quality.chordToneIntervals[2]) % 12,
  ];

  // 7-chord qualities require the full four notes; maj/min require a
  // complete triad.
  if (quality == ChordQuality.dominant7 || quality == ChordQuality.minor7) {
    return {...triad, (rootPc + getSeventhInterval(quality)) % 12};
  }

  return triad.toSet();
}

/// A candidate path through the active strings: one fret per string plus
/// the running score and sweep direction. Mirrors the `State` type in
/// `generateFretboardPattern`.
class _PatternState {
  const _PatternState({
    required this.frets,
    required this.pcs,
    required this.score,
    required this.direction,
  });

  final List<int> frets;
  final List<int> pcs;
  final double score;
  final int? direction; // -1 | 0 | 1 | null
}

/// JS `Array.prototype.sort` is stable; Dart's `List.sort` is not. Sorting
/// with the original index as a final tie-breaker reproduces stable-sort
/// results exactly, which matters for the beam search tie-breaking below.
List<T> _stableSortBy<T>(List<T> items, int Function(T, T) compare) {
  final indexed = List<(int, T)>.generate(items.length, (i) => (i, items[i]));
  indexed.sort((a, b) {
    final c = compare(a.$2, b.$2);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final entry in indexed) entry.$2];
}

/// Searches a fretboard path of chord tones sweeping down the strings,
/// then builds the full up/down sweep arpeggio. Mirrors
/// `generateFretboardPattern`.
List<SweepNote> generateFretboardPattern(
  int rootPc,
  ChordQuality quality,
  int position,
  GuitarString sweepLowString,
) {
  final chordToneOrder = [
    for (final interval in quality.chordToneIntervals) (rootPc + interval) % 12,
  ];
  final chordToneSet = chordToneOrder.toSet();
  final requiredToneSet = buildRequiredChordTonePitchClasses(rootPc, quality);

  final lowString = sweepLowString;
  final strings = <GuitarString>[
    for (var n = lowString.number; n >= 1; n -= 1) GuitarString.fromNumber(n),
  ];

  final allRootCandidates = <({GuitarString string, int fret, bool isRoot})>[
    for (final s in strings)
      for (final fret in getChordToneCandidatesRelaxed(s, {rootPc}, position))
        (string: s, fret: fret, isRoot: true),
  ];

  ({GuitarString string, int fret, bool isRoot})? anchor;

  if (allRootCandidates.isNotEmpty) {
    final sorted = _stableSortBy(allRootCandidates, (a, b) {
      if (a.string != b.string) return b.string.number - a.string.number;
      return (a.fret - (position + 1)).abs() - (b.fret - (position + 1)).abs();
    });
    anchor = sorted.first;
  } else {
    final lowestStrings = strings.take(2).toList();
    final fallbackCandidates = <({GuitarString string, int fret, bool isRoot})>[
      for (final s in lowestStrings)
        for (final fret in getChordToneCandidatesRelaxed(
          s,
          chordToneSet,
          position,
        ))
          (string: s, fret: fret, isRoot: false),
    ];
    if (fallbackCandidates.isEmpty) return [];
    anchor = _stableSortBy(fallbackCandidates, (a, b) {
      if (a.string != b.string) return b.string.number - a.string.number;
      return (a.fret - (position + 1)).abs() - (b.fret - (position + 1)).abs();
    }).first;
  }

  final anchorStringIdx = strings.indexOf(anchor.string);
  final activeStrings = strings.sublist(anchorStringIdx);

  final candidateMap = <GuitarString, List<int>>{};
  for (final s in activeStrings) {
    final cands = getChordToneCandidatesRelaxed(s, chordToneSet, position);
    candidateMap[s] = cands.isEmpty ? [] : cands;
  }
  candidateMap[anchor.string] = [anchor.fret];

  if ((candidateMap[activeStrings.first] ?? []).isEmpty) return [];

  var states = <_PatternState>[
    for (final fret in candidateMap[activeStrings.first] ?? const <int>[])
      _PatternState(
        frets: [fret],
        pcs: [(activeStrings.first.openMidi + fret) % 12],
        score: 0,
        direction: null,
      ),
  ];

  for (var i = 1; i < activeStrings.length; i += 1) {
    final currentString = activeStrings[i];
    final prevString = activeStrings[i - 1];
    final cands = candidateMap[currentString] ?? [];
    final nextStates = <_PatternState>[];

    for (final state in states) {
      final prevFret = state.frets.last;
      final prevPc = state.pcs.last;
      final prevMidi = prevString.openMidi + prevFret;

      for (final fret in cands) {
        final delta = fret - prevFret;
        if (delta.abs() > 3) continue;

        final stepDir = delta == 0 ? 0 : (delta > 0 ? 1 : -1);

        final midi = currentString.openMidi + fret;
        if (midi <= prevMidi) continue;

        final pc = midi % 12;
        var score = state.score;

        if (pc == prevPc) score += 6;
        if (state.direction != null &&
            stepDir != 0 &&
            state.direction != stepDir) {
          score += 7;
        }

        score += delta.abs() * 2.5;
        final target =
            position + 1 + (i - (activeStrings.length - 1) / 2) * 0.4;
        score += (fret - target).abs() * 1.5;

        final nextFrets = [...state.frets, fret];
        final span = nextFrets.reduce(math.max) - nextFrets.reduce(math.min);
        if (span > maxPatternSpan) continue;

        nextStates.add(
          _PatternState(
            frets: nextFrets,
            pcs: [...state.pcs, pc],
            score: score,
            direction: state.direction ?? (stepDir == 0 ? null : stepDir),
          ),
        );
      }
    }

    states = _stableSortBy(
      nextStates,
      (a, b) => a.score.compareTo(b.score),
    ).take(80).toList();
    if (states.isEmpty) return [];
  }

  final maxAllowedMissing = activeStrings.length <= 3 ? 1 : 0;

  final candidates =
      <({_PatternState state, int missing, double finalScore})>[];
  for (final s in states) {
    final covered = s.pcs.toSet();
    var missing = 0;
    for (final pc in requiredToneSet) {
      if (!covered.contains(pc)) missing += 1;
    }

    final span = s.frets.reduce(math.max) - s.frets.reduce(math.min);
    final finalScore = s.score + span * 2 + missing * 18;
    if (missing <= maxAllowedMissing) {
      candidates.add((state: s, missing: missing, finalScore: finalScore));
    }
  }

  final best = _stableSortBy(
    candidates,
    (a, b) => a.finalScore.compareTo(b.finalScore),
  );
  if (best.isEmpty) return [];

  final pickedFrets = best.first.state.frets;
  final patternMinFret = pickedFrets.reduce(math.min);

  final down = <SweepNote>[
    for (var idx = 0; idx < activeStrings.length; idx += 1)
      SweepNote(
        string: activeStrings[idx],
        fret: pickedFrets[idx],
        finger: guessFinger(pickedFrets[idx], patternMinFret),
      ),
  ];

  const highString = GuitarString.first;
  final lowBase = down.first;
  SweepNote? highBase;
  for (final n in down) {
    if (n.string == highString) {
      highBase = n;
      break;
    }
  }
  final maxPatternFret = math.min(fretMax, position + maxPatternSpan + 1);

  final int? highTurnFret = highBase != null
      ? getNextHigherChordToneFret(
          highString,
          chordToneSet,
          highBase.fret,
          maxPatternFret,
        )
      : null;
  final int? lowTurnFret = getNextHigherChordToneFret(
    lowBase.string,
    chordToneSet,
    lowBase.fret,
    maxPatternFret,
  );

  final highTurn =
      highTurnFret != null && highBase != null && highTurnFret != highBase.fret
      ? [
          SweepNote(
            string: highString,
            fret: highTurnFret,
            finger: guessFinger(highTurnFret, patternMinFret),
          ),
        ]
      : <SweepNote>[];
  final lowTurn = lowTurnFret != null && lowTurnFret != lowBase.fret
      ? [
          SweepNote(
            string: lowBase.string,
            fret: lowTurnFret,
            finger: guessFinger(lowTurnFret, patternMinFret),
          ),
        ]
      : <SweepNote>[];

  final highBaseReturn = highTurn.isNotEmpty && highBase != null
      ? [highBase]
      : <SweepNote>[];
  // React: `const up = [...down].slice(0, -1).reverse()` — down minus its
  // last (highest-string) note, reversed.
  final up = down.length > 1
      ? down.sublist(0, down.length - 1).reversed.toList()
      : <SweepNote>[];
  return [...down, ...highTurn, ...highBaseReturn, ...up, ...lowTurn];
}

/// First chord-tone fret strictly above [fromFret] (and within [maxFret]),
/// or null when there is none. Mirrors `getNextHigherChordToneFret`.
int? getNextHigherChordToneFret(
  GuitarString stringNo,
  Set<int> chordTonePitchClasses,
  int fromFret,
  int maxFret,
) {
  final candidates = listMatchingFrets(stringNo, chordTonePitchClasses);
  for (final f in candidates) {
    if (f > fromFret && f <= maxFret) return f;
  }
  return null;
}

/// Builds the full practice pattern (sweep arpeggio or strict 3NPS) for the
/// given musical settings. Mirrors `buildPattern`.
List<SweepNote> buildPattern({
  required int rootPc,
  required ChordQuality quality,
  required int position,
  required PracticeMode mode,
  required GuitarString sweepLowString,
}) {
  final scaleSet = {
    for (final interval in quality.scaleIntervals) (rootPc + interval) % 12,
  };

  if (mode == PracticeMode.strict3nps) {
    final rawStrings = <GuitarString>[
      for (var n = sweepLowString.number; n >= 1; n -= 1)
        GuitarString.fromNumber(n),
    ];

    final allRootCandidates = <({GuitarString string, int fret})>[
      for (final s in rawStrings)
        for (final fret in getChordToneCandidatesRelaxed(s, {rootPc}, position))
          (string: s, fret: fret),
    ];

    var activeStrings = rawStrings;
    if (allRootCandidates.isNotEmpty) {
      final sorted = _stableSortBy(allRootCandidates, (a, b) {
        if (a.string != b.string) return b.string.number - a.string.number;
        return (a.fret - (position + 1)).abs() -
            (b.fret - (position + 1)).abs();
      });
      final bestRoot = sorted.first;
      final anchorIdx = rawStrings.indexOf(bestRoot.string);
      activeStrings = rawStrings.sublist(anchorIdx);
    }

    final down = <SweepNote>[
      for (final stringNo in activeStrings)
        for (final fret in getFretsForStringStrict3Nps(
          stringNo,
          scaleSet,
          position,
        ))
          SweepNote(
            string: stringNo,
            fret: fret,
            finger: guessFinger(fret, position),
          ),
    ];

    final up = down.length >= 2
        ? down.sublist(1, down.length - 1).reversed.toList()
        : <SweepNote>[];
    return [...down, ...up];
  }

  return generateFretboardPattern(rootPc, quality, position, sweepLowString);
}
