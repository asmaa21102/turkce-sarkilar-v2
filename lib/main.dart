import 'dart:math';

import 'package:flutter/material.dart';

import 'player.dart';
import 'synth.dart';

void main() => runApp(PlayerScope(player: Player(), child: const MusicApp()));

const bg = Color(0xFF0B1020);

class MusicApp extends StatelessWidget {
  const MusicApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Türkçe Şarkılar',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2962FF), brightness: Brightness.dark), scaffoldBackgroundColor: bg),
        home: const LibraryPage(),
      );
}

// ── Library ─────────────────────────────────────────────────────────────
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String query = '';
  String? makam; // filter
  bool favsOnly = false;
  String sort = 'list'; // list, name, tempo, length

  List<int> visible(Player p) {
    final q = query.trim().toLowerCase();
    final list = [
      for (var i = 0; i < tracks.length; i++)
        if ((makam == null || tracks[i].makam.name == makam) &&
            (!favsOnly || p.favs.contains(i)) &&
            (q.isEmpty || '${tracks[i].title} ${tracks[i].makam.name} ${tracks[i].mood}'.toLowerCase().contains(q)))
          i,
    ];
    switch (sort) {
      case 'name':
        list.sort((a, b) => tracks[a].title.compareTo(tracks[b].title));
      case 'tempo':
        list.sort((a, b) => tracks[b].bpm.compareTo(tracks[a].bpm));
      case 'length':
        list.sort((a, b) => tracks[a].duration.compareTo(tracks[b].duration));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final p = PlayerScope.of(context);
    final items = visible(p);
    final makams = {for (final t in tracks) t.makam.name}.toList();
    final totalMin = tracks.fold(Duration.zero, (a, t) => a + t.duration).inMinutes;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
            sliver: SliverToBoxAdapter(
              child: Row(children: [
                const Icon(Icons.graphic_eq_rounded),
                const SizedBox(width: 8),
                const Expanded(child: Text('Türkçe Şarkılar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
                IconButton(tooltip: 'Bilgi', onPressed: () => _about(context), icon: const Icon(Icons.info_outline_rounded)),
              ]),
            ),
          ),
          // Hero card: play everything
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), gradient: const LinearGradient(colors: [Color(0xFF2962FF), Color(0xFF7C4DFF)])),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Makam Seçkisi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      Text('${tracks.length} parça · ${makams.length} makam · ~$totalMin dk', style: const TextStyle(color: Colors.white70)),
                    ]),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                    onPressed: items.isEmpty ? null : () => p.play(p.shuffle ? items[Random().nextInt(items.length)] : items.first, from: items),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Çal'),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(tooltip: 'Karışık', onPressed: p.toggleShuffle, icon: Icon(Icons.shuffle_rounded, color: p.shuffle ? Colors.white : Colors.white54)),
                ]),
              ),
            ),
          ),
          if (p.recent.isNotEmpty && query.isEmpty && makam == null && !favsOnly) ...[
            const _Title('Son çalınanlar'),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 150,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: p.recent.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, k) {
                    final i = p.recent[k];
                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => p.play(i, from: p.recent),
                      child: SizedBox(
                        width: 112,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Cover(index: i, size: 112, radius: 18),
                          const SizedBox(height: 6),
                          Text(tracks[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
          // Search + filters
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            sliver: SliverToBoxAdapter(
              child: SearchBar(
                hintText: 'Parça, makam veya ruh hâli ara',
                leading: const Icon(Icons.search_rounded),
                elevation: const WidgetStatePropertyAll(0),
                backgroundColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: .07)),
                onChanged: (v) => setState(() => query = v),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(children: [
                FilterChip(
                  avatar: Icon(favsOnly ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 18, color: const Color(0xFFFF4081)),
                  label: Text('Favoriler (${p.favs.length})'),
                  selected: favsOnly,
                  showCheckmark: false,
                  onSelected: (v) => setState(() => favsOnly = v),
                ),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Tüm makamlar'), selected: makam == null, onSelected: (_) => setState(() => makam = null)),
                for (final m in makams) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(label: Text(m), selected: makam == m, onSelected: (_) => setState(() => makam = makam == m ? null : m)),
                ],
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
            sliver: SliverToBoxAdapter(
              child: Row(children: [
                Text('${items.length} parça', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const Spacer(),
                PopupMenuButton<String>(
                  initialValue: sort,
                  onSelected: (v) => setState(() => sort = v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'list', child: Text('Liste sırası')),
                    PopupMenuItem(value: 'name', child: Text('İsme göre')),
                    PopupMenuItem(value: 'tempo', child: Text('En hareketli')),
                    PopupMenuItem(value: 'length', child: Text('En kısa')),
                  ],
                  child: const Padding(padding: EdgeInsets.all(8), child: Row(children: [Icon(Icons.sort_rounded, size: 20), SizedBox(width: 4), Text('Sırala')])),
                ),
              ]),
            ),
          ),
          if (items.isEmpty)
            const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Text('Bu seçime uygun parça yok.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)))),
          SliverList.builder(
            itemCount: items.length,
            itemBuilder: (_, k) => TrackTile(index: items[k], number: k + 1, onTap: () => items[k] == p.current ? p.toggle() : p.play(items[k], from: items)),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ]),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  void _about(BuildContext context) => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Bu parçalar hakkında'),
          content: const Text('Parçalar uygulamanın içinde, çalarken üretilir: telli bir çalgıya benzeyen tını (Karplus–Strong), Türk makamlarında bir ezgi ve darbukaya benzeyen bir usul. Kayıtlı şarkı kullanılmaz, telif sorunu yoktur.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam'))],
        ),
      );
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);
  @override
  Widget build(BuildContext context) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
        sliver: SliverToBoxAdapter(child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
      );
}

