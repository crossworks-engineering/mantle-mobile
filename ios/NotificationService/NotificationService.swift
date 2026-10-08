import Foundation
import UserNotifications

/// Notification Service Extension — intercepts every `mutable-content` push,
/// decrypts the libsodium sealed box carried in `ct`, and rewrites the visible
/// title/body. The plaintext never touches APNs or the relay; only this
/// extension (holding the device secret key from the shared Keychain) can open
/// it. See ios/PUSH_SETUP.md.
class NotificationService: UNNotificationServiceExtension {
  private var contentHandler: ((UNNotificationContent) -> Void)?
  private var bestAttempt: UNMutableNotificationContent?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    let mutable = request.content.mutableCopy() as? UNMutableNotificationContent
    bestAttempt = mutable

    guard let content = mutable else {
      contentHandler(request.content)
      return
    }

    if let ct = request.content.userInfo["ct"] as? String,
       let plaintext = PushCrypto.openSealed(ciphertextBase64: ct),
       let json = try? JSONSerialization.jsonObject(with: plaintext) as? [String: Any] {
      // Plain words, with the same fallbacks as the Android paths: a reply is
      // markdown, and a blank teaser must not show as an empty notification.
      content.title = PushText.title(json["t"] as? String)
      content.body = PushText.body(json["b"] as? String)
      // Carry what a tap needs through to the app: the link, the item the
      // push is about, and the brain and login it was sealed for.
      var info = content.userInfo
      for key in ["deepLink", "itemLink", "brainId", "loginId"] {
        if let value = json[key] as? String { info[key] = value }
      }
      content.userInfo = info
    } else {
      // Couldn't decrypt — show a generic, non-leaky fallback.
      content.title = PushText.defaultTitle
      content.body = PushText.defaultBody
    }

    contentHandler(content)
  }

  override func serviceExtensionTimeWillExpire() {
    // Called just before the extension is killed — deliver our best attempt.
    if let handler = contentHandler, let content = bestAttempt {
      handler(content)
    }
  }
}

// BEGIN PushText
/// What a push notification says, in plain words. The Swift twin of
/// `lib/data/push/push_text.dart` (`pushNotificationText`,
/// `plainFromMarkdown`): the same rules in the same order, because on iOS
/// this extension draws the notification and the Dart code never runs.
/// `tool/check_push_text_swift.sh` runs it against the Dart test's cases.
enum PushText {
  static let defaultTitle = "Mantle"
  static let defaultBody = "You have a new message."

  static func title(_ raw: String?) -> String {
    let t = clean(raw)
    return t.isEmpty ? defaultTitle : t
  }

  /// The cut counts graphemes (`String.count`), as the Dart side does with
  /// `characters`, so an emoji is never cut in half.
  static func body(_ raw: String?, max: Int = 140) -> String {
    let b = clean(raw)
    if b.isEmpty { return defaultBody }
    if b.count <= max { return b }
    return String(b.prefix(max - 1)) + "\u{2026}"
  }

  /// How much of a message the rules below ever read, in Unicode scalars.
  /// Some rules are quadratic on input they cannot match, so a long reply is
  /// cut first. Scalars, as the Dart side (`runes`), so both cut alike.
  static let inputLimit = 2000

  static func head(_ s: String) -> String {
    if s.unicodeScalars.count <= inputLimit { return s }
    var out = String.UnicodeScalarView()
    out.append(contentsOf: s.unicodeScalars.prefix(inputLimit))
    return String(out)
  }

  /// A word character in any script: a letter, a combining mark, a decimal
  /// digit or `_`. Spelled out, not `\w`, because ICU's `\w` and Dart's
  /// differ (Dart's is ASCII); this class means the same in both.
  private static let word = "\\p{L}\\p{M}\\p{Nd}_"

