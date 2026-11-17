import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/music.dart';

/// Gap in logical pixels between adjacent fret cells.
const double fretboardFretGap = 1.0;

/// Cap on the per-string row height (logical px): the board renders as a
/// compact wide strip, vertically centered, instead of stretching to fill
/// the whole pane.
const double kMaxStringHeight = 36;

/// Precomputed geometry for the fretboard, derived from the exact formula
/// used for phone fitting (see the migration plan, Task 11).
///
/// Kept as a pure function of [size] and [stringCount] so the fitting math
/// can be unit-tested without pumping widgets.
class FretboardLayout {
  const FretboardLayout({
    required this.labelWidth,
    required this.topNumberHeight,
    required this.boardWidth,
    required this.fretWidth,
    required this.stringHeight,
    required this.compact,
  });

  /// Width of the left column holding string numbers.
  final double labelWidth;

  /// Height of the top band holding fret numbers.
  final double topNumberHeight;

  /// Width of the board area to the right of the string labels.
  final double boardWidth;

  /// Width of one fret cell.
  final double fretWidth;

  /// Height of one string row.
  final double stringHeight;

  /// True when the board is dense enough that per-fret labels must be
  /// trimmed (fret numbers at inlays only, note names on root/active only).
  final bool compact;
}

/// Computes the fitted fretboard layout for the given canvas [size].
///
/// Formula (from the plan):
///   labelWidth      = (width * 0.045).clamp(24, 40)
///   topNumberHeight = (height * 0.12).clamp(14, 24)
///   boardWidth      = width - labelWidth
///   fretWidth       = (boardWidth - fretGap * 23) / 24
///   stringHeight    = min((height - topNumberHeight) / stringCount,
///                         maxStringHeight)
///   compact         = fretWidth < 22
///
/// [minFretWidth] lets the caller zoom the board (wider cells, horizontal
/// panning) instead of always fitting all 24 frets into the viewport.
/// [maxStringHeight] caps the per-string row height so the board reads as
/// a compact, wide strip instead of filling the whole pane vertically.
FretboardLayout computeFretboardLayout(
  Size size,
  int stringCount, {
  double minFretWidth = 0,
  double maxStringHeight = double.infinity,
}) {
  final labelWidth = (size.width * 0.045).clamp(24.0, 40.0);
  final topNumberHeight = (size.height * 0.12).clamp(14.0, 24.0);
  final boardWidth = size.width - labelWidth;
  final naturalFretWidth =
      (boardWidth - fretboardFretGap * (fretCount - 1)) / fretCount;
  final fretWidth = naturalFretWidth < minFretWidth
      ? minFretWidth
      : naturalFretWidth;
  final naturalStringHeight = (size.height - topNumberHeight) / stringCount;
  final stringHeight = naturalStringHeight < maxStringHeight
      ? naturalStringHeight
      : maxStringHeight;
  return FretboardLayout(
    labelWidth: labelWidth,
    topNumberHeight: topNumberHeight,
    boardWidth: boardWidth,
    fretWidth: fretWidth,
    stringHeight: stringHeight,
    compact: fretWidth < 22,
  );
}

/// Paints a 24-fret guitar fretboard fitted exactly to its canvas:
/// no horizontal scrolling is ever needed, dense ("compact") boards hide
/// non-essential labels automatically.
///
/// Visual direction mirrors the legacy React app (black panels, monospace,
/// white-on-dark note dots).
class FretboardPainter extends CustomPainter {
  FretboardPainter({
    required List<SweepNote> pattern,
    required this.rootPc,
    required this.stringCount,
    required this.position,
    required this.activeStep,
    required this.showNoteNames,
    this.fretOffset = 0,
    this.minFretWidth = 0,
    this.firstVisibleFret = fretMin,
    this.lastVisibleFret = fretMax,
  }) : _cellIndices = _indexNotes(pattern);

