import 'package:flutter/material.dart';

import '../app/app_lifecycle_audio_guard.dart';
import '../app/trainer_controller.dart';
import '../audio/audio_engine.dart';
import '../audio/soloud_audio_engine.dart';
import '../audio/trainer_playback_service.dart';
import 'controls/compact_settings_sheet.dart';
import 'controls/trainer_controls.dart';
import 'fretboard/fretboard_view.dart';

/// Threshold above which a permanent control column is shown next to the
/// fretboard; below it a settings sheet is used instead.
const double kWideLayoutWidth = 850;

/// Main trainer screen: portrait shows a rotate prompt, landscape shows the
/// full trainer (fretboard + controls + status bar).
///
/// [engine] is injectable so widget tests can use a fake audio engine;
/// production uses [SoLoudAudioEngine].
class TrainerScreen extends StatefulWidget {
  const TrainerScreen({super.key, this.engine});

  final AudioEngine? engine;

  @override
  State<TrainerScreen> createState() => _TrainerScreenState();
}

class _TrainerScreenState extends State<TrainerScreen> {
  late final TrainerController _controller;
  late final TrainerPlaybackService _playback;
  late final AppLifecycleAudioGuard _lifecycleGuard;

  @override
  void initState() {
    super.initState();
    _controller = TrainerController();
    _playback = TrainerPlaybackService(
      controller: _controller,
      engine: widget.engine ?? SoLoudAudioEngine(),
    );
    _lifecycleGuard = AppLifecycleAudioGuard(_playback);
    WidgetsBinding.instance.addObserver(_lifecycleGuard);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleGuard);
    _playback.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_controller.isRunning) {
      await _playback.stop();
    } else {
      await _playback.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Landscape-only app (see main.dart): always render the full trainer.
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => _buildLandscape(context),
      ),
    );
  }

  Widget _buildLandscape(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= kWideLayoutWidth;

    return SafeArea(
      child: Column(
        children: [
          _buildStatusBar(context, wide),
          Expanded(
            child: wide ? _buildWideBody(context) : _buildCompactBody(context),
          ),
        ],
      ),
    );
  }

  // ── Status bar ────────────────────────────────────────────────────────

  Widget _buildStatusBar(BuildContext context, bool wide) {
    final c = _controller;
    final noPattern = c.pattern.isEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1F1F1F))),
      ),
      child: Listener(
        child: Row(
          children: [
            const Text(
              'SWEEP.TRAINER',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: Color(0xFFF3F4F6),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                '${c.root} ${c.quality.label} | Pos ${c.position} | '
                'Strings 1-${c.sweepLowString.number} | ${c.bpm} BPM'
                '${c.autoRampOn ? ' | RAMP→${c.targetBpm}' : ''}'
                '${noPattern ? ' | NO PATTERN' : ''}'
                '${wide ? '' : ' | Rounds ${c.completedRounds}'}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
            ),
            if (wide) ...[
              const SizedBox(width: 8),
              Text(
                'Rounds ${c.completedRounds}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF3F4F6),
                ),
              ),
              const SizedBox(width: 10),
            ],
            if (!wide) ...[
              OutlinedButton(
                key: const Key('settings-button'),
                onPressed: () => _openSettings(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF3F4F6),
                  side: const BorderSide(color: Color(0xFF3A3A3A)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 32),
                  textStyle: const TextStyle(
                    fontSize: 11,

                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('SETTINGS'),
              ),
              const SizedBox(width: 8),
            ],
            _compactStartStop(),
            const SizedBox(width: 8),
            _rollDiceButton(),
          ],
        ),
      ),
    );
  }

  /// START/STOP button in the status bar, always visible without
  /// scrolling (both layouts).
  Widget _compactStartStop() {
    final running = _controller.isRunning;
    return FilledButton(
      key: const Key('start-stop-button'),
      onPressed: _togglePlayback,
      style: FilledButton.styleFrom(
        backgroundColor: running
            ? const Color(0xFF8B1E1E)
            : const Color(0xFFE5E7EB),
        foregroundColor: running
            ? const Color(0xFFF3F4F6)
            : const Color(0xFF050505),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        minimumSize: const Size(0, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
      child: Text(running ? 'STOP' : 'START'),
    );
  }

  /// ROLL button: randomizes root + quality + position.
  Widget _rollDiceButton() {
    return FilledButton.tonal(
      key: const Key('roll-dice-button'),
      onPressed: () {
        _controller.randomize();
      },
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF232323),
        foregroundColor: const Color(0xFFF3F4F6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: const Size(0, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.casino, size: 13),
          SizedBox(width: 4),
          Text('ROLL'),
        ],
      ),
    );
  }

  // ── Wide layout: controls column + fretboard ──────────────────────────

  Widget _buildWideBody(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 250,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: Color(0xFF1F1F1F))),
          ),
          child: TrainerControls(controller: _controller),
        ),
        Expanded(child: _buildFretboardPane(context)),
      ],
    );
  }

  // ── Compact layout: fretboard + quick controls ────────────────────────

  Widget _buildCompactBody(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _buildFretboardPane(context)),
        _buildQuickControls(),
      ],
    );
  }

  Widget _buildFretboardPane(BuildContext context) {
    final c = _controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: FretboardView(
              pattern: c.pattern,
              rootPc: c.rootPc,
              visibleLowString: c.sweepLowString,
              position: c.position,
              activeStep: c.activeStep,
              showNoteNames: c.showNoteNames,
            ),
          ),
          if (c.pattern.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'No playable pattern found for this position.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ),
        ],
      ),
    );
  }

  /// Quick BPM row shown under the fretboard in compact layout.
  Widget _buildQuickControls() {
    final c = _controller;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF1F1F1F))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton(
            key: const Key('bpm-minus'),
            onPressed: () => c.bpm = c.bpm - 5,
            style: _quickButtonStyle(),
            child: const Text('-5 BPM'),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            key: const Key('bpm-plus'),
            onPressed: () => c.bpm = c.bpm + 5,
            style: _quickButtonStyle(),
            child: const Text('+5 BPM'),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            key: const Key('pos-minus'),
            onPressed: () => c.setPosition(c.position - 1),
            style: _quickButtonStyle(),
            child: const Text('POS -'),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            key: const Key('pos-plus'),
            onPressed: () => c.setPosition(c.position + 1),
            style: _quickButtonStyle(),
            child: const Text('POS +'),
          ),
        ],
      ),
    );
  }

  ButtonStyle _quickButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFFF3F4F6),
      side: const BorderSide(color: Color(0xFF3A3A3A)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      minimumSize: const Size(0, 30),
      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    );
  }

  Future<void> _openSettings(BuildContext context) {
    return CompactSettingsSheet.show(context, controller: _controller);
  }
}