class Cover extends StatelessWidget {
  final int index;
  final double size;
  final double radius;
  final Widget? child;
  const Cover({super.key, required this.index, required this.size, this.radius = 14, this.child});

  @override
  Widget build(BuildContext context) {
    final c = Color(tracks[index].color);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c, Color.lerp(c, Colors.black, .55)!])),
      child: Stack(alignment: Alignment.center, children: [
        Positioned(right: -size * .2, top: -size * .2, child: CircleAvatar(radius: size * .36, backgroundColor: Colors.white.withValues(alpha: .09))),
        child ?? Icon(Icons.music_note_rounded, color: Colors.white, size: size * .38),
        if (size >= 100) Positioned(left: size * .1, bottom: size * .08, child: Text(tracks[index].makam.name.toUpperCase(), style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, letterSpacing: 2, fontSize: size * .07))),
      ]),
    );
  }
}

class TrackTile extends StatelessWidget {
  final int index;
  final int number;
  final VoidCallback onTap;
  const TrackTile({super.key, required this.index, required this.number, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = PlayerScope.of(context);
    final t = tracks[index];
    final isCurrent = p.current == index;
    final color = Color(t.color);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isCurrent ? color.withValues(alpha: .16) : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
            child: Row(children: [
              SizedBox(width: 26, child: Text('$number', textAlign: TextAlign.center, style: TextStyle(color: isCurrent ? color : Colors.white38, fontWeight: FontWeight.w700))),
              const SizedBox(width: 6),
              Cover(
                index: index,
                size: 50,
                child: isCurrent
                    ? (p.loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : p.playing ? const Equalizer(small: true) : const Icon(Icons.pause_rounded, color: Colors.white))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: isCurrent ? Color.lerp(color, Colors.white, .45) : null)),
                  Text('${t.makam.name} · ${t.mood}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                ]),
              ),
              Text(fmt(t.duration), style: const TextStyle(color: Colors.white54, fontSize: 13)),
              IconButton(
                tooltip: 'Favori',
                onPressed: () => p.toggleFav(index),
                icon: Icon(p.favs.contains(index) ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 20, color: p.favs.contains(index) ? const Color(0xFFFF4081) : Colors.white38),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Mini player ─────────────────────────────────────────────────────────
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final p = PlayerScope.of(context);
    final t = p.track;
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: t == null
          ? const SizedBox(width: double.infinity)
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Material(
                  color: Color.lerp(Color(t.color), bg, .55),
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => openNowPlaying(context),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 4, 8),
                        child: Row(children: [
                          Hero(tag: 'cover', child: Cover(index: p.current!, size: 44, radius: 12, child: p.playing ? const Equalizer(small: true) : null)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text('${t.makam.name} makamı', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ]),
                          ),
                          IconButton(tooltip: 'Önceki', onPressed: p.previous, icon: const Icon(Icons.skip_previous_rounded)),
                          IconButton.filled(
                            style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                            onPressed: p.toggle,
                            icon: p.loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black)) : Icon(p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                          ),
                          IconButton(tooltip: 'Sonraki', onPressed: p.next, icon: const Icon(Icons.skip_next_rounded)),
                        ]),
                      ),
                      LinearProgressIndicator(value: t.duration.inMilliseconds == 0 ? 0 : (p.position.inMilliseconds / t.duration.inMilliseconds).clamp(0, 1), minHeight: 3, backgroundColor: Colors.white12, color: Colors.white),
                    ]),
                  ),
                ),
              ),
            ),
    );
  }
}

void openNowPlaying(BuildContext context) => Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, _, _) => const NowPlayingPage(),
      transitionsBuilder: (_, a, _, child) => SlideTransition(position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
    ));

