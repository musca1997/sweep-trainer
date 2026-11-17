/// Generates short mono 16-bit PCM WAV bytes in memory so no binary audio
/// assets need to be committed to the repo. The returned buffers are valid
/// WAV files and can be loaded directly by flutter_soloud via `loadMem`.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// Sample rate used for all generated sounds.
const int generatedWavSampleRate = 44100;

/// Builds a complete mono 16-bit PCM WAV file from floating point samples
/// in the range -1.0..1.0.
Uint8List _wavBytes(List<double> samples, int sampleRate) {
  final dataSize = samples.length * 2;
  final bytes = ByteData(44 + dataSize);

  void writeAscii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      bytes.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  writeAscii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataSize, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little); // fmt chunk size
  bytes.setUint16(20, 1, Endian.little); // audio format: PCM
  bytes.setUint16(22, 1, Endian.little); // channels: mono
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  bytes.setUint16(32, 2, Endian.little); // block align
  bytes.setUint16(34, 16, Endian.little); // bits per sample
  writeAscii(36, 'data');
  bytes.setUint32(40, dataSize, Endian.little);

  for (var i = 0; i < samples.length; i++) {
    final clamped = samples[i].clamp(-1.0, 1.0);
    bytes.setInt16(44 + i * 2, (clamped * 32767).round(), Endian.little);
  }
  return bytes.buffer.asUint8List();
}

/// Generates a short metronome click: a high sine burst with a fast
/// exponential decay (~30 ms).
Uint8List generateClickWav({
  double frequency = 1800,
  int sampleRate = generatedWavSampleRate,
}) {
  const durationMs = 30.0;
  final count = (sampleRate * durationMs / 1000).round();
  final samples = List<double>.generate(count, (i) {
    final t = i / sampleRate;
    final envelope = math.exp(-t * 250); // ~-55 dB by the end
    return math.sin(2 * math.pi * frequency * t) * envelope;
  });
  return _wavBytes(samples, sampleRate);
}

/// Generates a short plucked-string sound (~150 ms) at [frequency]:
/// a 1.5 ms linear attack followed by an exponential decay, built from a
/// saw-like blend of harmonics.
Uint8List generatePluckWav({
  double frequency = 440,
  int sampleRate = generatedWavSampleRate,
}) {
  const durationMs = 150.0;
  const attackMs = 1.5;
  final count = (sampleRate * durationMs / 1000).round();
  final attackSamples = (sampleRate * attackMs / 1000).round();
  const harmonicSum = 1.0 + 0.5 + 0.25 + 0.125;
  final samples = List<double>.generate(count, (i) {
    final t = i / sampleRate;
    final attack = i < attackSamples ? i / attackSamples : 1.0;
    final envelope = attack * math.exp(-t * 28); // ~-36 dB by the end
    final wave =
        math.sin(2 * math.pi * frequency * t) +
        0.5 * math.sin(2 * math.pi * 2 * frequency * t) +
        0.25 * math.sin(2 * math.pi * 3 * frequency * t) +
        0.125 * math.sin(2 * math.pi * 4 * frequency * t);
    return wave / harmonicSum * envelope;
  });
  return _wavBytes(samples, sampleRate);
}