  /// Maps (string number, fret) -> pattern indices playing that note.
  static Map<(int, int), List<int>> _indexNotes(List<SweepNote> pattern) {
    final result = <(int, int), List<int>>{};
    for (var i = 0; i < pattern.length; i++) {
      final note = pattern[i];
      result.putIfAbsent((note.string.number, note.fret), () => <int>[]).add(i);
    }
    return result;
  }

  final Map<(int, int), List<int>> _cellIndices;
  final int rootPc;
  final int stringCount;
  final int position;
  final int? activeStep;
  final bool showNoteNames;

  /// Horizontal viewport offset in fret units (may be fractional for
  /// smooth dragging). 0 shows the board from fret 1; positive values shift
  /// the viewport toward higher frets.
  final double fretOffset;

  /// Minimum fret-cell width (logical px) — must match the value used by
  /// [FretboardView] so the painted geometry agrees with the pan/zoom math.
  final double minFretWidth;

  /// Fret range the viewport shows (inclusive); cells outside it are not
  /// painted at all, so no slivers or out-of-viewport rects exist.
  final int firstVisibleFret;
  final int lastVisibleFret;

  static const _cellBackground = Color(0xFF090909);
  static const _cellBorder = Color(0xFF2A2A2A);
  static const _inlayBorder = Color(0xFF3A3A3A);
  static const _patternBorder = Color(0xFF5A5A5A);
  static const _fretNumberColor = Color(0xFF636363);
  static const _stringLabelColor = Color(0xFFA1A1AA);
  static const _dotColor = Color(0xFFE5E7EB);
  static const _dotNameBackground = Color(0xFFFAFAFA);
  static const _dotNameText = Color(0xFF050505);

