import 'dart:math';
import 'dart:typed_data';

/// Original demo tracks, generated in the app (no recorded songs, no copyright):
/// a plucked-string sound (Karplus–Strong, close to a bağlama/saz) playing a melody in a
/// Turkish makam over a drone, with a darbuka-like "düm / tek" rhythm.
class Makam {
  final String name;
  final double tonic; // Hz
  final List<double> cents; // scale degrees in cents above the tonic (one octave)
  const Makam(this.name, this.tonic, this.cents);
}

class TrackSpec {
  final String title;
  final String mood;
  final Makam makam;
  final int bpm;
  final int seed;
  final int bars;
  final List<int> usul; // 8 steps per bar: 0 rest, 1 düm, 2 tek
  final int color;
  const TrackSpec(this.title, this.mood, this.makam, this.bpm, this.seed, this.bars, this.usul, this.color);
  Duration get duration => Duration(milliseconds: (bars * 4 * 60000 / bpm).round() + 1500);
}

const hicaz = Makam('Hicaz', 146.83, [0, 112, 386, 498, 702, 814, 996, 1200]);
const ussak = Makam('Uşşak', 220.0, [0, 150, 294, 498, 702, 792, 996, 1200]);
const rast = Makam('Rast', 196.0, [0, 204, 355, 498, 702, 906, 1057, 1200]);
const kurdi = Makam('Kürdi', 220.0, [0, 90, 294, 498, 702, 792, 996, 1200]);
const nihavend = Makam('Nihavend', 261.63, [0, 204, 294, 498, 702, 792, 1110, 1200]);
const huseyni = Makam('Hüseyni', 220.0, [0, 150, 294, 498, 702, 906, 996, 1200]);
const saba = Makam('Saba', 220.0, [0, 150, 294, 384, 702, 792, 996, 1200]);
const segah = Makam('Segâh', 246.94, [0, 150, 348, 498, 702, 852, 1002, 1200]);
const hicazkar = Makam('Hicazkâr', 196.0, [0, 112, 386, 498, 702, 814, 1088, 1200]);

const sofyan = [1, 0, 0, 0, 2, 0, 2, 0];
const duyek = [1, 0, 2, 0, 0, 2, 1, 2];
const sofyanFast = [1, 0, 2, 2, 1, 0, 2, 0];
const curcuna = [1, 0, 2, 1, 0, 2, 2, 0];

const tracks = [
  TrackSpec('Hicaz Esintisi', 'Hüzünlü · ağır', hicaz, 78, 11, 16, sofyan, 0xFFD84315),
  TrackSpec('Uşşak Sabahı', 'Sakin · içten', ussak, 92, 23, 16, duyek, 0xFF00897B),
  TrackSpec('Rast Yolu', 'Neşeli · aydınlık', rast, 110, 37, 20, sofyanFast, 0xFF1E88E5),
  TrackSpec('Kürdi Gece', 'Derin · gece', kurdi, 84, 41, 16, sofyan, 0xFF5E35B1),
  TrackSpec('Nihavend Rüzgârı', 'Romantik', nihavend, 96, 53, 16, duyek, 0xFFC2185B),
  TrackSpec('Hüseyni Halay', 'Hareketli · halay', huseyni, 124, 67, 24, curcuna, 0xFF43A047),
  TrackSpec('Saba Yağmuru', 'Hüzünlü · yağmurlu', saba, 72, 71, 14, sofyan, 0xFF546E7A),
  TrackSpec('Segâh Işığı', 'Huzurlu · mistik', segah, 80, 83, 16, duyek, 0xFFF9A825),
  TrackSpec('Hicazkâr Saray', 'Görkemli', hicazkar, 100, 97, 18, sofyanFast, 0xFF6D4C41),
  TrackSpec('Hicaz Oyun Havası', 'Hareketli · düğün', hicaz, 132, 101, 26, curcuna, 0xFFE53935),
  TrackSpec('Uşşak Akşamı', 'Sıcak · akşam', ussak, 86, 113, 16, sofyan, 0xFF00ACC1),
  TrackSpec('Rast Bayramı', 'Neşeli · bayram', rast, 118, 127, 22, duyek, 0xFF3949AB),
];

const sampleRate = 22050;

