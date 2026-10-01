#!/usr/bin/env bash
#
# check_push_text_swift.sh: run the iOS extension's PushText (the Swift twin
# of lib/data/push/push_text.dart) against the same cases the Dart test holds
# in test/data/push_text_test.dart. On iOS the Notification Service Extension
# draws the notification and no Dart runs, so the two must agree. macOS only
# (it needs swiftc).
#
#   tool/check_push_text_swift.sh
#
set -euo pipefail
cd "$(dirname "$0")/.."

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The enum alone: the extension class around it needs UserNotifications.
{
  echo 'import Foundation'
  sed -n '/^\/\/ BEGIN PushText$/,/^\/\/ END PushText$/p' \
    ios/NotificationService/NotificationService.swift
} > "$work/PushText.swift"

cat > "$work/main.swift" <<'SWIFT'
import Foundation

var failed = 0
func check(_ input: String, _ want: String, _ got: String) {
  if got != want {
    failed += 1
    print("FAIL  in:   \(input)\n      want: \(want)\n      got:  \(got)")
  }
}
func plain(_ md: String, _ want: String) { check(md, want, PushText.clean(md)) }

plain("## Plan for today\n\n- Call the supplier\n- [x] Send the quote\n1. Review",
      "Plan for today Call the supplier Send the quote Review")
plain("**Done.** I _moved_ the *two* files and ~~kept~~ dropped `tmp.txt`.",
      "Done. I moved the two files and kept dropped tmp.txt.")
plain("set max_retry_count to 3 * 4", "set max_retry_count to 3 * 4")
plain("See [the release notes](https://example.com/notes) and ![chart](media:abc).",
      "See the release notes and chart.")
plain("Before ![](media:abc) after", "Before after")
plain("Filed under [Acme Corp](page:9f3c2d10) by [Thabo](mention:entity:77).",
      "Filed under Acme Corp by Thabo.")
plain("[Folder index](folder:here)", "Folder index")
plain("Run this:\n```bash\npnpm verify\n```\nthen push.", "Run this: pnpm verify then push.")
plain("| Item | Cost |\n| --- | ---: |\n| Paint | 120 |", "Item Cost Paint 120")
plain("> Quoted line\n\n---\n\nAfter", "Quoted line After")
plain("Area is $\\pi r^2$ and $$E=mc^2$$.", "Area is \\pi r^2 and E=mc^2 .")
plain("It costs $5 and $6.50 in total.", "It costs $5 and $6.50 in total.")
plain(":::warning\nCheck the ==due date== and the [total]{color=chart-2}.\n:::",
      "Check the due date and the total.")
plain("Here is the plan. ## Next steps - **Call** the supplier - Send `quote.pdf`",
      "Here is the plan. Next steps - Call the supplier - Send quote.pdf")
plain("| Item | Cost | | --- | --- | | Paint | 120 |", "Item Cost Paint 120")
plain("All set. See [the plan](page:9f3c2d", "All set. See the plan")
plain("All set, and **this part is impor", "All set, and this part is impor")
plain("Use `flutter build ap", "Use flutter build ap")
plain("2 \\* 3 is not \\*emphasis\\*", "2 * 3 is not *emphasis*")
plain("Lunch is at 12:30, table for 4 - see you there!",
      "Lunch is at 12:30, table for 4 - see you there!")

check("title", "Saskia", PushText.title("**Saskia**"))
check("blank title", PushText.defaultTitle, PushText.title("  "))
check("nil body", PushText.defaultBody, PushText.body(nil))
check("blank body", PushText.defaultBody, PushText.body(" \n\t "))
check("body",
      "Done I filed it under Acme Corp and sent quote.pdf.",
      PushText.body("## Done\n\nI filed it under [Acme Corp](page:9f3c2d10) and sent `quote.pdf`."))
let long = PushText.body("**" + String(repeating: "x", count: 200) + "**")
check("cut length", "140", String(long.count))
check("cut ends with an ellipsis", "true", String(long.hasSuffix("\u{2026}")))
check("cut starts with the words", "true", String(long.hasPrefix("x")))

if failed > 0 {
  print("\(failed) case(s) failed")
  exit(1)
}
print("PushText (Swift) agrees with the Dart cases")
SWIFT

swiftc -O -o "$work/check" "$work/PushText.swift" "$work/main.swift"
"$work/check"
