import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'synth.dart';

enum Repeat { off, all, one }

/// Playback state shared by the library, the mini player and the full player.
class Player extends ChangeNotifier {
  final _audio = AudioPlayer();
  final _cache = <int, Uint8List>{};
  final _subs = <StreamSubscription>[];
  SharedPreferences? _prefs;

  int? current; // null until something is chosen
  List<int> queue = [for (var i = 0; i < tracks.length; i++) i];
  bool playing = false;
  bool loading = false;
  bool shuffle = false;
  Repeat repeat = Repeat.all;
  double volume = .8;
  Duration position = Duration.zero;
  Set<int> favs = {};
  List<int> recent = [];

  Player() {
    _audio.setReleaseMode(ReleaseMode.stop);
    _subs.add(_audio.onPositionChanged.listen((p) {
      position = p;
      notifyListeners();
    }));
    _subs.add(_audio.onPlayerComplete.listen((_) => _onComplete()));
    _subs.add(_audio.onPlayerStateChanged.listen((s) {
      playing = s == PlayerState.playing;
      notifyListeners();
    }));
    SharedPreferences.getInstance().then((p) {
      _prefs = p;
      favs = (p.getStringList('favs') ?? []).map(int.parse).toSet();
      recent = (p.getStringList('recent') ?? []).map(int.parse).where((i) => i < tracks.length).toList();
      notifyListeners();
    });
  }

  TrackSpec? get track => current == null ? null : tracks[current!];

  /// Plays track [i]; [from] is the list it was chosen from, which becomes the queue.
  Future<void> play(int i, {List<int>? from}) async {
    if (from != null && from.isNotEmpty) queue = [...from];
    if (!queue.contains(i)) queue = [i, ...queue];
    current = i;
    loading = true;
    position = Duration.zero;
    recent = [i, ...recent.where((x) => x != i)].take(6).toList();
    _prefs?.setStringList('recent', recent.map((e) => '$e').toList());
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 30)); // let the spinner paint
    final bytes = _cache[i] ??= renderWav(tracks[i]);
    await _audio.stop();
    await _audio.setVolume(volume);
    await _audio.play(BytesSource(bytes, mimeType: 'audio/wav'));
    loading = false;
    notifyListeners();
  }

  Future<void> toggle() async {
    if (loading) return;
    if (current == null) return play(queue.first);
    if (playing) {
      await _audio.pause();
    } else if (position > Duration.zero) {
      await _audio.resume();
    } else {
      await play(current!);
    }
  }

  /// The tracks after the current one in the queue.
  List<int> get upNext {
    if (current == null) return queue;
    final at = queue.indexOf(current!);
    return [...queue.sublist(at + 1), if (repeat == Repeat.all) ...queue.sublist(0, at)];
  }

  int _step(int dir) {
    if (current == null) return queue.first;
    if (shuffle && queue.length > 1) {
      final others = queue.where((i) => i != current).toList();
      return others[Random().nextInt(others.length)];
    }
    final at = queue.indexOf(current!);
    return queue[(at + dir) % queue.length];
  }

  void next() => play(_step(1));
  void previous() => position.inSeconds > 3 ? seek(Duration.zero) : play(_step(-1));

  void _onComplete() {
    if (repeat == Repeat.one) {
      play(current!);
      return;
    }
    final last = queue.indexOf(current!) == queue.length - 1;
    if (repeat == Repeat.off && last && !shuffle) {
      position = Duration.zero;
      notifyListeners();
      return;
    }
    next();
  }

  void seek(Duration d) {
    position = d;
    _audio.seek(d);
    notifyListeners();
  }

  void setVolume(double v) {
    volume = v;
    _audio.setVolume(v);
    notifyListeners();
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    notifyListeners();
  }

  void cycleRepeat() {
    repeat = Repeat.values[(repeat.index + 1) % 3];
    notifyListeners();
  }

  void toggleFav(int i) {
    favs.contains(i) ? favs.remove(i) : favs.add(i);
    _prefs?.setStringList('favs', favs.map((e) => '$e').toList());
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _audio.dispose();
    super.dispose();
  }
}

class PlayerScope extends InheritedNotifier<Player> {
  const PlayerScope({super.key, required Player player, required super.child}) : super(notifier: player);
  static Player of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<PlayerScope>()!.notifier!;
}

String fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
