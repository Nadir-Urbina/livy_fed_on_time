import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

/// Every Livy sound is synthesized in code — zero audio asset files. Tones are
/// rendered to in-memory 16-bit PCM WAV and played via audioplayers. All
/// chimes are deliberately soft and low-volume: quiet-hours appropriate.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const _sampleRate = 22050;
  final _players = <AudioPlayer>[];
  final _cache = <String, Uint8List>{};
  bool enabled = true;

  final _files = <String, String>{};

  Future<void> _play(String key, Uint8List Function() render) async {
    if (!enabled) return;
    try {
      // Synthesized WAVs are rendered once to a temp file — BytesSource is
      // unreliable on iOS (AVPlayer can't stream data URLs), file playback
      // is rock solid. Still zero audio assets: the bytes are generated here.
      var path = _files[key];
      if (path == null) {
        final bytes = _cache.putIfAbsent(key, render);
        final dir = await getTemporaryDirectory();
        path = '${dir.path}/livy_sfx_$key.wav';
        await File(path).writeAsBytes(bytes, flush: true);
        _files[key] = path;
      }
      final player = AudioPlayer();
      _players.add(player);
      player.onPlayerComplete.listen((_) {
        player.dispose();
        _players.remove(player);
      });
      await player.setVolume(0.35);
      await player.play(DeviceFileSource(path));
    } catch (_) {
      // Sound is a garnish — never let it break the interaction.
    }
  }

  /// Soft two-note "logged" chime (C6 → E6, bell-like decay).
  Future<void> feedLogged() => _play('feedLogged', () {
        return _render([
          _Tone(1046.5, 0.00, 0.30),
          _Tone(1318.5, 0.12, 0.42),
        ], seconds: 0.6);
      });

  /// Gentle rising three-note arpeggio for celebrations (C5-E5-G5-C6).
  Future<void> celebration() => _play('celebration', () {
        return _render([
          _Tone(523.25, 0.00, 0.30),
          _Tone(659.25, 0.11, 0.30),
          _Tone(783.99, 0.22, 0.32),
          _Tone(1046.5, 0.33, 0.55),
        ], seconds: 1.0);
      });

  /// A single warm low chime for gentle nudges (A4).
  Future<void> gentleNudge() => _play('gentleNudge', () {
        return _render([_Tone(440.0, 0.0, 0.5)], seconds: 0.6);
      });

  /// Tiny tick for button/press feedback (short, almost subliminal).
  Future<void> tick() => _play('tick', () {
        return _render([_Tone(880.0, 0.0, 0.06)], seconds: 0.08);
      });

  /// Two soft descending notes when something is declined/dismissed.
  Future<void> dismiss() => _play('dismiss', () {
        return _render([
          _Tone(659.25, 0.00, 0.20),
          _Tone(523.25, 0.10, 0.28),
        ], seconds: 0.45);
      });

  /// Renders tones (sine + one octave-up harmonic, exponential decay) into a
  /// 16-bit mono WAV byte buffer.
  Uint8List _render(List<_Tone> tones, {required double seconds}) {
    final n = (seconds * _sampleRate).round();
    final samples = Float64List(n);
    for (final t in tones) {
      final start = (t.startSec * _sampleRate).round();
      final len = (t.durSec * _sampleRate).round();
      for (var i = 0; i < len && start + i < n; i++) {
        final time = i / _sampleRate;
        final env = math.exp(-4.5 * time / t.durSec) * math.min(1.0, i / (_sampleRate * 0.005));
        final v = math.sin(2 * math.pi * t.freq * time) * 0.8 +
            math.sin(2 * math.pi * t.freq * 2 * time) * 0.2;
        samples[start + i] += v * env * 0.5;
      }
    }
    final pcm = Int16List(n);
    for (var i = 0; i < n; i++) {
      pcm[i] = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    }
    return _wrapWav(pcm);
  }

  Uint8List _wrapWav(Int16List pcm) {
    final dataLen = pcm.length * 2;
    final bytes = BytesBuilder();
    void str(String s) => bytes.add(s.codeUnits);
    void u32(int v) => bytes.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);
    void u16(int v) => bytes.add([v & 0xFF, (v >> 8) & 0xFF]);

    str('RIFF');
    u32(36 + dataLen);
    str('WAVE');
    str('fmt ');
    u32(16);
    u16(1); // PCM
    u16(1); // mono
    u32(_sampleRate);
    u32(_sampleRate * 2);
    u16(2);
    u16(16);
    str('data');
    u32(dataLen);
    bytes.add(pcm.buffer.asUint8List());
    return bytes.toBytes();
  }
}

class _Tone {
  const _Tone(this.freq, this.startSec, this.durSec);
  final double freq;
  final double startSec;
  final double durSec;
}
