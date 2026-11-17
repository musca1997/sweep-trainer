import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/guitar_sweep_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Landscape-only: the trainer is built for landscape, so the app locks
  // to landscape from the very first frame (no rotate prompt needed).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const GuitarSweepApp());
}
