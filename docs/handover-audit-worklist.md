# Handover: the audit worklist is done, bar the human item

_Written 2026-09-16 at the end of the session that wrote the audit and did
items 1 to 6; updated 2026-09-17 after items 7 to 11. Item 11 is not
pushed. What remains is item 12, which needs a person and a phone._

> ### Start here
>
> 1. Run the `mantle-recall` skill first (fleet, ssh aliases, the
>    `jackdaw-ui-standards` map). Then this repo's `CLAUDE.md` and
>    `docs/styling-guide.md`; the guide's "Shared conventions" and "Status
>    colours" sections are new and are the rules items 5 and 6 established.
> 2. `fvm flutter analyze && fvm flutter test` — expect clean and **201**
>    passing. A failure before you touch anything is not yours.
> 3. The audit is `docs/audit-2026-09-16.md`; the worklist at its end is the
>    plan. Items 1 to 11 are done (commits `939d982` … `eaaff69`). This file
>    is what the doc does not say: the judgement calls and the traps.

---

## Where things stand

| What                     | State                                                                                                 |
| ------------------------ | ----------------------------------------------------------------------------------------------------- |
| Branch                   | `main`, everything pushed through `585cad6` (item 11 plus a hash fix). Item 10's own run went red on stale generated hashes; the fix is in. Push is Jason's call. |
| Tests                    | 154 → 241. Analyzer clean.                                                                            |
| CI                       | `.github/workflows/verify.yml` exists but has never run (nothing pushed). The Android job uses `tool/ci/google-services.ci.json`; that placeholder was proven to build a release APK locally. |
| Simulator                | An iPhone 17 (iOS 26) on the Mac has the app installed and **signed in to the dev brain**. `fvm flutter build ios --simulator --debug`, then `xcrun simctl install booted build/ios/iphonesimulator/Runner.app` and `xcrun simctl launch booted crossworks.engineering.jackdaw`. The login survives reinstalls. Do NOT sign it out; a session cannot type credentials. |
| Brain                    | Task "Act on the jackdaw-mobile audit" (tag `mantle-roadmap`) has 11 of 12 ticked and a comment per item. Audit page `adcc0b73…` has an uncommitted draft with the scope rule. |
| Owner's scope rule       | No full editors for Pages or complex screens on the phone. Notes is the exception. Formulas, recall, tables, drawing: decide with Jason before any work. |

## Habits this repo expects (the ones that bit)

- `fvm flutter …` always. `fvm dart run build_runner build --delete-conflicting-outputs`
  after any provider change; generated files are committed and CI diffs them.
  Run it **last**, after the final edit to any `@riverpod` class: the
  generated hash covers the class body, so a rename after the run (item 10's
  `update` → `edit`) went red on CI while analyzer and tests were green.
- Commit on `main`, one commit per worklist item, message says *why*. **No
  `Co-Authored-By` trailer, no "Generated with" line.** Never push unasked.
- The style ratchet (`test/style_ratchet_test.dart`) holds five counts at
  zero across `lib/features` and `lib/widgets`: colour literals, numeric
  `fontSize:`, Material imports, hand-rolled dates, inline `ShadDialog.alert`.
  If it fails, fix the code, not the test.
- Every `state =` after an `await` in an autoDispose notifier is guarded with
  `if (ref.mounted)`. No lint can hold this (custom_lint is dropped over an
  analyzer conflict), so read for it.
- Dates go through `lib/core/format/dates.dart`. Confirms go through
  `confirmDestructive`. Header titles through `headerTitleStyle`.
- zsh eats `--include=*.dart` and `===` echo separators; quote the glob, use
  `"---"`.
- The screens are ConsumerStatefulWidgets with no widget tests. Verify visual
  changes on the simulator: the three earlier sessions did, and it caught
  the Journal order bug the reviews had only read.
- **Never run `dart format` on this repo.** The pinned formatter rewrites
  files it touches in the newer style (2-space initializer lists and so
  on), and the tree is not format-clean, so one run dirties eight files
  that are not yours. Match the surrounding style by hand.

## Item 7 is done (`fd581d3`)

What landed, and the choices a later reader might question:

