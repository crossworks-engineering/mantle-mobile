/// What a push notification says. Pure, so it is unit-tested; both the FCM
/// path (sealed `t`/`b` payload) and the direct-connection path (SSE + REST)
/// go through it.
library;

const pushDefaultTitle = 'Mantle';
const pushDefaultBody = 'You have a new message.';

/// Title and body for a push, with a fallback when a field is missing OR
/// blank. Blank matters: a server that pushes on the reply's pending insert
/// (before migration 0156) seals an empty teaser, and an empty body under
/// the agent's name reads as a broken notification.
///
/// Both are reduced to plain words first ([plainFromMarkdown]): a reply is
/// markdown, and a brain that cuts its teaser without stripping it sends
/// `**Done.** See [the plan](page:…)` to the lock screen. Then whitespace
/// collapses to one space and the body is cut to [maxBody] with an ellipsis,
/// so an oversized or multi-line teaser still fits one notification line.
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
  return plainFromMarkdown(value).replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Markdown reduced to the words a person would read aloud: no emphasis
/// marks, no heading or list markers, a link as its text, an image as its
/// alt text, a table as its cells, code without its fences.
///
/// It has to work on TWO shapes of input. The direct-connection path hands it
/// the whole reply, newlines and all. The sealed teaser arrives already
/// flattened to one line and cut at 140 characters by the brain, so a block
/// marker can sit mid-line (`Intro ## Plan - one`) and the cut can land
/// inside a token (`[the plan](page:9f3`). Hence: line rules run where there
/// are lines, mid-line heading marks are removed too, and a link or image the
/// cut left unclosed still yields its label.
///
/// Mirrored in Swift for the iOS Notification Service Extension (`PushText`
/// in `ios/NotificationService/NotificationService.swift`), which draws the
/// notification itself. `tool/check_push_text_swift.sh` runs the Swift twin
/// against the cases in `test/data/push_text_test.dart`; change both together.
String plainFromMarkdown(String input) {
  // A backslash escape is the character it protects. Park each one out of
  // reach (a private-use code point) so no rule below reads it as a mark,
  // and put the characters back at the end.
  var s = input.replaceAllMapped(
    RegExp(r'\\([\\`*_{}\[\]()#+\-.!|>~$=])'),
    (m) => String.fromCharCode(_parked + m[1]!.codeUnitAt(0)),
  );

  // Code fences: keep the code, drop the fence and its language tag.
  s = s.replaceAll(RegExp(r'```[\w+-]*[ \t]*\n?'), ' ');
  // Mantle's container fences (`:::info`, `:::aside chart-2`, `:::`) and the
  // column separator.
  s = s.replaceAll(RegExp(r':::[a-z]*(?:[ \t]+chart-\d+)?'), ' ');
  s = s.replaceAll(RegExp(r'^\s*\+\+\+\s*$', multiLine: true), ' ');

  // Images, then links and reference chips (`[label](page:<id>)`): the alt
  // text or the label. A target cut off by the teaser's length still counts.
  s = s.replaceAllMapped(
    RegExp(r'!\[([^\]]*)\]\([^)]*(?:\)|$)'),
    (m) => m[1]!,
  );
  s = s.replaceAllMapped(
    RegExp(r'\[([^\]]*)\]\([^)]*(?:\)|$)'),
    (m) => m[1]!,
  );
  // Mantle's coloured and highlighted spans: `[text]{color=chart-2}`.
  s = s.replaceAllMapped(RegExp(r'\[([^\]]*)\]\{[^}]*\}'), (m) => m[1]!);
  s = s.replaceAllMapped(RegExp(r'==(?=\S)(.+?)(?<=\S)=='), (m) => m[1]!);

  // Line-leading block marks, where the text still has lines.
  s = s.replaceAll(
    RegExp(r'^[ \t]*(?:[-*_][ \t]*){3,}$', multiLine: true),
    ' ',
  ); // rule
  s = s.replaceAll(
    RegExp(r'^[ \t]*\|?[ \t]*:?-{2,}:?[ \t]*(?:\|[ \t]*:?-{2,}:?[ \t]*)*\|?[ \t]*$',
        multiLine: true),
    ' ',
  ); // table separator row
  s = s.replaceAll(RegExp(r'^[ \t]{0,3}>[ \t]?', multiLine: true), '');
  s = s.replaceAll(
    RegExp(r'^[ \t]*(?:[-*+]|\d+[.)])[ \t]+(?:\[[ xX]\][ \t]+)?', multiLine: true),
    '',
  );
  // Heading marks, at a line start or mid-line in a flattened teaser.
  s = s.replaceAllMapped(
    RegExp(r'(^|\s)#{1,6}[ \t]+(?=\S)', multiLine: true),
    (m) => m[1]!,
  );
  // What is left of a flattened table: separator cells and the pipes.
  s = s.replaceAll(RegExp(r'(?<=^|[\s|]):?-{3,}:?(?=$|[\s|])'), ' ');
  s = s.replaceAll('|', ' ');

  // Math: `$$…$$` and `$…$` keep their source. The inline form uses the
  // renderer's guards so "costs $5 and $6" stays as written.
  s = s.replaceAll(r'$$', ' ');
  s = s.replaceAllMapped(
    RegExp(r'\$(?!\s)([^$\n]*?[^\s$])\$(?!\d)'),
    (m) => RegExp(r'[A-Za-z\\^_]').hasMatch(m[1]!) ? m[1]! : m[0]!,
  );

  // Emphasis and inline code: the words without the marks. Bold before
  // italic, so `**a**` is not read as two empty italics.
  s = s.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m[1]!);
  s = s.replaceAllMapped(RegExp(r'(?<!\w)__(.+?)__(?!\w)'), (m) => m[1]!);
  s = s.replaceAllMapped(RegExp(r'~~(.+?)~~'), (m) => m[1]!);
  s = s.replaceAllMapped(
    RegExp(r'(?<![\w*])\*(?=\S)([^*\n]+?)(?<=\S)\*(?![\w*])'),
    (m) => m[1]!,
  );
  s = s.replaceAllMapped(
    RegExp(r'(?<!\w)_(?=\S)([^_\n]+?)(?<=\S)_(?!\w)'),
    (m) => m[1]!,
  );
  // Marks the cut left without their pair.
  s = s.replaceAll('**', '').replaceAll('~~', '').replaceAll('`', '');

  return s.replaceAllMapped(
    RegExp('[\\u{E000}-\\u{E07F}]', unicode: true),
    (m) => String.fromCharCode(m[0]!.codeUnitAt(0) - _parked),
  );
}

/// Where an escaped character waits while the marks are removed: the start
/// of the private-use area, offset by the character's own code.
const _parked = 0xE000;
