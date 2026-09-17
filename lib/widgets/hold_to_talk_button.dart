import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../features/voice/voice_capture.dart';

/// Sliding this far up or left while holding throws the recording away.
const double kHoldToTalkCancelDistance = 60;

/// The mic. Press and hold to record, release to transcribe: the words
/// arrive in [onTranscript], and where they go (a field, at its caret) is
/// the caller's business — nothing here submits. Slide up or left while
/// holding to discard. A plain tap toggles recording instead, for anyone who
/// cannot hold (a screen-reader user, a switch), so hold-only never locks
/// the mic away. Haptics mark start and stop; while recording the mic
/// becomes a pulsing dot with the elapsed time, while transcribing a
/// spinner. Hidden for the rest of the session once the brain says it has
/// no STT worker (a 412; [SttAvailability]).
///
/// [width] and [height] box the target: 44 × 44 on its own, or the field's
/// inner height when it sits inside a [VoiceTextField]. Recording widens it
/// to fit the timer.
class HoldToTalkButton extends ConsumerStatefulWidget {
  const HoldToTalkButton({
    super.key,
    required this.onTranscript,
    required this.onError,
    this.enabled = true,
    this.width = 44,
    this.height = 44,
  });

  final ValueChanged<String> onTranscript;

  /// A line for the field's error slot ("Microphone permission is needed…",
  /// the server's 412 hint, "Couldn't hear anything").
  final ValueChanged<String> onError;
  final bool enabled;
  final double width;
  final double height;

  @override
  ConsumerState<HoldToTalkButton> createState() => _HoldToTalkButtonState();
}

class _HoldToTalkButtonState extends ConsumerState<HoldToTalkButton>
    with SingleTickerProviderStateMixin {
  late final VoiceCapture _capture;
  late final AnimationController _pulse;
  VoiceCaptureState _shown = VoiceCaptureState.idle;
  bool _cancelledThisHold = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _capture = VoiceCapture(
      recorder: ref.read(voiceRecorderFactoryProvider)(),
      transcribe: (path) => ref.read(voiceTranscriberProvider)(path),
      onTranscript: (text) {
        if (mounted) widget.onTranscript(text);
      },
      onError: (e) {
        if (!mounted) return;
        if (e.sttUnavailable) {
          ref.read(sttAvailabilityProvider.notifier).markUnavailable();
        }
        widget.onError(e.message);
      },
    );
    _capture.addListener(_onCapture);
  }

  @override
  void dispose() {
    _capture.removeListener(_onCapture);
    _capture.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onCapture() {
    if (!mounted) return;
    final next = _capture.state;
    if (next != _shown) {
      if (next == VoiceCaptureState.recording ||
          _shown == VoiceCaptureState.recording) {
        HapticFeedback.mediumImpact();
      }
      if (next == VoiceCaptureState.idle) {
        _pulse.stop();
        _pulse.reset();
      } else if (!_pulse.isAnimating) {
        _pulse.repeat(reverse: next == VoiceCaptureState.recording);
      }
      _shown = next;
    }
    setState(() {});
  }

  void _toggle() {
    if (!widget.enabled) return;
    if (_capture.isRecording) {
      _capture.stop();
    } else if (_capture.isIdle) {
      _capture.start();
    }
  }

  void _holdStart(LongPressStartDetails _) {
    if (!widget.enabled) return;
    _cancelledThisHold = false;
    _capture.start();
  }

  void _holdMove(LongPressMoveUpdateDetails d) {
    if (_cancelledThisHold) return;
    final o = d.localOffsetFromOrigin;
    if (o.dy < -kHoldToTalkCancelDistance ||
        o.dx < -kHoldToTalkCancelDistance) {
      _cancelledThisHold = true;
      _capture.cancel();
    }
  }

  void _holdEnd(LongPressEndDetails _) {
    if (_cancelledThisHold) return;
    _capture.stop();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(sttAvailabilityProvider)) return const SizedBox.shrink();
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final state = _capture.state;
    final label = switch (state) {
      VoiceCaptureState.idle => 'Hold to dictate',
      VoiceCaptureState.recording => 'Stop dictating',
      VoiceCaptureState.transcribing => 'Transcribing',
    };
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: label,
      hint: state == VoiceCaptureState.idle
          ? 'Hold and speak, or tap to start and tap again to stop'
          : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        onLongPressStart: _holdStart,
        onLongPressMoveUpdate: _holdMove,
        onLongPressEnd: _holdEnd,
        child: SizedBox(
          height: widget.height,
          child: switch (state) {
            VoiceCaptureState.idle => SizedBox(
                width: widget.width,
                child: Center(
                  // Muted like every other in-field or action-row glyph
                  // (SecretInput's eye, the composer's paperclip); half
                  // that while disabled.
                  child: Icon(
                    LucideIcons.mic,
                    size: 20,
                    color: widget.enabled
                        ? scheme.mutedForeground
                        : scheme.mutedForeground.withValues(alpha: 0.5),
                  ),
                ),
              ),
            VoiceCaptureState.recording => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: Tween<double>(begin: 0.35, end: 1)
                          .animate(_pulse),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: scheme.destructive,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _fmt(_capture.elapsed),
                      style: theme.textTheme.small
                          .copyWith(color: scheme.foreground),
                    ),
                  ],
                ),
              ),
            VoiceCaptureState.transcribing => SizedBox(
                width: widget.width,
                child: Center(
                  child: RotationTransition(
                    turns: _pulse,
                    child: Icon(
                      LucideIcons.loaderCircle,
                      size: 20,
                      color: scheme.mutedForeground,
                    ),
                  ),
                ),
              ),
          },
        ),
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