- `lib/features/chat/chat_timeline.dart` holds `startsDay` and `showsTime`
  as pure functions over the oldest-first list; the item builder asks per
  index, so the divider is part of the first message's item and
  `loadMore` / `_mergeLatest` never see it. Tests in
  `test/features/chat_timeline_test.dart`.
- A time shows under a bubble when more than five minutes passed since the
  message before it, or it starts a day. The long-press sheet's title is
  the full stamp (`Yesterday · 15:33`). `formatTime` joined `dates.dart`.
- The jump button is a `GestureDetector` + `Container` (primary +
  primaryForeground, 44pt) with a 3pt halo in `background` and a soft
  shadow: without the halo it vanished into a user bubble of the same
  primary. A reply landing while scrolled up counts on the button; the
  user's own send still follows them down. The count path was not seen on
  the simulator (it needs a reply from elsewhere while scrolled up); the
  logic is `_onMessages` in `chat_screen.dart`.
- Images: server attachments push `/files/image/:id`; a just-sent picture
  pushes `/files/local-image?path=` because the landed inbound row keeps
  only the local preview (`chat_controller.dart:588`, no node id comes
  back). `FileImageScreen` has `.file` and `.local` constructors and a
  Retry that invalidates `fileBytesProvider`. The inline fallback chip is
  tappable too, so a failed fetch can be retried from the full screen.
- The composer takes `agentName`; `agentBySlug(ref, slug)` in
  `chat_screen.dart` is the shared lookup the header now uses as well.

## Item 8 is done (`491c747`)

- The server checked: `POST /api/auth/mobile-login` returns only the token
  and `GET /api/profile` returns preferences plus a user id, no email. So
  the app stores the email typed at sign-in (`SettingsRepository.
  accountEmail`, key `account_email`, lower-cased) and clears it in
  `SessionController._forgetAccountState`, which both sign-out and the 401
  path call. A session from before this build shows no "Signed in as" row
  until the next sign-in; that is by design, not a bug.
- `appVersionProvider` (`lib/core/app_version.dart`, package_info_plus)
  and `serverVersionProvider` (`lib/data/server/server_version.dart`,
  autoDispose so a down server is re-asked when the screen reopens).
- `SessionController.changeServer()` = `signOut()` then `setUrl('')`; the
  gate's `build()` watches the URL and lands on `needsServer`, the router
  does the rest. Tested, including the token-clear failure keeping the
  address.
- Clear cache calls `AppDatabase.clearUserData` (messages + outbox) and
  invalidates the whole `chatControllerProvider` family so an open thread
  reloads. The confirm says the outbox goes.
