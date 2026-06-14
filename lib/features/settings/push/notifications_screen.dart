import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../data/push/push_api.dart';
import '../../../widgets/mantle_header.dart';
import 'push_controller.dart';

/// Settings → Notifications. One-tap Connect enrolls this device for end-to-end
/// encrypted push (Mantle Push). Shows connection status, the enrolled device
/// list, and Disconnect.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String? _busyLabel; // non-null while an action is in flight

  Future<void> _connect() async {
    setState(() => _busyLabel = 'Connecting…');
    await ref.read(pushControllerProvider.notifier).connect();
    if (mounted) setState(() => _busyLabel = null);
  }

  Future<void> _disconnect() async {
    setState(() => _busyLabel = 'Disconnecting…');
    await ref.read(pushControllerProvider.notifier).disconnect();
    if (mounted) setState(() => _busyLabel = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final state = ref.watch(pushControllerProvider);
    final value = state.value;
    final connected = value?.isConnected ?? false;
    final busy = _busyLabel != null;
    final error = state.hasError ? _messageFor(state.error) : null;

    return Container(
      color: scheme.background,
      child: Column(
        children: [
          MantleHeader(
            leading: const MantleHeaderTitle('Notifications', wordmark: false),
            trailing: [
              ShadButton.ghost(
                onPressed: () => context.pop(),
                child: Icon(LucideIcons.arrowLeft, size: 20, color: scheme.primaryForeground),
              ),
            ],
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text('Push notifications', style: theme.textTheme.small),
                  const SizedBox(height: 8),
                  ShadCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              connected ? LucideIcons.bellRing : LucideIcons.bellOff,
                              size: 18,
                              color: connected ? scheme.primary : scheme.mutedForeground,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              connected ? 'This device is connected' : 'Not connected',
                              style: theme.textTheme.p,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Get notified when your assistant reaches out while the app is '
                          'closed. Notifications are end-to-end encrypted — the relay '
                          'can’t read them.',
                          style: theme.textTheme.muted,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: connected
                              ? ShadButton.outline(
                                  onPressed: busy ? null : _disconnect,
                                  leading: const Icon(LucideIcons.bellOff, size: 16),
                                  child: Text(_busyLabel ?? 'Disconnect this device'),
                                )
                              : ShadButton(
                                  onPressed: busy ? null : _connect,
                                  leading: const Icon(LucideIcons.bell, size: 16),
                                  child: Text(_busyLabel ?? 'Connect'),
                                ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            error,
                            style: theme.textTheme.small.copyWith(color: scheme.destructive),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if ((value?.devices ?? const []).isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Enrolled devices', style: theme.textTheme.small),
                    const SizedBox(height: 8),
                    ShadCard(
                      child: Column(
                        children: [
                          for (final d in value!.devices) _DeviceRow(theme: theme, device: d),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _messageFor(Object? error) {
    if (error is PushException) return error.message;
    return 'Something went wrong setting up notifications. Please try again.';
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.theme, required this.device});

  final ShadThemeData theme;
  final PushDevice device;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final icon = device.platform == 'android' ? LucideIcons.smartphone : LucideIcons.tabletSmartphone;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.mutedForeground),
          const SizedBox(width: 12),
          Expanded(child: Text(device.label ?? device.platform, style: theme.textTheme.p)),
        ],
      ),
    );
  }
}
