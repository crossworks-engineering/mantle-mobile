import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// A compact audio player for a voice reply (or any audio attachment): a
/// play/pause button, a scrub-free progress track, and an elapsed/total
/// readout. Loads from a local file path (the turn writes the artifact bytes to
/// disk). Self-contained — owns its [AudioPlayer] and tears it down on dispose.
class AudioBubble extends StatefulWidget {
  const AudioBubble({
    super.key,
    required this.path,
    required this.theme,
    this.caption,
  });

  final String path;
  final ShadThemeData theme;
  final String? caption;

  @override
  State<AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<AudioBubble> {
  final _player = AudioPlayer();
  final _subs = <StreamSubscription<dynamic>>[];

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _playing = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final d = await _player.setFilePath(widget.path);
      if (!mounted) return;
      setState(() => _duration = d ?? Duration.zero);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    _subs.add(_player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    }));
    _subs.add(_player.durationStream.listen((d) {
      if (d != null && mounted) setState(() => _duration = d);
    }));
    _subs.add(_player.playerStateStream.listen((s) {
      if (!mounted) return;
      // Reaching the end stops playback and rewinds, so the button flips back
      // to "play" and the next tap restarts from the top.
      if (s.processingState == ProcessingState.completed) {
        _player.pause();
        _player.seek(Duration.zero);
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      } else {
        setState(() => _playing = s.playing);
      }
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_failed) return;
    if (_playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.theme.colorScheme;

    if (_failed) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.volumeX, size: 18, color: scheme.mutedForeground),
            const SizedBox(width: 8),
            Text('Audio unavailable', style: widget.theme.textTheme.muted),
          ],
        ),
      );
    }

    final total = _duration.inMilliseconds;
    final progress =
        total == 0 ? 0.0 : (_position.inMilliseconds / total).clamp(0.0, 1.0);

    return SizedBox(
      width: 240,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: scheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.border),
        ),
        child: Row(
          children: [
            // The circle stays 36 so the bubble keeps its shape; the hit
            // box around it is the 44pt target.
            Semantics(
              button: true,
              label: _playing ? 'Pause' : 'Play',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggle,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _playing ? LucideIcons.pause : LucideIcons.play,
                        size: 18,
                        color: scheme.primaryForeground,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A thin progress track: muted base, primary fill.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Stack(
                      children: [
                        Container(
                          height: 4,
                          color: scheme.foreground.withValues(alpha: 0.15),
                        ),
                        FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(height: 4, color: scheme.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_fmt(_position)} / ${_fmt(_duration)}',
                    style: widget.theme.textTheme.muted,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
