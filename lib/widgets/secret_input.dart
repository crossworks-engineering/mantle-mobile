import 'package:flutter/services.dart' show TextInputAction, TextInputType;
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// A masked text field with a show/hide eye — the one input for a password,
/// an app password, an API key, a token, or any other value the screen
/// should not display by default. Every secret field in the app is this
/// widget, so a new one gets the toggle for free and the behaviour stays the
/// same everywhere (mirrors the web's `SecretInput`).
///
/// Masked on first build. The trailing eye flips the field between masked
/// and plain text and is a 44pt target (the app's minimum) named for screen
/// readers as "Show password" / "Hide password". Autocorrect and suggestions
/// are off, as they are for every secret. `autofillHints` defaults to the
/// password hint so iOS and Android password managers still fill the field;
/// the toggle does not touch the controller, so a filled value survives it.
class SecretInput extends StatefulWidget {
  const SecretInput({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.enabled = true,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints = const [AutofillHints.password],
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final Widget? placeholder;
  final bool enabled;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  /// Password-manager hints. Pass `const []` for a value no manager should
  /// offer to fill (an API key typed once).
  final Iterable<String> autofillHints;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<SecretInput> createState() => _SecretInputState();
}

/// A default shadcn input's height minus its 1pt border top and bottom.
const double _kInnerHeight = 37;

class _SecretInputState extends State<SecretInput> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return ShadInput(
      controller: widget.controller,
      focusNode: widget.focusNode,
      placeholder: widget.placeholder,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      obscureText: _obscured,
      autocorrect: false,
      enableSuggestions: false,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      // The eye sits inside the field's right edge and must not make this
      // field taller than the plain input above it (a shadcn input is 39pt:
      // one text line, 8pt of vertical padding, a 1pt border). So the
      // vertical padding moves off the field and onto the eye's box, which
      // is exactly the field's inner height; the target is 44pt wide and the
      // field's full height tall. The glyph stays 18.
      padding: const EdgeInsets.symmetric(horizontal: 12),
      trailing: Semantics(
        button: true,
        label: _obscured ? 'Show password' : 'Hide password',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled
              ? () => setState(() => _obscured = !_obscured)
              : null,
          child: SizedBox(
            width: 44,
            height: _kInnerHeight,
            child: Center(
              child: Icon(
                _obscured ? LucideIcons.eye : LucideIcons.eyeOff,
                size: 18,
                color: scheme.mutedForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
