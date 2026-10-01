import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../widgets/jackdaw_lockup.dart';
import '../../widgets/secret_input.dart';

import '../../data/auth/auth_api.dart';
import '../../data/server/server_config.dart';
import 'logins_screen.dart' show HeldLoginsList;
import 'scan_sign_in_screen.dart';
import 'session_controller.dart';

/// Email + password sign-in against `POST /api/auth/mobile-login`, or a scan
/// of the web app's sign-in QR ([ScanSignInScreen]). On success the session
/// flips to `loggedIn` and the router moves to home.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Sent here to sign BACK in to a login the phone still lists: start with
    // its email. Read once; a later visit starts clean.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final email = ref.read(pendingLoginEmailProvider.notifier).take();
      if (email != null && _email.text.isEmpty) _email.text = email;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .signIn(email: email, password: password);
      // Router redirects to home on success.
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final server = ref.watch(serverConfigProvider).value;
    // Re-read when the session state changes, which is when this can change.
    ref.watch(sessionControllerProvider);
    final adding =
        ref.read(sessionControllerProvider.notifier).isAddingLogin;
    // Logins this phone still holds. Nobody is in use here, so each is a
    // tap away: after a brain refused the login in use, or after the app was
    // closed while a login was being added, the others must not need a
    // password to get back to.
    final held = ref.watch(heldSessionsProvider).value ?? const [];

    return Container(
      color: theme.colorScheme.background,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const JackdawLockup(),
                  const SizedBox(height: 24),
                  Text(adding ? 'Add a login' : 'Sign in',
                      style: theme.textTheme.h2),
                  const SizedBox(height: 8),
                  Text(
                    server == null ? 'Sign in to Mantle.' : 'Signing in to $server',
                    style: theme.textTheme.muted,
                  ),
                  const SizedBox(height: 24),
                  // One autofill group, hinted, so a password manager fills
                  // both fields together; the eye on the password does not
                  // interfere with that (it never touches the controller).
                  AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ShadInput(
                          controller: _email,
                          placeholder: const Text('you@example.com'),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email,
                          ],
                          autocorrect: false,
                          enabled: !_submitting,
                        ),
                        const SizedBox(height: 12),
                        SecretInput(
                          controller: _password,
                          placeholder: const Text('Password'),
                          textInputAction: TextInputAction.done,
                          enabled: !_submitting,
                          onSubmitted: (_) => _submit(),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: theme.textTheme.small.copyWith(
                        color: theme.colorScheme.destructive,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ShadButton(
                      onPressed: _submitting ? null : _submit,
                      child: Text(_submitting ? 'Signing in…' : 'Sign in'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ShadButton.outline(
                      onPressed:
                          _submitting ? null : () => context.push('/scan'),
                      leading: const Icon(LucideIcons.scanLine, size: 16),
                      child: const Text('Scan a sign-in code'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: ShadButton.link(
                      onPressed: _submitting
                          ? null
                          : () => ref
                              .read(sessionControllerProvider.notifier)
                              .setServer(''),
                      child: const Text('Change server'),
                    ),
                  ),
                  // Adding a login on top of ones already held: the way back
                  // to the login that was in use. It never signed out.
                  if (adding)
                    Center(
                      child: ShadButton.link(
                        onPressed: _submitting
                            ? null
                            : () => ref
                                .read(sessionControllerProvider.notifier)
                                .cancelAddLogin(),
                        child: const Text('Back to the login I was using'),
                      ),
                    ),
                  if (held.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Logins on this phone', style: theme.textTheme.h4),
                    const SizedBox(height: 4),
                    Text(
                      'Tap one to use it without signing in again.',
                      style: theme.textTheme.muted,
                    ),
                    const SizedBox(height: 12),
                    HeldLoginsList(held: held),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
