import 'package:flutter/material.dart';

import '../../app/subdivision.dart';
import '../../app/trainer_controller.dart';
import '../../domain/music.dart';

/// All trainer settings controls, rendered as a compact column of labeled
/// rows. Used both as the left-hand panel on wide landscape screens and
/// inside the settings bottom sheet on compact landscape screens. The
/// START/STOP button lives in the status bar (see `TrainerScreen`), so it
/// never requires scrolling.
class TrainerControls extends StatelessWidget {
  const TrainerControls({
    super.key,
    required this.controller,
    this.compact = false,
  });

  final TrainerController controller;

  /// When true, rows are squeezed to fit the bottom sheet (smaller
  /// vertical padding, smaller sliders).
  final bool compact;

  static const _labelStyle = TextStyle(
    fontSize: 10,
    letterSpacing: 0.8,
    fontFamily: 'JetBrainsMono',
    color: Color(0xFF9CA3AF),
  );
  static const _valueStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    fontFamily: 'JetBrainsMono',
    color: Color(0xFFF3F4F6),
  );
  static const _selectStyle = TextStyle(
    fontSize: 13,
    fontFamily: 'JetBrainsMono',
    color: Color(0xFFF3F4F6),
  );

  @override
  Widget build(BuildContext context) {
    final vPad = compact ? 2.0 : 6.0;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row('ROOT', _rootPicker(), vPad: vPad),
          _row('CHORD QUALITY', _qualityPicker(), vPad: vPad),
          _row(
            'POSITION ${controller.position}',
            _positionSlider(),
            vPad: vPad,
          ),
          _row('PRACTICE MODE', _modePicker(), vPad: vPad),
          _row('SWEEP STRINGS', _stringsPicker(), vPad: vPad),
          _row('BPM ${controller.bpm}', _bpmControls(), vPad: vPad),
          _row('SUBDIVISION', _subdivisionPicker(), vPad: vPad),
          _row(
            'TARGET BPM ${controller.targetBpm}',
            _targetBpmSlider(),
            vPad: vPad,
          ),
          _row(
            '+BPM PER STEP ${controller.rampStep}',
            _rampStepSlider(),
            vPad: vPad,
          ),
          _row(
            'ROUNDS PER STEP ${controller.rampEveryRounds}',
            _rampRoundsSlider(),
            vPad: vPad,
          ),
          _switchRow(
            'Metronome',
            controller.metronomeOn,
            (v) => controller.metronomeOn = v,
          ),
          _switchRow(
            'Auto Ramp',
            controller.autoRampOn,
            (v) => controller.autoRampOn = v,
          ),
          _switchRow(
            'Show Note Names',
            controller.showNoteNames,
            (v) => controller.showNoteNames = v,
          ),
        ],
      ),
    );
  }

  Widget _row(String label, Widget child, {required double vPad}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: vPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _labelStyle),
          const SizedBox(height: 2),
          child,
        ],
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: _valueStyle),
      value: value,
      onChanged: onChanged,
      activeTrackColor: const Color(0xFFE5E7EB),
      activeThumbColor: const Color(0xFF050505),
      inactiveTrackColor: const Color(0xFF2A2A2A),
      inactiveThumbColor: const Color(0xFF9CA3AF),
    );
  }

  Widget _rootPicker() {
    return DropdownButton<String>(
      key: const Key('root-picker'),
      value: controller.root,
      isExpanded: true,
      dropdownColor: const Color(0xFF111111),
      style: _selectStyle,
      items: [
        for (final n in noteNames) DropdownMenuItem(value: n, child: Text(n)),
      ],
      onChanged: (v) {
        if (v != null) controller.setRoot(v);
      },
    );
  }

  Widget _qualityPicker() {
    return DropdownButton<ChordQuality>(
      key: const Key('quality-picker'),
      value: controller.quality,
      isExpanded: true,
      dropdownColor: const Color(0xFF111111),
      style: _selectStyle,
      items: [
        for (final q in ChordQuality.values)
          DropdownMenuItem(value: q, child: Text(q.label)),
      ],
      onChanged: (v) {
        if (v != null) controller.quality = v;
      },
    );
  }

  Widget _positionSlider() {
    return Slider(
      key: const Key('position-slider'),
      min: TrainerController.positionMin.toDouble(),
      max: TrainerController.positionMax.toDouble(),
      divisions: TrainerController.positionMax - TrainerController.positionMin,
      value: controller.position.toDouble(),
      label: '${controller.position}',
      onChanged: (v) => controller.setPosition(v.round()),
    );
  }

  Widget _modePicker() {
    return DropdownButton<PracticeMode>(
      key: const Key('mode-picker'),
      value: controller.mode,
      isExpanded: true,
      dropdownColor: const Color(0xFF111111),
      style: _selectStyle,
      items: [
        for (final m in PracticeMode.values)
          DropdownMenuItem(value: m, child: Text(m.label)),
      ],
      onChanged: (v) {
        if (v != null) controller.mode = v;
      },
    );
  }

  Widget _stringsPicker() {
    return DropdownButton<GuitarString>(
      key: const Key('strings-picker'),
      value: controller.sweepLowString,
      isExpanded: true,
      dropdownColor: const Color(0xFF111111),
      style: _selectStyle,
      items: [
        for (final s in GuitarString.values.skip(1))
          DropdownMenuItem(value: s, child: Text('Strings 1-${s.number}')),
      ],
      onChanged: (v) {
        if (v != null) controller.sweepLowString = v;
      },
    );
  }

  Widget _bpmControls() {
    return Row(
      children: [
        Expanded(
          child: Slider(
            key: const Key('bpm-slider'),
            min: TrainerController.bpmMin.toDouble(),
            max: TrainerController.bpmMax.toDouble(),
            divisions: TrainerController.bpmMax - TrainerController.bpmMin,
            value: controller.bpm.toDouble(),
            label: '${controller.bpm}',
            onChanged: (v) => controller.bpm = v.round(),
          ),
        ),
        _bpmButton('-5', () => controller.bpm = controller.bpm - 5),
        _bpmButton('+5', () => controller.bpm = controller.bpm + 5),
      ],
    );
  }

  Widget _bpmButton(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFF3F4F6),
          side: const BorderSide(color: Color(0xFF3A3A3A)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          minimumSize: const Size(44, 30),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _subdivisionPicker() {
    return DropdownButton<Subdivision>(
      key: const Key('subdivision-picker'),
      value: controller.subdivision,
      isExpanded: true,
      dropdownColor: const Color(0xFF111111),
      style: _selectStyle,
      items: [
        for (final s in Subdivision.values)
          DropdownMenuItem(value: s, child: Text(s.label)),
      ],
      onChanged: (v) {
        if (v != null) controller.subdivision = v;
      },
    );
  }

  Widget _targetBpmSlider() {
    return Slider(
      key: const Key('target-bpm-slider'),
      min: TrainerController.targetBpmMin.toDouble(),
      max: TrainerController.targetBpmMax.toDouble(),
      divisions:
          (TrainerController.targetBpmMax - TrainerController.targetBpmMin) ~/
          5,
      value: controller.targetBpm.toDouble(),
      label: '${controller.targetBpm}',
      onChanged: (v) => controller.targetBpm = v.round(),
    );
  }

  Widget _rampStepSlider() {
    return Slider(
      key: const Key('ramp-step-slider'),
      min: TrainerController.rampStepMin.toDouble(),
      max: TrainerController.rampStepMax.toDouble(),
      divisions: TrainerController.rampStepMax - TrainerController.rampStepMin,
      value: controller.rampStep.toDouble(),
      label: '${controller.rampStep}',
      onChanged: (v) => controller.rampStep = v.round(),
    );
  }

  Widget _rampRoundsSlider() {
    return Slider(
      key: const Key('ramp-rounds-slider'),
      min: TrainerController.rampEveryRoundsMin.toDouble(),
      max: TrainerController.rampEveryRoundsMax.toDouble(),
      divisions:
          TrainerController.rampEveryRoundsMax -
          TrainerController.rampEveryRoundsMin,
      value: controller.rampEveryRounds.toDouble(),
      label: '${controller.rampEveryRounds}',
      onChanged: (v) => controller.rampEveryRounds = v.round(),
    );
  }
}