  /// Plain words on one line: markdown removed, whitespace collapsed.
  static func clean(_ raw: String?) -> String {
    guard let raw = raw else { return "" }
    return sub(plain(raw), "\\s+", " ").trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Where an escaped character waits while the marks are removed.
  private static let parked: UInt32 = 0xE000

  /// Markdown reduced to the words a person would read aloud. Works on a
  /// whole reply (with lines) and on a teaser the brain already flattened to
  /// one line and cut, where a block mark can sit mid-line and a link can be
  /// left unclosed.
  static func plain(_ input: String) -> String {
    // A backslash escape is the character it protects: park it out of reach.
    var s = map(head(input), "\\\\([\\\\`*_{}\\[\\]()#+\\-.!|>~$=])") { groups in
      guard let c = groups[1].unicodeScalars.first,
            let p = Unicode.Scalar(parked + c.value) else { return groups[0] }
      return String(Character(p))
    }

    // Code fences, Mantle's container fences and the column separator.
    s = sub(s, "```[\(word)+-]*[ \\t]*\\n?", " ")
    s = sub(s, ":::[a-z]*(?:[ \\t]+chart-\\d+)?", " ")
    s = sub(s, "^\\s*\\+\\+\\+\\s*$", " ", lines: true)

    // Images, links and reference chips: the alt text or the label. A
    // target the cut left unclosed still counts.
    s = sub(s, "!\\[([^\\]]*)\\]\\([^)]*(?:\\)|$)", "$1")
    s = sub(s, "\\[([^\\]]*)\\]\\([^)]*(?:\\)|$)", "$1")
    s = sub(s, "\\[([^\\]]*)\\]\\{[^}]*\\}", "$1")
    s = sub(s, "==(?=\\S)(.+?)(?<=\\S)==", "$1")

    // Line-leading block marks, where the text still has lines.
    s = sub(s, "^[ \\t]*(?:[-*_][ \\t]*){3,}$", " ", lines: true)
    s = sub(
      s,
      "^[ \\t]*\\|?[ \\t]*:?-{2,}:?[ \\t]*(?:\\|[ \\t]*:?-{2,}:?[ \\t]*)*\\|?[ \\t]*$",
      " ",
      lines: true
    )
    s = sub(s, "^[ \\t]{0,3}>[ \\t]?", "", lines: true)
    s = sub(s, "^[ \\t]*(?:[-*+]|\\d+[.)])[ \\t]+(?:\\[[ xX]\\][ \\t]+)?", "", lines: true)
    // Heading marks, at a line start or mid-line in a flattened teaser.
    s = sub(s, "(^|\\s)#{1,6}[ \\t]+(?=\\S)", "$1", lines: true)
    // What is left of a flattened table: separator cells and the pipes.
    s = sub(s, "(?<=^|[\\s|]):?-{3,}:?(?=$|[\\s|])", " ")
    s = s.replacingOccurrences(of: "|", with: " ")

    // Math keeps its source; the inline form uses the renderer's guards so
    // "costs $5 and $6" stays as written.
    s = s.replacingOccurrences(of: "$$", with: " ")
    s = map(s, "\\$(?!\\s)([^$\\n]*?[^\\s$])\\$(?!\\d)") { groups in
      groups[1].range(of: "[A-Za-z\\\\^_]", options: .regularExpression) != nil
        ? groups[1] : groups[0]
    }

    // Emphasis and inline code: the words without the marks.
    s = sub(s, "\\*\\*(.+?)\\*\\*", "$1")
    s = sub(s, "(?<![\(word)])__(.+?)__(?![\(word)])", "$1")
    s = sub(s, "~~(.+?)~~", "$1")
    s = sub(s, "(?<![\(word)*])\\*(?=\\S)([^*\\n]+?)(?<=\\S)\\*(?![\(word)*])", "$1")
    s = sub(s, "(?<![\(word)])_(?=\\S)([^_\\n]+?)(?<=\\S)_(?![\(word)])", "$1")
    // Marks the cut left without their pair.
    s = s.replacingOccurrences(of: "**", with: "")
      .replacingOccurrences(of: "~~", with: "")
      .replacingOccurrences(of: "`", with: "")

    // Put the escaped characters back.
    var out = String.UnicodeScalarView()
    for u in s.unicodeScalars {
      if u.value >= parked, u.value < parked + 0x80,
         let back = Unicode.Scalar(u.value - parked) {
        out.append(back)
      } else {
        out.append(u)
      }
    }
    return String(out)
  }

  private static func regex(_ pattern: String, lines: Bool) -> NSRegularExpression? {
    try? NSRegularExpression(pattern: pattern, options: lines ? [.anchorsMatchLines] : [])
  }

  /// Replace every match of `pattern` with `template` (`$1` is group 1).
  private static func sub(
    _ s: String, _ pattern: String, _ template: String, lines: Bool = false
  ) -> String {
    guard let re = regex(pattern, lines: lines) else { return s }
    return re.stringByReplacingMatches(
      in: s, range: NSRange(s.startIndex..., in: s), withTemplate: template)
  }

  /// Replace every match of `pattern` with what `replace` makes of its
  /// groups (`groups[0]` is the whole match).
  private static func map(
    _ s: String, _ pattern: String, _ replace: ([String]) -> String
  ) -> String {
    guard let re = regex(pattern, lines: false) else { return s }
    let ns = s as NSString
    var out = ""
    var last = 0
    for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
      out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
      var groups: [String] = []
      for i in 0..<m.numberOfRanges {
        let r = m.range(at: i)
        groups.append(r.location == NSNotFound ? "" : ns.substring(with: r))
      }
      out += replace(groups)
      last = m.range.location + m.range.length
    }
    out += ns.substring(from: last)
    return out
  }
}
// END PushText
