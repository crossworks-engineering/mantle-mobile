import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/jackdaw_lockup.dart';

import '../../data/server/server_config.dart';
import 'scan_sign_in_screen.dart';
import 'session_controller.dart';

/// First-run screen: which Mantle server are we talking to? Validates the URL
/// by hitting the public `GET /api/version` before saving it. Or scan the web
/// app's sign-in QR, which names the server and signs in in one go
/// ([ScanSignInScreen]).
/// The public read-only brain. Filling it in is the fastest way to see the
/// app with no server of your own, and the way App Review gets in.
const _demoServerUrl = 'https://demo.mantle-ai.tech';
const _mantleSiteUrl = 'https://mantle-ai.tech';

class ServerSetupScreen extends ConsumerStatefulWidget {
  const ServerSetupScreen({super.key});

  @override
  ConsumerState<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends ConsumerState<ServerSetupScreen> {
  final _controller = TextEditingController();
  bool _checking = false;
  String? _error;

  /// Set when the address turned out to be the owner app rather than the brain:
  /// we rewrite the field to the brain it points at and say so, instead of
  /// connecting somewhere the user didn't type. The next tap connects.
  String? _notice;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_controller.text.trim().isEmpty) {
      setState(() => _error = 'Enter your Mantle server URL.');
      return;
    }
    final url = canonicalServerUrl(_controller.text);
    final problem = serverUrlProblem(url);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
      _notice = null;
    });
    final probe = await probeMantleServer(url);
    if (!mounted) return;
    switch (probe) {
      case ServerProbeUnreachable():
        setState(() {
          _checking = false;
          _error = "Couldn't reach a Mantle server at that URL.";
        });
      case ServerProbeClientApp(:final brainBaseUrl):
        setState(() {
          _checking = false;
          _controller.text = brainBaseUrl;
          _notice =
              "That's the Mantle app address. Its brain is at $brainBaseUrl — "
              'tap Connect to use it.';
        });
      case ServerProbeBrain(:final baseUrl):
        await ref.read(sessionControllerProvider.notifier).setServer(baseUrl);
      // Router redirects to /login once the server is saved.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

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
                  Text('Connect to Mantle', style: theme.textTheme.h2),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the address of your Mantle server.',
                    style: theme.textTheme.muted,
                  ),
                  const SizedBox(height: 24),
                  ShadInput(
                    controller: _controller,
                    placeholder: const Text('https://mantle.example.com'),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enabled: !_checking,
                    onSubmitted: (_) => _connect(),
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
                  if (_notice != null) ...[
                    const SizedBox(height: 8),
                    Text(_notice!, style: theme.textTheme.small),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ShadButton(
                      onPressed: _checking ? null : _connect,
                      child: Text(_checking ? 'Connecting…' : 'Connect'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Or skip the typing: the web app's QR names the server
                  // and signs the phone in.
                  SizedBox(
                    width: double.infinity,
                    child: ShadButton.outline(
                      onPressed: _checking ? null : () => context.push('/scan'),
                      leading: const Icon(LucideIcons.scanLine, size: 16),
                      child: const Text('Scan a sign-in code'),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // What this screen is asking for, for someone who has never
                  // heard of Mantle: it is software you run, not an account
                  // with us. The demo fills the field; the site opens outside.
                  Text(
                    'Mantle is free, open-source software you run yourself. '
                    'No server yet? Try the demo.',
                    style: theme.textTheme.muted,
                  ),
                  const SizedBox(height: 4),
                  // Wrap, not Row: on a narrow phone the two links stack.
                  Wrap(
                    spacing: 16,
                    children: [
                      ShadButton.link(
                        padding: EdgeInsets.zero,
                        onPressed: _checking
                            ? null
                            : () => setState(() {
                                _controller.text = _demoServerUrl;
                                _error = null;
                                _notice = null;
                              }),
                        child: const Text('Use the demo server'),
                      ),
                      ShadButton.link(
                        padding: EdgeInsets.zero,
                        onPressed: () => launchUrl(
                          Uri.parse(_mantleSiteUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: const Text('About Mantle'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