- Seen on the simulator: the card, both versions, Clear cache end to end,
  the Change server confirm (cancelled, the simulator's sign-in is kept).

## Item 9 is done (`6615253`)

- shadcn_ui 0.54 does allow it: `buttonSizesTheme.regular.height: 44` in
  `lib/theme/mantle_theme.dart` makes every regular `ShadButton` 44pt.
  Icon-only ghost buttons then get their width from padding (composer:
  `horizontal: 11` around a 22 icon).
- `HeaderAction(icon:, label:, onPressed:)` in `lib/widgets/mantle_header.dart`
  replaced the 28 hand-built header ghost buttons. The label goes on the
  `Icon` (`semanticLabel`), because `ShadButton` already announces itself as
  a button but names nothing. Same trick on every other icon-only button.
- Small taps grow by boxing, not by scaling the mark: `SizedBox(44×44,
  Center(icon))` for the done circles and the Pages chevron; a 44-tall
  container for the tag chips in the horizontal lists; **vertical padding**
  for the reminder chips inside a `Wrap`, because a centred box there takes
  the whole row (seen on the simulator, fixed).
- The done-circle rows switched to `CrossAxisAlignment.center` so a 44 box
  and a one- or two-line title sit together; the audit's "Overflow",
  "Safe areas" and "Landscape" bullets were **not** in item 9 and remain.
- Notes and Tasks quick-add rows are now `IntrinsicHeight` +
  `stretch` (the guide's rule), because the 44 button no longer matched the
  input. Journal's composer keeps `end` alignment on purpose: its input
  grows to four lines.
- The alarm rationale is a `ShadSheet` (`_AlarmRationaleSheet` in
  `events_screen.dart`) behind `SettingsRepository.alarmRationaleShown`.
  "Not now" is remembered too. Seen once on the simulator; the OS prompt did
  not follow because the simulator had already granted notifications.

## Item 10 is done (`16afe21`)

- Each edit is a sheet with the fields the list shows, opened by a tap on
  the row (long-press still deletes, in Tasks and Events). `EditTaskSheet`
  in `tasks_screen.dart`; `EventSheet` (add and edit, one widget) in
  `events_screen.dart`; `EntrySheet` in `journal_screen.dart`.
- The controllers' method is `edit`, not `update`: Riverpod 3's
  `AsyncNotifier` already has an `update`, and the analyzer said so.
- PATCH bodies carry only what changed. Tasks re-fetch quietly after an
  edit so the server's due-date order holds; Events re-sort locally and
  re-arm alarms; Journal swaps the row in place (its date does not move).
- Journal's model gained `kind`, `status`, `author`, `agentSlug`. An open
  gap shows a warning dot + "Open question" (fills only, per the guide)
  and its sheet takes an answer, posting to `/api/journal/{id}/resolve`.
  Not seen on the simulator: the dev brain had no open question at the
  time; the controller path is unit-tested (`answerGap`).
- `ChoicePill` (`lib/widgets/choice_pill.dart`) replaced the three chip
  copies. Notes' and Search's horizontal lists are 44 tall to match.
- Seen on the simulator with throwaway rows, then deleted: task edit (due
  date + priority land in the row), event edit (the reminder change lands;
  the "Just a test event" on the dev brain now carries a 5-minute lead),
  journal edit and delete.
- The time picker is `ShadTimePicker` (hours + minutes, 24h). It replaced
  the HH:MM text box in the event sheet; no parsing remains.

## Item 11 is done (`eaaff69`)

- `test/helpers/pump_screen.dart` is how a screen gets a widget test: pass
  a `ProviderContainer` (its overrides are typed where they are written;
  flutter_riverpod does not re-export `Override`), and the helper wraps
  the screen in `MantleColors` + `ShadApp(home:)` with a tall phone-width
  view. Lazy lists only build what is on screen, so without the tall view
  a Settings row below the fold is simply not there.
- A `ShadSheet` builds only inside a sheet route (`ShadSheetInheritedWidget`
  null-checks). Test a sheet by opening it through `showShadSheet` from a
  tiny host widget, as `journal_entry_sheet_test.dart` does.
- `JournalScreen` owns an `AudioRecorder`, whose constructor starts a
  platform call; it has no widget test for that reason. Its sheet does.
- `EventAlarms` gained `plannedAlarms` (pure) and `pluginForTesting`; the
  reconcile is tested against a mocked plugin. `PushDecryptor` is tested
  with `Sodium`, `Crypto`, `Box`, `SecureKey` and `FlutterSecureStorage`
  all mocked; libsodium itself is never loaded in tests.
- Still uncovered, and known: the Dio auth interceptor's full path, deep
  links end to end, the direct-push Android handler, the location service,
  the theme controllers.

## Item 12 is Jason's

The Android device pass, real-device push and alarm, the software keyboard
on the four capture screens, and the `pub outdated` decision (117 held
back, the file_picker pin). None of it can be done from a simulator.

## Two judgement calls to inherit

- **Item 5 dropped the script face from the chat header.** The agent name
  was set in BukhariScript at 24; now it is the same `h4` every sub-screen
  uses. The wordmark keeps the script. Jason has seen the screenshot and
  did not object; if it comes up, the reason is one header style, and the
  script face reads as a brand mark, which an agent name is not.
- **Status colours are one set for all 43 themes.** Neither shadcn nor the
  web's `globals.css` carries `success`/`warning`/`info` tokens (checked:
  zero matches), so per-theme values do not exist to port. They live in
  `lib/theme/mantle_theme.dart` as `MantleColors.success(brightness)` etc.
  The theme generator (`tool/generate_themes.dart`) still points at the
  pre-split path `~/Projects/mantle/apps/web`; the sources now live in the
  jackdaw repo under `client/web/app/globals.css` and
  `packages/web-ui/src/lib/themes.ts`. Fix the path before regenerating.

## Verify quickly

```bash
cd ~/Projects/jackdaw-mobile && fvm flutter analyze && fvm flutter test
git log --oneline -19  # eaaff69 test: alarms … fd98307 docs: audit
```
