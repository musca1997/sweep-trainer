import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/music.dart';
import 'fretboard_painter.dart';

/// Minimum fret-cell width (logical px). When the viewport cannot fit all
/// 24 frets at this width, the board is zoomed and the viewport follows
/// the selected [FretboardView.position] automatically.
const double kMinFretWidth = 75;

/// Responsive 24-fret fretboard rendered with a [CustomPainter].
///
/// The board is zoomed to at least [kMinFretWidth] px per cell and the
/// viewport always shows the selected position (2 frets of context before
/// it). Whenever [position] changes (slider, ROLL, etc.) the viewport
/// follows automatically — there is no manual panning.
class FretboardView extends StatefulWidget {
  const FretboardView({
    super.key,
    required this.pattern,
    required this.rootPc,
    required this.visibleLowString,
    required this.position,
    required this.activeStep,
    required this.showNoteNames,
  });

  /// Notes of the current practice pattern, in playback order.
  final List<SweepNote> pattern;

  /// Pitch class (0-11) of the selected root, used to highlight root notes.
  final int rootPc;

  /// Lowest string shown on the board; the board always shows strings
  /// `1..visibleLowString.number` with string 1 on top.
  final GuitarString visibleLowString;

  /// Current position; its fret cells get a white marker and the viewport
  /// centers on it.
  final int position;

  /// Index of the currently sounding pattern step, or null when idle.
  final int? activeStep;

  /// When true, note names are drawn on pattern dots (compact boards show
  /// names only on root/active notes).
  final bool showNoteNames;

  @override
  State<FretboardView> createState() => _FretboardViewState();
}

class _FretboardViewState extends State<FretboardView> {
  /// Viewport offset in fret units; 0 = board starts at fret 1.
  double _fretOffset = 0;

  /// The position the viewport was last aligned to; used to detect
  /// position changes inside the LayoutBuilder (where maxOffset is known).
  int? _lastFocusedPosition;

  /// Offset that shows [position] with a couple of frets of context before
  /// it, so the position marker and the pattern below it are visible.
  /// Always an integer so cell borders land exactly on fret lines and the
  /// string-label column stays clear.
  double _focusedOffset(int position, double maxOffset) {
    return (position - 2).clamp(0.0, maxOffset).roundToDouble();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final layout = computeFretboardLayout(
          size,
          widget.visibleLowString.number,
          minFretWidth: kMinFretWidth,
          maxStringHeight: kMaxStringHeight,
        );
        final step = layout.fretWidth + fretboardFretGap;
        // Whole fret cells only: never show a partially visible fret on
        // the right edge, and keep cell borders exactly at integer fret
        // positions so the first cell never bleeds into the string-label
        // column.
        final visibleFrets = ((layout.boardWidth + fretboardFretGap) / step)
            .floorToDouble();
        final maxOffset = math.max(0.0, fretCount - visibleFrets);

        // Follow the selected position (also covers pattern changes from
        // ROLL, which regenerates the position marker). Re-computes only
        // when position actually changed, so scrolling the controls does
        // not cause needless repaints.
        if (_lastFocusedPosition != widget.position ||
            _fretOffset > maxOffset) {
          _lastFocusedPosition = widget.position;
          _fretOffset = _focusedOffset(widget.position, maxOffset);
        }

        final firstVisibleFret = _fretOffset.round() + fretMin;
        final lastVisibleFret = math.min(
          fretMax,
          firstVisibleFret + visibleFrets.round() - 1,
        );

        return Semantics(
          container: true,
          label:
              'Fretboard with ${widget.pattern.length} notes over '
              '${widget.visibleLowString.number} strings',
          child: CustomPaint(
            key: const Key('fretboard'),
            painter: FretboardPainter(
              pattern: widget.pattern,
              rootPc: widget.rootPc,
              stringCount: widget.visibleLowString.number,
              position: widget.position,
              activeStep: widget.activeStep,
              showNoteNames: widget.showNoteNames,
              fretOffset: _fretOffset,
              minFretWidth: kMinFretWidth,
              firstVisibleFret: firstVisibleFret,
              lastVisibleFret: lastVisibleFret,
            ),
          ),
        );
      },
    );
  }
}