  @override
  void paint(Canvas canvas, Size size) {
    final layout = computeFretboardLayout(
      size,
      stringCount,
      minFretWidth: minFretWidth,
      maxStringHeight: kMaxStringHeight,
    );

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF000000),
    );

    // Vertically center the compact board strip in the pane.
    final contentHeight =
        layout.topNumberHeight + layout.stringHeight * stringCount;
    final yOffset = math.max(0.0, (size.height - contentHeight) / 2);
    canvas.save();
    canvas.translate(0, yOffset);
    _paintCells(layout, canvas, size);
    _paintFretNumbers(layout, canvas);
    _paintStringLabels(layout, canvas);
    _paintNoteDots(layout, canvas, size);
    canvas.restore();
  }

  Rect _cellRect(FretboardLayout layout, int stringNumber, int fret) {
    final col = fret - fretMin - fretOffset;
    final row = stringNumber - 1;
    return Rect.fromLTWH(
      layout.labelWidth + col * (layout.fretWidth + fretboardFretGap),
      layout.topNumberHeight + row * layout.stringHeight,
      layout.fretWidth,
      layout.stringHeight,
    );
  }

  void _paintCells(FretboardLayout layout, Canvas canvas, Size size) {
    final fill = Paint()..style = PaintingStyle.fill;
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var stringNumber = 1; stringNumber <= stringCount; stringNumber++) {
      for (var fret = firstVisibleFret; fret <= lastVisibleFret; fret++) {
        final rect = _cellRect(layout, stringNumber, fret);
        // Keep cells inside the viewport: negative-x rects can trip the
        // rasterizer on some devices (observed on Samsung with Skia).
        if (rect.right < 0 || rect.left > size.width) continue;
        final indices = _cellIndices[(stringNumber, fret)];
        final isActive = indices != null && indices.contains(activeStep);

        fill.color = _cellBackground;
        canvas.drawRect(rect, fill);

        border.color = isActive
            ? Colors.white
            : indices != null
            ? _patternBorder
            : inlayFrets.contains(fret)
            ? _inlayBorder
            : _cellBorder;
        canvas.drawRect(rect.deflate(0.5), border);

        if (fret == position) {
          canvas.drawRect(
            Rect.fromLTWH(rect.left, rect.bottom - 2, rect.width, 2),
            Paint()..color = Colors.white,
          );
        }
      }
    }
  }

  void _paintFretNumbers(FretboardLayout layout, Canvas canvas) {
    for (var fret = firstVisibleFret; fret <= lastVisibleFret; fret++) {
      final col = fret - fretMin - fretOffset;
      // Zoomed mode shows every fret number (integer fretOffset keeps them
      // aligned with their cells); only the dense compact layout trims to
      // inlay frets.
      if (layout.compact && !inlayFrets.contains(fret)) continue;
      final center = Offset(
        layout.labelWidth +
            col * (layout.fretWidth + fretboardFretGap) +
            layout.fretWidth / 2,
        layout.topNumberHeight / 2,
      );
      _paintText(
        canvas,
        '$fret',
        center,
        fontSize: layout.compact ? 8 : 10,
        color: _fretNumberColor,
      );
    }
  }

  void _paintStringLabels(FretboardLayout layout, Canvas canvas) {
    for (var stringNumber = 1; stringNumber <= stringCount; stringNumber++) {
      final center = Offset(
        layout.labelWidth / 2,
        layout.topNumberHeight +
            (stringNumber - 1) * layout.stringHeight +
            layout.stringHeight / 2,
      );
      _paintText(
        canvas,
        '$stringNumber',
        center,
        fontSize: 10,
        color: _stringLabelColor,
      );
    }
  }

  void _paintNoteDots(FretboardLayout layout, Canvas canvas, Size size) {
    for (final entry in _cellIndices.entries) {
      final (stringNumber, fret) = entry.key;
      if (stringNumber > stringCount) continue;
      final indices = entry.value;
      final isActive = indices.contains(activeStep);
      final isRoot = _isRoot(stringNumber, fret);
      if (fret < firstVisibleFret || fret > lastVisibleFret) continue;
      final rect = _cellRect(layout, stringNumber, fret);
      if (rect.right < 0 || rect.left > size.width) continue;
      final center = rect.center;

      final showName = showNoteNames && (!layout.compact || isRoot || isActive);

      if (showName) {
        final dotSize =
            (layout.fretWidth < layout.stringHeight
                    ? layout.fretWidth
                    : layout.stringHeight)
                .clamp(14.0, 20.0);
        final square = Rect.fromCenter(
          center: center,
          width: dotSize,
          height: dotSize,
        );
        final rounded = RRect.fromRectAndRadius(
          square,
          const Radius.circular(2),
        );

        if (isRoot) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              square.inflate(7),
              const Radius.circular(5),
            ),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.35)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
          );
        }

        canvas.drawRRect(
          rounded,
          Paint()
            ..color = isActive || isRoot ? Colors.white : _dotNameBackground,
        );

        _paintText(
          canvas,
          noteNameAt(GuitarString.fromNumber(stringNumber), fret),
          center,
          fontSize: (dotSize * 0.5).clamp(8.0, 11.0),
          color: _dotNameText,
          fontWeight: isRoot || isActive ? FontWeight.w700 : FontWeight.w400,
        );
      } else {
        final radius = isActive ? 5.5 : (layout.compact ? 3.0 : 3.5);
        if (isRoot) {
          canvas.drawCircle(
            center,
            radius * 3,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.30)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
        }
        canvas.drawCircle(
          center,
          radius,
          Paint()..color = isActive || isRoot ? Colors.white : _dotColor,
        );
      }
    }
  }

  bool _isRoot(int stringNumber, int fret) {
    return (GuitarString.fromNumber(stringNumber).openMidi + fret) % 12 ==
        rootPc;
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset center, {
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: fontSize,
          color: color,
          fontWeight: fontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(FretboardPainter oldDelegate) {
    return oldDelegate._cellIndices != _cellIndices ||
        oldDelegate.rootPc != rootPc ||
        oldDelegate.stringCount != stringCount ||
        oldDelegate.position != position ||
        oldDelegate.activeStep != activeStep ||
        oldDelegate.showNoteNames != showNoteNames ||
        oldDelegate.fretOffset != fretOffset ||
        oldDelegate.minFretWidth != minFretWidth;
  }
}
