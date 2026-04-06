import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlayerScreen extends StatefulWidget {
  final String title;
  final String url;
  const AudioPlayerScreen({super.key, required this.title, required this.url});

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      await _player.setUrl(widget.url);
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Impossible de charger l\'audio.';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration? d) {
    if (d == null) return '00:00';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.title,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            overflow: TextOverflow.ellipsis),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.redAccent)))
              : _buildPlayer(),
    );
  }

  Widget _buildPlayer() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icône décorative
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
              border: Border.all(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
                  width: 2),
            ),
            child: const Icon(Icons.headphones_rounded,
                color: Color(0xFF0EA5E9), size: 60),
          ),
          const SizedBox(height: 32),
          Text(widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 32),

          // Barre de progression
          StreamBuilder<Duration?>(
            stream: _player.durationStream,
            builder: (_, snap) {
              final total = snap.data ?? Duration.zero;
              return StreamBuilder<Duration>(
                stream: _player.positionStream,
                builder: (_, posSnap) {
                  final pos = posSnap.data ?? Duration.zero;
                  final progress = total.inMilliseconds > 0
                      ? pos.inMilliseconds / total.inMilliseconds
                      : 0.0;
                  return Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFF0EA5E9),
                          inactiveTrackColor:
                              const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                          thumbColor: const Color(0xFF0EA5E9),
                          overlayColor:
                              const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: progress.clamp(0.0, 1.0),
                          onChanged: (v) => _player.seek(
                              Duration(
                                  milliseconds:
                                      (v * total.inMilliseconds).round())),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_fmt(pos),
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                            Text(_fmt(total),
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),

          const SizedBox(height: 24),

          // Boutons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // -10s
              IconButton(
                onPressed: () => _player.seek(
                    (_player.position) - const Duration(seconds: 10)),
                icon: const Icon(Icons.replay_10_rounded,
                    color: Colors.white70, size: 32),
              ),
              const SizedBox(width: 20),
              // Play/Pause
              StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (_, snap) {
                  final playing = snap.data?.playing ?? false;
                  return GestureDetector(
                    onTap: () =>
                        playing ? _player.pause() : _player.play(),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                          color: Color(0xFF0EA5E9),
                          shape: BoxShape.circle),
                      child: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 20),
              // +10s
              IconButton(
                onPressed: () => _player.seek(
                    (_player.position) + const Duration(seconds: 10)),
                icon: const Icon(Icons.forward_10_rounded,
                    color: Colors.white70, size: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }
}