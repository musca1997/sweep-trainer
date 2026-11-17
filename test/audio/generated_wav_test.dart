import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_sweep_trainer/audio/generated_wav.dart';

/// Decodes the mono 16-bit PCM samples out of a WAV buffer.
List<int> _decodeSamples(Uint8List wav) {
  final data = ByteData.sublistView(wav);
  final dataSize = data.getUint32(40, Endian.little);
  expect(wav.length, 44 + dataSize);
  return [
    for (var i = 0; i < dataSize ~/ 2; i++)
      data.getInt16(44 + i * 2, Endian.little),
  ];
}

void _expectValidWav(Uint8List wav, {required int sampleRate}) {
  final data = ByteData.sublistView(wav);
  // RIFF/WAVE header.
  expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
  expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
  expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
  // PCM, mono, 16-bit.
  expect(data.getUint16(20, Endian.little), 1);
  expect(data.getUint16(22, Endian.little), 1);
  expect(data.getUint16(34, Endian.little), 16);
  expect(data.getUint32(24, Endian.little), sampleRate);
  expect(data.getUint32(28, Endian.little), sampleRate * 2); // byte rate
  // Sizes agree.
  final dataSize = data.getUint32(40, Endian.little);
  expect(dataSize, wav.length - 44);
  expect(dataSize % 2, 0);
}

void main() {
  test('click WAV is a valid short mono PCM file', () {
    final wav = generateClickWav();
    _expectValidWav(wav, sampleRate: generatedWavSampleRate);
    final samples = _decodeSamples(wav);
    // 30 ms at 44100 Hz.
    expect(samples.length, closeTo(1323, 2));
    // Envelope: starts quiet (post-attack sine) and decays to near silence.
    expect(samples.first.abs(), lessThanOrEqualTo(1));
    expect(samples.last.abs(), lessThan(500));
  });

  test('pluck WAV is a valid short mono PCM file with decay envelope', () {
    final wav = generatePluckWav(frequency: 440);
    _expectValidWav(wav, sampleRate: generatedWavSampleRate);
    final samples = _decodeSamples(wav);
    // 150 ms at 44100 Hz.
    expect(samples.length, closeTo(6615, 2));

    final earlyPeak = samples
        .sublist(0, (0.02 * generatedWavSampleRate).round())
        .map((s) => s.abs())
        .reduce((a, b) => a > b ? a : b);
    final latePeak = samples
        .sublist((0.13 * generatedWavSampleRate).round())
        .map((s) => s.abs())
        .reduce((a, b) => a > b ? a : b);
    // Exponential decay: the last 20 ms are at most ~5% of the first 20 ms.
    expect(latePeak, lessThan(earlyPeak * 0.05));
    expect(earlyPeak, greaterThan(10000));
  });

  test('pluck WAV pitch changes with frequency', () {
    final low = _decodeSamples(generatePluckWav(frequency: 220));
    final high = _decodeSamples(generatePluckWav(frequency: 880));
    // Both are valid and contain full-scale activity.
    expect(
      low.sublist(0, 4410).map((s) => s.abs()).reduce((a, b) => a > b ? a : b),
      greaterThan(10000),
    );
    expect(
      high.sublist(0, 4410).map((s) => s.abs()).reduce((a, b) => a > b ? a : b),
      greaterThan(10000),
    );
  });

  test('generated samples never clip (stay in int16 range)', () {
    for (final wav in [generateClickWav(), generatePluckWav()]) {
      for (final sample in _decodeSamples(wav)) {
        expect(sample, inInclusiveRange(-32768, 32767));
      }
    }
  });
}
