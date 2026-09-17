import 'package:flutter/services.dart'
    show TextInputAction, TextInputType, TextSelection;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../features/voice/voice_capture.dart';
import 'hold_to_talk_button.dart';

/// A default shadcn input's height minus its 1pt border top and bottom.
const double _kInnerHeight = 37;

/// A [ShadInput] with a [HoldToTalkButton] inside its right edge — the one
/// input for anything new the phone would otherwise make you type: a task,
/// a note, an event title, a journal entry. Hold the mic, speak, release,
/// and the words land in the field at the caret ([insertTranscript]) for a
/// look before they are saved; nothing submits on its own (Whisper invents
/// words on silence). A second hold extends rather than replaces.
///
/// The mic must not make this field taller than a plain input beside it, so
/// the field's vertical padding moves off the row and onto the text
/// ([ShadInput.inputPadding]) and the mic's box is exactly the inner height,
/// like [SecretInput]'s eye. A growing field keeps the mic on its last line.
/// The mic is gone for the session once the brain answers 412 (no STT
/// worker), and the field is then a plain [ShadInput].
///
/// A failure shows as the field's own error line below it, unless [onError]
/// is given — a screen with an error slot of its own passes that.
class VoiceTextField extends ConsumerStatefulWidget {
  const VoiceTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.placeholder,
    this.enabled = true,
    this.autofocus = false,
    this.style,
    this.placeholderStyle,
    this.minLines,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.onError,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final Widget? placeholder;
  final bool enabled;
  final bool autofocus;
  final TextStyle? style;
  final TextStyle? placeholderStyle;
  final int? minLines;
  final int? maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Where a dictation failure goes. Null → shown under the field.
  final ValueChanged<String>? onError;

  @override
  ConsumerState<VoiceTextField> createState() => _VoiceTextFieldState();
}

class _VoiceTextFieldState extends ConsumerState<VoiceTextField> {
  String? _error;

  void _insert(String text) {
    insertTranscript(widget.controller, text);
    widget.onChanged?.call(widget.controller.text);
    if (_error != null) setState(() => _error = null);
  }

  void _fail(String message) {
    final forward = widget.onError;
    if (forward != null) {
      forward(message);
    } else {
      setState(() => _error = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final withMic = ref.watch(sttAvailabilityProvider);
    final field = ShadInput(
      controller: widget.controller,
      focusNode: widget.focusNode,
      placeholder: widget.placeholder,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      style: widget.style,
      placeholderStyle: widget.placeholderStyle,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      padding: withMic ? const EdgeInsets.symmetric(horizontal: 12) : null,
      inputPadding: withMic ? const EdgeInsets.symmetric(vertical: 8) : null,
      crossAxisAlignment: CrossAxisAlignment.end,
      trailing: withMic
          ? HoldToTalkButton(
              enabled: widget.enabled,
              height: _kInnerHeight,
              onTranscript: _insert,
              onError: _fail,
            )
          : null,
    );
    final error = _error;
    if (error == null) return field;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field,
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            error,
            style: theme.textTheme.small
                .copyWith(color: theme.colorScheme.destructive),
          ),
        ),
      ],
    );
  }
}

/// Put [text] into [controller] at the caret (replacing a selection), with a
/// space on either side where it meets other text, and leave the caret after
/// it. A field that is not focused has no caret; then the words go on the
/// end. The one insertion rule for every dictated field.
void insertTranscript(TextEditingController controller, String text) {
  final words = text.trim();
  if (words.isEmpty) return;
  final current = controller.text;
  var sel = controller.selection;
  if (!sel.isValid || sel.start > current.length || sel.end > current.length) {
    sel = TextSelection.collapsed(offset: current.length);
  }
  final before = current.substring(0, sel.start);
  final after = current.substring(sel.end);
  final lead = before.isNotEmpty && before.trimRight() == before ? ' ' : '';
  final trail = after.isNotEmpty && after.trimLeft() == after ? ' ' : '';
  final inserted = '$lead$words$trail';
  controller.value = TextEditingValue(
    text: '$before$inserted$after',
    selection: TextSelection.collapsed(
      offset: before.length + inserted.length - trail.length,
    ),
  );
}
