/// What a push notification says. Pure, so it is unit-tested; both the FCM
/// path (sealed `t`/`b` payload) and the direct-connection path (SSE + REST)
/// go through it.
library;

const pushDefaultTitle = 'Mantle';
const pushDefaultBody = 'You have a new message.';

/// Title and body for a push, with a fallback when a field is missing OR
/// blank. Blank matters: a server that pushes on the reply's pending insert
/// (before migration 0156) seals an empty teaser, and an empty body under
/// the agent's name reads as a broken notification. Whitespace collapses to
/// one space and the body is cut to [maxBody] with an ellipsis, so an
/// oversized or multi-line teaser still fits one notification line.
({String title, String body}) pushNotificationText(
  Map<String, dynamic> payload, {
  int maxBody = 140,
}) {
  final title = _clean(payload['t']);
  final body = _clean(payload['b']);
  return (
    title: title.isEmpty ? pushDefaultTitle : title,
    body: body.isEmpty
        ? pushDefaultBody
        : body.length > maxBody
            ? '${body.substring(0, maxBody - 1)}…'
            : body,
  );
}

String _clean(Object? value) {
  if (value is! String) return '';
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}