// ── Now playing ─────────────────────────────────────────────────────────
class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = PlayerScope.of(context);
    final t = p.track!;
    final color = Color(t.color);
    final total = t.duration;
    final next = p.upNext;
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(color, Colors.black, .3)!, bg, bg], stops: const [0, .6, 1])),
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
            Row(children: [
              IconButton(tooltip: 'Kapat', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32)),
              const Expanded(child: Text('ŞİMDİ ÇALIYOR', textAlign: TextAlign.center, style: TextStyle(letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70))),
              const SizedBox(width: 48),
            ]),
            const SizedBox(height: 14),
            Center(
              child: Hero(
                tag: 'cover',
                child: Container(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(36), boxShadow: [BoxShadow(color: color.withValues(alpha: .45), blurRadius: 50, offset: const Offset(0, 24))]),
                  child: Cover(index: p.current!, size: 260, radius: 36, child: Equalizer(active: p.playing)),
                ),
              ),
            ),
            const SizedBox(height: 26),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                    Text('${t.makam.name} makamı · ${t.mood} · ${t.bpm} BPM', style: const TextStyle(color: Colors.white60)),
                  ]),
                ),
                IconButton(onPressed: () => p.toggleFav(p.current!), icon: Icon(p.favs.contains(p.current) ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: p.favs.contains(p.current) ? const Color(0xFFFF4081) : null)),
              ]),
            ),
            const SizedBox(height: 10),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7), overlayShape: SliderComponentShape.noOverlay, activeTrackColor: Colors.white, inactiveTrackColor: Colors.white24, thumbColor: Colors.white),
              child: Slider(value: p.position.inMilliseconds.clamp(0, total.inMilliseconds).toDouble(), max: total.inMilliseconds.toDouble(), onChanged: (v) => p.seek(Duration(milliseconds: v.round()))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Row(children: [Text(fmt(p.position), style: const TextStyle(color: Colors.white60, fontSize: 12)), const Spacer(), Text(fmt(total), style: const TextStyle(color: Colors.white60, fontSize: 12))]),
            ),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              IconButton(tooltip: 'Karışık', onPressed: p.toggleShuffle, icon: Icon(Icons.shuffle_rounded, color: p.shuffle ? color : Colors.white54)),
              IconButton(iconSize: 38, tooltip: 'Önceki', onPressed: p.previous, icon: const Icon(Icons.skip_previous_rounded)),
              SizedBox(
                width: 78, height: 78,
                child: FilledButton(
                  style: FilledButton.styleFrom(shape: const CircleBorder(), backgroundColor: Colors.white, foregroundColor: Colors.black, padding: EdgeInsets.zero),
                  onPressed: p.toggle,
                  child: p.loading ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.black)) : Icon(p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 44),
                ),
              ),
              IconButton(iconSize: 38, tooltip: 'Sonraki', onPressed: p.next, icon: const Icon(Icons.skip_next_rounded)),
              IconButton(tooltip: 'Tekrar', onPressed: p.cycleRepeat, icon: Icon(p.repeat == Repeat.one ? Icons.repeat_one_rounded : Icons.repeat_rounded, color: p.repeat == Repeat.off ? Colors.white54 : color)),
            ]),
            Row(children: [
              const Icon(Icons.volume_down_rounded, color: Colors.white54),
              Expanded(child: Slider(value: p.volume, onChanged: p.setVolume)),
              const Icon(Icons.volume_up_rounded, color: Colors.white54),
            ]),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(children: [
                const Text('Sıradakiler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                if (p.shuffle) const Text('karışık çalınıyor', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 6),
            if (next.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Liste bitiyor.', style: TextStyle(color: Colors.white54))),
            for (var k = 0; k < next.length; k++) TrackTile(index: next[k], number: k + 1, onTap: () => p.play(next[k])),
          ]),
        ),
      ),
    );
  }
}

/// Animated equaliser bars (they rebuild every frame only while visible).
class Equalizer extends StatefulWidget {
  final bool active;
  final bool small;
  const Equalizer({super.key, this.active = true, this.small = false});
  @override
  State<Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<Equalizer> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.small ? 4 : 7;
    final maxH = widget.small ? 20.0 : 96.0;
    return AnimatedBuilder(
      animation: c,
      builder: (_, _) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < n; i++)
          Container(
            margin: EdgeInsets.symmetric(horizontal: widget.small ? 1.5 : 4),
            width: widget.small ? 4 : 10,
            height: widget.active ? maxH * (.25 + .75 * ((sin(2 * pi * (c.value + i * .17)) * .5 + .5) * (.6 + .4 * sin(i * 1.7))).abs()) : maxH * .2,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)),
          ),
      ]),
    );
  }
}
