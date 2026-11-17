import 'dart:async';

import 'package:flutter/widgets.dart';

import '../audio/trainer_playback_service.dart';

/// Stops audio when the app leaves the foreground.
///
/// - `paused` / `inactive`: stop playback immediately (audio must never
///   keep sounding behind the lock screen or an incoming call).
/// - `detached`: same treatment; the engine is left for the screen's own
///   dispose path.
/// - `resumed`: nothing is restarted automatically — the user taps START
///   again, matching the React trainer's explicit-start behavior.
class AppLifecycleAudioGuard with WidgetsBindingObserver {
  AppLifecycleAudioGuard(this.playbackService);

  final TrainerPlaybackService playbackService;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(playbackService.stop());
    }
  }
}
