import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// The one way the app asks before doing something it cannot undo: a
/// `ShadDialog.alert` with a plain Cancel and a red action, the action named
/// by its verb ("Delete", "Reject", "Sign out"). Resolves true only when the
/// person tapped the action.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String description,
  required String action,
}) async {
  final confirmed = await showShadDialog<bool>(
    context: context,
    builder: (ctx) => ShadDialog.alert(
      title: Text(title),
      description: Text(description),
      actions: [
        ShadButton.outline(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        ShadButton.destructive(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// The same ask for something that can be undone but should not happen
/// unseen (filing a note where the team can read it): a plain Cancel and a
/// primary action.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String description,
  required String action,
}) async {
  final confirmed = await showShadDialog<bool>(
    context: context,
    builder: (ctx) => ShadDialog.alert(
      title: Text(title),
      description: Text(description),
      actions: [
        ShadButton.outline(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        ShadButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return confirmed == true;
}
