import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class MemberVoicePlayer extends StatefulWidget {
  final String url;
  const MemberVoicePlayer({super.key, required this.url});

  @override
  State<MemberVoicePlayer> createState() => _MemberVoicePlayerState();
}

class _MemberVoicePlayerState extends State<MemberVoicePlayer> {
  late final AudioPlayer _player;
  static const Color _waveColor = Color(0xFFB18B55);

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    unawaited(_player.setUrl(widget.url).catchError((Object _) => null));
  }

  @override
  void didUpdateWidget(covariant MemberVoicePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _player.setUrl(widget.url).catchError((_) {});
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _time(Duration? value) {
    final seconds = (value ?? Duration.zero).inSeconds;
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<PlayerState>(
    stream: _player.playerStateStream,
    builder: (context, state) {
      final playing = state.data?.playing ?? false;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.45),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _waveColor.withOpacity(.28)),
        ),
        child: Column(children: [
          Row(children: [
            Icon(Icons.graphic_eq_rounded, color: _waveColor),
            const SizedBox(width: 8),
            const Expanded(child: Text('البصمة الصوتية', style: TextStyle(fontWeight: FontWeight.w800))),
            IconButton(
              tooltip: playing ? 'إيقاف مؤقت' : 'تشغيل',
              onPressed: () async {
                if (playing) {
                  await _player.pause();
                } else {
                  if (_player.processingState == ProcessingState.completed) await _player.seek(Duration.zero);
                  await _player.play();
                }
              },
              icon: Icon(playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, size: 38, color: _waveColor),
            ),
          ]),
          StreamBuilder<Duration>(
            stream: _player.positionStream,
            builder: (context, position) => StreamBuilder<Duration?>(
              stream: _player.durationStream,
              builder: (context, duration) {
                final total = duration.data ?? Duration.zero;
                final current = position.data ?? Duration.zero;
                final progress = total.inMilliseconds == 0 ? 0.0 : (current.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
                return Column(children: [
                  Row(
                    children: List.generate(36, (i) {
                      final heights = [10,16,23,13,28,18,34,15,24,31,12,20,35,17,27,11,22,32,14,25,18,30,12,35,20,27,14,32,17,24,11,29,19,34,13,22];
                      final active = i / 36 <= progress;
                      return Expanded(child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        height: heights[i].toDouble(),
                        decoration: BoxDecoration(color: active ? _waveColor : _waveColor.withOpacity(playing ? .30 : .20), borderRadius: BorderRadius.circular(5)),
                      ));
                    }),
                  ),
                  const SizedBox(height: 7),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(_time(current), style: Theme.of(context).textTheme.labelSmall),
                    Text(_time(total), style: Theme.of(context).textTheme.labelSmall),
                  ]),
                  Slider(
                    value: progress,
                    onChanged: total == Duration.zero ? null : (v) => _player.seek(Duration(milliseconds: (total.inMilliseconds * v).round())),
                    activeColor: _waveColor,
                  ),
                ]);
              },
            ),
          ),
        ]),
      );
    },
  );
}
