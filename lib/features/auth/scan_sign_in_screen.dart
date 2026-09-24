import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/auth/auth_api.dart';
import '../../data/auth/pairing_payload.dart';
import '../../widgets/mantle_header.dart';
import 'session_controller.dart';

/// Sign in by pointing the camera at the QR the web app shows under Settings
/// → Logins → "Sign in on your phone". The code names the brain and carries
/// a one-time pairing code ([PairingPayload]); a scan sets the server and
/// claims the code for a bearer, so a fresh install lands on Home with
/// nothing typed. Reachable from both the server-setup and sign-in screens.
///
/// A code that is not ours keeps the camera running and says so; a refused
/// code (expired, used, wrong brain) shows the server's one generic line with
/// a way to scan again. The camera stops the moment a code is being claimed
/// so a second frame cannot claim twice.
class ScanSignInScreen extends ConsumerStatefulWidget {
  const ScanSignInScreen({super.key});

  @override
  ConsumerState<ScanSignInScreen> createState() => _ScanSignInScreenState();
}

class _ScanSignInScreenState extends ConsumerState<ScanSignInScreen> {
  final _scanner = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _claiming = false;
  String? _error;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_claiming) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    if (raw.isEmpty) return;
    final payload = PairingPayload.parse(raw);
    if (payload == null) {
      setState(() => _error = "That's not a Jackdaw sign-in code.");
      return;
    }
    setState(() {
      _claiming = true;
      _error = null;
    });
    await _scanner.stop();
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .signInWithPairing(payload);
      // The router redirects to home once the session flips to loggedIn.
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _claiming = false;
        _error = e.message;
      });
      await _scanner.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      color: scheme.background,
      child: Column(
        children: [
          MantleHeader(
            leading: const MantleHeaderTitle(
              'Scan to sign in',
              wordmark: false,
            ),
            trailing: [
              HeaderAction(
                icon: LucideIcons.x,
                label: 'Cancel',
                onPressed: () => context.pop(),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'On the web app, open Settings → Logins → "Sign in on '
                    'your phone" and point the camera at the code.',
                    style: theme.textTheme.muted,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _claiming
                          ? _Notice(theme: theme, text: 'Signing in…')
                          : MobileScanner(
                              controller: _scanner,
                              onDetect: _onDetect,
                              errorBuilder: (context, error) => _Notice(
                                theme: theme,
                                text: _describeCamera(error),
                              ),
                            ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: theme.textTheme.small.copyWith(
                        color: scheme.destructive,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'The code is single-use and expires in about a minute; '
                    'it never contains your password.',
                    style: theme.textTheme.small.copyWith(
                      color: scheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _describeCamera(MobileScannerException error) =>
      switch (error.errorCode) {
        // A refusal is respected, not argued with: say what still works.
        MobileScannerErrorCode.permissionDenied =>
          'Camera access is off, so the code can\'t be scanned here. '
              'You can type the server address and sign in instead.',
        MobileScannerErrorCode.unsupported =>
          'This device has no camera the app can use.',
        _ => "Couldn't start the camera.",
      };
}

/// The camera box's stand-in: a flat accent panel with one line.
class _Notice extends StatelessWidget {
  const _Notice({required this.theme, required this.text});

  final ShadThemeData theme;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Container(
      color: scheme.accent,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.p.copyWith(color: scheme.accentForeground),
      ),
    );
  }
}
