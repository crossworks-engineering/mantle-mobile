import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../data/push/push_api.dart';
import '../../../widgets/mantle_header.dart';
import 'direct_push_controller.dart';
import 'push_controller.dart';
import 'push_prefs_controller.dart';
import 'reminder_channel_controller.dart';

/// Settings → Notifications. One-tap Connect enrolls this device for end-to-end
/// encrypted push (Mantle Push). When connected: per-trigger toggles, the
/// enrolled device list (with unpair), and reset. The reminder-delivery choice
/// (Telegram vs this app) shows regardless of connection.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String? _busyLabel;

  Future<void> _connect() async {
    setState(() => _busyLabel = 'Connecting…');
    // Mutually exclusive with the direct connection — only one transport at a
    // time. The direct connection is an Android-only transport; on iOS its
    // provider isn't watched here, so touching it would auto-dispose mid-async
    // and throw, aborting the whole Connect flow. Only stop it where it exists.
    if (Platform.isAndroid) {
      await ref.read(directPushControllerProvider.notifier).disable();
    }
    await ref.read(pushControllerProvider.notifier).connect();
    if (mounted) setState(() => _busyLabel = null);
  }

  Future<void> _setDirect(bool on) async {
    setState(() => _busyLabel = on ? 'Starting…' : 'Stopping…');
    final direct = ref.read(directPushControllerProvider.notifier);
    if (on) {
      await ref.read(pushControllerProvider.notifier).disconnect(); // mutual exclusion
      await direct.enable();
    } else {
      await direct.disable();
    }
    if (mounted) setState(() => _busyLabel = null);
  }

  Future<void> _disconnect() async {
    setState(() => _busyLabel = 'Disconnecting…');
    await ref.read(pushControllerProvider.notifier).disconnect();
    if (mounted) setState(() => _busyLabel = null);
  }

  Future<void> _unpair(String id) async {
    try {
      await ref.read(pushApiProvider).unsubscribe(id);
    } catch (_) {
      /* ignore — refresh reflects reality */
    }
    ref.invalidate(pushControllerProvider);
  }

  Future<void> _reset() async {
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: const Text('Reset push?'),
        description: const Text(
          'This rolls your push identity and disconnects every device. '
          'You’ll need to Connect again on each one.',
        ),
        actions: [
          ShadButton.outline(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ShadButton.destructive(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busyLabel = 'Resetting…');
    await ref.read(pushControllerProvider.notifier).reset();
    if (mounted) setState(() => _busyLabel = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final state = ref.watch(pushControllerProvider);
    final connected = state.value?.isConnected ?? false;
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
                  _statusCard(theme, connected: connected, busy: busy, error: error),
                  const SizedBox(height: 24),
                  _reminderDeliveryCard(theme),
                  if (Platform.isAndroid) ...[
                    const SizedBox(height: 24),
                    _directCard(theme, busy: busy),
                  ],
                  if (connected) ...[
                    const SizedBox(height: 24),
                    _triggersCard(theme),
                    if ((state.value?.devices ?? const []).isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _devicesCard(theme, state.value!.devices),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ShadButton.outline(
                        onPressed: busy ? null : _reset,
                        leading: const Icon(LucideIcons.rotateCcw, size: 16),
                        child: const Text('Reset push'),
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

  Widget _statusCard(ShadThemeData theme, {required bool connected, required bool busy, String? error}) {
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                  Text(connected ? 'This device is connected' : 'Not connected', style: theme.textTheme.p),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Get notified when your assistant reaches out while the app is closed. '
                'Notifications are end-to-end encrypted — the relay can’t read them.',
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
                Text(error, style: theme.textTheme.small.copyWith(color: scheme.destructive)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _directCard(ShadThemeData theme, {required bool busy}) {
    final on = ref.watch(directPushControllerProvider).value ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Without Google Play', style: theme.textTheme.small),
        const SizedBox(height: 8),
        ShadCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Direct connection', style: theme.textTheme.p)),
                  ShadSwitch(value: on, onChanged: busy ? null : _setDirect),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Keeps a connection to your Mantle open in the background, so you get '
                'notifications without Google services. Shows a persistent “connected” '
                'notification and uses a little more battery. An alternative to Connect.',
                style: theme.textTheme.muted,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _triggersCard(ShadThemeData theme) {
    final prefs = ref.watch(pushPrefsControllerProvider).value;
    final notifier = ref.read(pushPrefsControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notify me about', style: theme.textTheme.small),
        const SizedBox(height: 8),
        ShadCard(
          child: Column(
            children: [
              _SwitchRow(
                theme: theme,
                label: 'Assistant messages',
                value: prefs?.assistantMessages ?? true,
                onChanged: prefs == null ? null : (v) => notifier.save({'assistantMessages': v}),
              ),
              _SwitchRow(
                theme: theme,
                label: 'Approvals',
                value: prefs?.approvals ?? true,
                onChanged: prefs == null ? null : (v) => notifier.save({'approvals': v}),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reminderDeliveryCard(ShadThemeData theme) {
    final selected = ref.watch(reminderChannelControllerProvider).value;
    final notifier = ref.read(reminderChannelControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Event reminders', style: theme.textTheme.small),
        const SizedBox(height: 8),
        ShadCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReminderOption(
                theme: theme,
                icon: LucideIcons.send,
                label: 'Telegram',
                selected: selected == 'telegram',
                // Disabled until the current value loads, so a tap can't race it.
                onTap: selected == null ? null : () => notifier.select('telegram'),
              ),
              _ReminderOption(
                theme: theme,
                icon: LucideIcons.smartphone,
                label: 'This app',
                selected: selected == 'mobile',
                onTap: selected == null ? null : () => notifier.select('mobile'),
              ),
              const SizedBox(height: 8),
              Text(
                'Where event reminders are delivered. Follows whichever you last '
                'messaged from; pick one to keep it there. Reminders to this app '
                'need notifications connected above to alert you.',
                style: theme.textTheme.muted,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _devicesCard(ShadThemeData theme, List<PushDevice> devices) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Enrolled devices', style: theme.textTheme.small),
        const SizedBox(height: 8),
        ShadCard(
          child: Column(
            children: [for (final d in devices) _DeviceRow(theme: theme, device: d, onUnpair: () => _unpair(d.id))],
          ),
        ),
      ],
    );
  }

  String _messageFor(Object? error) {
    if (error is PushException) return error.message;
    return 'Something went wrong setting up notifications. Please try again.';
  }
}

class _ReminderOption extends StatelessWidget {
  const _ReminderOption({
    required this.theme,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ShadThemeData theme;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: scheme.mutedForeground),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: theme.textTheme.p)),
            if (selected) Icon(LucideIcons.check, size: 18, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.theme, required this.label, required this.value, required this.onChanged});

  final ShadThemeData theme;
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.p)),
          ShadSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.theme, required this.device, required this.onUnpair});

  final ShadThemeData theme;
  final PushDevice device;
  final VoidCallback onUnpair;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final icon = device.platform == 'android' ? LucideIcons.smartphone : LucideIcons.tabletSmartphone;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.mutedForeground),
          const SizedBox(width: 12),
          Expanded(child: Text(device.label ?? device.platform, style: theme.textTheme.p)),
          ShadButton.ghost(
            onPressed: onUnpair,
            child: Icon(LucideIcons.trash2, size: 16, color: scheme.mutedForeground),
          ),
        ],
      ),
    );
  }
}
