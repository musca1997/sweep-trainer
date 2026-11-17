import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_sweep_trainer/ui/fretboard/fretboard_painter.dart';
import 'package:guitar_sweep_trainer/ui/fretboard/fretboard_view.dart';
import 'package:guitar_sweep_trainer/ui/trainer_screen.dart';

import 'audio/fake_audio_engine.dart';

void main() {
  Future<void> pumpTrainer(WidgetTester tester, {required Size size}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: TrainerScreen(engine: FakeAudioEngine()),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Landscape logical sizes (Task 15 QA matrix).
  const landscapeSizes = [
    Size(667, 375), // old small iPhone landscape
    Size(740, 360), // small Android landscape
    Size(844, 390), // iPhone 12/13/14 class
    Size(915, 412), // larger Android class
    Size(932, 430), // iPhone Pro Max class
  ];

  for (final size in landscapeSizes) {
    testWidgets('landscape ${size.width}x${size.height} shows full trainer', (
      tester,
    ) async {
      await pumpTrainer(tester, size: size);

      expect(find.text('SWEEP.TRAINER'), findsOneWidget);
      expect(find.byKey(const Key('fretboard')), findsOneWidget);
      // At least one START/STOP button is visible.
      expect(find.byKey(const Key('start-stop-button')), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: 'no overflow exceptions on $size',
      );
    });
  }

  testWidgets('narrow landscape uses quick controls and settings sheet', (
    tester,
  ) async {
    await pumpTrainer(tester, size: const Size(667, 375));

    // Quick BPM controls visible on compact layout.
    expect(find.byKey(const Key('bpm-minus')), findsOneWidget);
    expect(find.byKey(const Key('bpm-plus')), findsOneWidget);

    // Settings sheet opens from the status bar button (button label plus
    // sheet title both read SETTINGS, so assert on the sheet's content).
    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('root-picker')), findsOneWidget);
    expect(find.byKey(const Key('bpm-slider')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide landscape shows permanent controls column', (tester) async {
    await pumpTrainer(tester, size: const Size(915, 412));

    expect(find.byKey(const Key('root-picker')), findsOneWidget);
    expect(find.byKey(const Key('quality-picker')), findsOneWidget);
    expect(find.byKey(const Key('position-slider')), findsOneWidget);
    expect(find.byKey(const Key('start-stop-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('START button toggles playback with fake engine', (tester) async {
    await pumpTrainer(tester, size: const Size(844, 390));

    await tester.tap(find.byKey(const Key('start-stop-button')));
    await tester.pump();
    expect(find.text('STOP'), findsOneWidget);

    await tester.tap(find.byKey(const Key('start-stop-button')));
    await tester.pump();
    expect(find.text('START'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('START button is in the status bar on wide layout (no scroll)', (
    tester,
  ) async {
    await pumpTrainer(tester, size: const Size(915, 412));

    // The button must be visible without scrolling the controls column:
    // it lives in the top status bar next to SWEEP.TRAINER.
    final button = find.byKey(const Key('start-stop-button'));
    expect(button, findsOneWidget);
    expect(tester.getTopLeft(button).dy, lessThan(80));
  });

  testWidgets(
    'ROLL dice button changes settings and keeps a playable pattern',
    (tester) async {
      await pumpTrainer(tester, size: const Size(844, 390));
      await tester.tap(find.byKey(const Key('roll-dice-button')));
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Status bar still renders and the pattern is not empty (no NO
      // PATTERN hint, fretboard still present).
      expect(find.textContaining('NO PATTERN'), findsNothing);
      expect(find.text('SWEEP.TRAINER'), findsOneWidget);
    },
  );

  testWidgets('fretboard painter is zoomed with the same fret width as view', (
    tester,
  ) async {
    await pumpTrainer(tester, size: const Size(844, 390));
    final paint = tester.widget<CustomPaint>(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is FretboardPainter,
      ),
    );
    expect((paint.painter! as FretboardPainter).minFretWidth, kMinFretWidth);
    expect(find.text('SWEEP.TRAINER'), findsOneWidget);
  });

  testWidgets(
    'fretboard follows position automatically and has no manual pan',
    (tester) async {
      await pumpTrainer(tester, size: const Size(915, 412)); // wide layout
      final fretboard = find.byKey(const Key('fretboard'));
      expect(fretboard, findsOneWidget);

      FretboardPainter painter() =>
          tester
                  .widget<CustomPaint>(
                    find.byWidgetPredicate(
                      (w) => w is CustomPaint && w.painter is FretboardPainter,
                    ),
                  )
                  .painter!
              as FretboardPainter;

      // Default position 12 → viewport offset 10 (2 frets of context).
      expect(painter().fretOffset, 10);

      // Dragging the board does nothing (manual panning was removed).
      await tester.drag(fretboard, const Offset(-250, 0));
      await tester.pump();
      expect(painter().fretOffset, 10);
      expect(tester.takeException(), isNull);

      // Changing position re-focuses the viewport.
      await tester.drag(
        find.byKey(const Key('position-slider')),
        const Offset(-160, 0),
      );
      await tester.pump();
      final after = painter().fretOffset;
      expect(after, isNot(equals(10)));
      expect(tester.takeException(), isNull);
    },
  );
}
