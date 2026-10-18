import 'package:flutter_test/flutter_test.dart';
import 'package:turkce_sarkilar/synth.dart';

void main() {
  test('every track renders a valid, non-silent WAV of the right length', () {
    for (final t in tracks) {
      final wav = renderWav(t);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      final seconds = (wav.length - 44) / 2 / sampleRate;
      expect(seconds, closeTo(t.duration.inMilliseconds / 1000, .05));
      final samples = render(t);
      expect(samples.reduce((a, b) => a.abs() > b.abs() ? a : b).abs(), greaterThan(.5));
    }
  });
}
