import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../widgets/jackdaw_lockup.dart';

import '../../data/server/server_config.dart';
import 'session_controller.dart';

/// First-run screen: which Mantle server are we talking to? Validates the URL
/// by hitting the public `GET /api/version` before saving it.
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
    final url = _controller.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Enter your Mantle server URL.');
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