/// Renders a track to a 16-bit mono WAV file.
Uint8List renderWav(TrackSpec t) {
  final samples = render(t);
  final data = ByteData(44 + samples.length * 2);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, (samples[i].clamp(-1.0, 1.0) * 32000).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

Float32List render(TrackSpec t) {
  final rnd = Random(t.seed);
  final beat = 60 / t.bpm; // seconds per quarter note
  final step = beat / 2; // eighth note
  final total = (t.duration.inMilliseconds / 1000 * sampleRate).round();
  final out = Float32List(total);
  double freq(int degree) {
    final oct = (degree / 7).floor();
    final d = degree - oct * 7;
    return t.makam.tonic * pow(2, oct + t.makam.cents[d] / 1200);
  }

  // Melody: phrases of two bars that wander near the scale and come home to the tonic.
  var pos = 0.0;
  var deg = 4;
  final rhythms = [
    [2, 1, 1, 2, 2],
    [1, 1, 1, 1, 2, 2],
    [3, 1, 2, 2],
    [1, 1, 2, 1, 1, 2],
  ];
  for (var bar = 0; bar < t.bars; bar += 2) {
    final r = rhythms[rnd.nextInt(rhythms.length)];
    final last = bar + 2 >= t.bars;
    for (var k = 0; k < r.length; k++) {
      final isEnd = k == r.length - 1;
      if (isEnd) {
        deg = (last || rnd.nextBool()) ? 0 : 4; // cadence on the tonic or the fifth
      } else {
        deg += [-2, -1, -1, 1, 1, 2][rnd.nextInt(6)];
        deg = deg.clamp(-1, 9);
      }
      final len = r[k] * step;
      _pluck(out, (pos * sampleRate).round(), freq(deg) * 2, len + .6, .55);
      // ornament (çarpma): a quick grace note before some long notes
      if (r[k] >= 2 && rnd.nextDouble() < .35) _pluck(out, ((pos - .06) * sampleRate).round(), freq(deg + 1) * 2, .12, .25);
      pos += len;
    }
    // remaining time of the two bars
    final used = r.fold(0, (a, b) => a + b) * step;
    pos += 8 * step - used;
  }

  // Drone: tonic + fifth, one pluck per bar.
  for (var bar = 0; bar < t.bars; bar++) {
    final s = (bar * 4 * beat * sampleRate).round();
    _pluck(out, s, t.makam.tonic / 2, 4 * beat + .5, .28);
    _pluck(out, s + (beat * sampleRate).round(), t.makam.tonic * 0.75, 2 * beat, .14);
  }

  // Percussion (usul).
  for (var bar = 0; bar < t.bars; bar++) {
    for (var i = 0; i < 8; i++) {
      final kind = t.usul[i];
      if (kind == 0) continue;
      final s = ((bar * 8 + i) * step * sampleRate).round();
      kind == 1 ? _dum(out, s) : _tek(out, s, rnd);
    }
  }

  // Fade in/out and normalise.
  var peak = 0.0;
  for (final v in out) {
    peak = max(peak, v.abs());
  }
  final g = peak > 0 ? .9 / peak : 1.0;
  final fade = (sampleRate * 1.2).round();
  for (var i = 0; i < total; i++) {
    var e = 1.0;
    if (i < fade ~/ 4) e = i / (fade / 4);
    if (i > total - fade) e = (total - i) / fade;
    out[i] *= g * e;
  }
  return out;
}

/// Karplus–Strong plucked string.
void _pluck(Float32List out, int start, double f, double seconds, double amp) {
  if (start < 0 || start >= out.length) return;
  final n = max(2, (sampleRate / f).round());
  final rnd = Random(start ^ n);
  final buf = Float32List(n);
  for (var i = 0; i < n; i++) {
    buf[i] = rnd.nextDouble() * 2 - 1;
  }
  final len = min((seconds * sampleRate).round(), out.length - start);
  var idx = 0;
  for (var i = 0; i < len; i++) {
    final next = (idx + 1) % n;
    final v = buf[idx];
    buf[idx] = .996 * .5 * (v + buf[next]);
    idx = next;
    out[start + i] += v * amp;
  }
}

/// Low "düm": a sine with falling pitch.
void _dum(Float32List out, int start) {
  final len = min((sampleRate * .35).round(), out.length - start);
  var phase = 0.0;
  for (var i = 0; i < len; i++) {
    final tt = i / sampleRate;
    final f = 60 + 90 * exp(-tt * 30);
    phase += 2 * pi * f / sampleRate;
    out[start + i] += sin(phase) * exp(-tt * 9) * .7;
  }
}

/// Sharp "tek": a short burst of filtered noise.
void _tek(Float32List out, int start, Random rnd) {
  final len = min((sampleRate * .09).round(), out.length - start);
  var prev = 0.0;
  for (var i = 0; i < len; i++) {
    final noise = rnd.nextDouble() * 2 - 1;
    final hp = noise - prev; // crude high-pass
    prev = noise;
    out[start + i] += hp * exp(-i / sampleRate * 45) * .22;
  }
}
