import 'package:flutter/material.dart';

import '../../app/trainer_controller.dart';
import 'trainer_controls.dart';

/// Draggable bottom sheet with all trainer settings, used on compact
/// landscape screens (width < 850) where a permanent control column does
/// not fit next to the fretboard. START/STOP stays in the status bar.
class CompactSettingsSheet extends StatelessWidget {
  const CompactSettingsSheet({super.key, required this.controller});

  final TrainerController controller;

  /// Opens the sheet from [context].
  static Future<void> show(
    BuildContext context, {
    required TrainerController controller,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B0B0B),
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => CompactSettingsSheet(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 82% of the screen height keeps the sheet fully usable while leaving
    // a sliver of the fretboard visible behind it.
    final height = MediaQuery.sizeOf(context).height * 0.82;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A3A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'SETTINGS',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 2,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: TrainerControls(controller: controller, compact: true),
            ),
          ],
        ),
      ),
    );
  }
}
