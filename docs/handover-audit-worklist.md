# Handover: the audit worklist, items 7 to 11

_Written 2026-09-16 at the end of the session that wrote the audit and did
items 1 to 6. Nothing is pushed. Pick up here._

> ### Start here
>
> 1. Run the `mantle-recall` skill first (fleet, ssh aliases, the
>    `jackdaw-ui-standards` map). Then this repo's `CLAUDE.md` and
>    `docs/styling-guide.md`; the guide's "Shared conventions" and "Status
>    colours" sections are new and are the rules items 5 and 6 established.
> 2. `fvm flutter analyze && fvm flutter test` — expect clean and **201**
>    passing. A failure before you touch anything is not yours.
> 3. The audit is `docs/audit-2026-09-16.md`; the worklist at its end is the
>    plan. Items 1 to 6 are done (commits `939d982` … `264aa28`). This file
>    is what the doc does not say: the judgement calls, the traps, and where
>    item 7 starts.

---

## Where things stand

| What                     | State                                                                                                 |
| ------------------------ | ----------------------------------------------------------------------------------------------------- |
| Branch                   | `main`, eight commits ahead of origin, **not pushed**. Push is Jason's call; it also runs CI for the first time. |
| Tests                    | 154 → 201. Analyzer clean.                                                                            |
| CI                       | `.github/workflows/verify.yml` exists but has never run (nothing pushed). The Android job uses `tool/ci/google-services.ci.json`; that placeholder was proven to build a release APK locally. |
| Simulator                | An iPhone 17 (iOS 26) on the Mac has the app installed and **signed in to the dev brain**. `fvm flutter build ios --simulator --debug`, then `xcrun simctl install booted build/ios/iphonesimulator/Runner.app` and `xcrun simctl launch booted crossworks.engineering.jackdaw`. The login survives reinstalls. Do NOT sign it out; a session cannot type credentials. |
| Brain                    | Task "Act on the jackdaw-mobile audit" (tag `mantle-roadmap`) has 6 of 12 ticked and a comment per item. Audit page `adcc0b73…` has an uncommitted draft with the scope rule. |
| Owner's scope rule       | No full editors for Pages or complex screens on the phone. Notes is the exception. Formulas, recall, tables, drawing: decide with Jason before any work. |

## Habits this repo expects (the ones that bit)

- `fvm flutter …` always. `fvm dart run build_runner build --delete-conflicting-outputs`
  after any provider change; generated files are committed and CI diffs them.
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

## Item 7: chat timestamps, date grouping, scroll-to-bottom, image full-screen, the placeholder

All in `lib/features/chat/`. Anchors as of `264aa28`:

- **Placeholder.** `chat_composer.dart:355` reads `'Message Mantle…'`. The
  composer is built at `chat_screen.dart:225` with `provider` and
  `textController` only; the screen already has the agent name at
  `chat_screen.dart:242-253` (`agents` from `agentControllerProvider`,
  `agent?.name ?? agentSlug`). Pass the name in and say
  `'Message <name>…'`. Smallest change on the list; do it first.
- **Timestamps and date grouping.** `_Bubble` (`chat_screen.dart:304`) never
  renders `createdAt`. The list is `ListView.builder(reverse: true)` at
  `:132`, so index 0 is the newest message. Two things the web does:
  a day divider when the day changes between neighbours (use `formatDay`
  from `core/format/dates.dart`, which already gives "Today" / "Yesterday"
  / "Fri 18 Sep"), and a time under a bubble when the gap to the previous
  message is more than a few minutes, or on long-press. Keep the time in
  `theme.textTheme.muted`; the ratchet forbids a smaller size. In a reversed
  list the divider belongs *above* the first message of a day, which is the
  item with the higher index; build the divider into the item builder, not
  as separate list entries, or `loadMore`'s merge and the queued-bubble
  ordering (`chat_controller.dart`, `_mergeLatest`) will have to know about
  it.
- **Scroll-to-bottom.** `_scroll` (`chat_screen.dart:33`) already drives
  `_onScroll` for paging older history at the far end. Show a small round
  button (primary + primaryForeground, 44pt, bottom-right above the
  composer) when `_scroll.position.pixels > ~300` in the reversed list, and
  animate to `0`. Bonus that matters: when a new outbound message lands
  while scrolled up, show an unread count on it instead of yanking the list.
- **Image full-screen.** `attachment_view.dart:33-50` renders local images
  (`Image.file`) and `:183-200` renders server ones (`Image.memory` from
  `fileBytesProvider`) with no tap handler. The route
  `/files/image/:id?name=` already exists (`app_router.dart:91`) and
  `files_screen.dart:151` shows how to build it; server attachments have a
  node id, so wrap them in a `GestureDetector` and `context.push`. Local
  previews (a just-sent picture) have only a path; either a tiny
  full-screen route taking a path or accept that they open only after the
  turn lands (the local preview is kept after landing, so the node id is
  known then). Also the audit's bug list: `fileBytesProvider` is keepAlive
  and caches a failed load as `null` forever (`chat_api.dart:439-451`);
  give the image screen a Retry that invalidates it while you are there.
- **Tests.** No widget tests exist; add controller-level ones where there is
  logic (a pure `dayBoundaries(messages)` helper is easy to test) and
  verify the rest on the simulator. The thread to open is the first inbox
  row; it has messages from today and older.

Commit as one item: `feat(chat): timestamps, day dividers, scroll-to-bottom,
full-screen images, and the agent's name in the composer`.

## Items 8 to 11, briefly

8. **Settings identity.** Show the server address (`serverConfigProvider`)
   and the signed-in account (there is no profile endpoint in use; check
   `/api/profile/*` on the server before adding one), the app version
   (add `package_info_plus`) and server version (the probe already reads
   `/api/version`; keep it), a "Change server" that signs out then routes to
   `/setup`, and "Clear cache" (`AppDatabase.clearUserData` exists). The
   placeholder text "Account & profile settings coming soon." goes.
9. **Tap targets and a11y.** The audit's list is in the doc under "Layout and
   accessibility". Fix `ShadButton` size at the theme level once rather than
   per call site if shadcn_ui 0.54 allows it; the small toggles need padding,
   not bigger icons. Add `Semantics(label:)` to every icon-only button. Give
   the Notes, Tasks and Search lists `keyboardDismissBehavior` and a bottom
   inset. Put a one-screen rationale before `EventAlarms.requestPermissions`
   (`events_screen.dart`, fired from `initState`).
10. **Parity that fits the phone.** Tasks due date and priority, Events edit
    and a real time picker, Journal edit/delete and rendering the assistant's
    `kind: 'gap'` questions. The APIs already accept most of this
    (`tasks_api.dart` has `create(dueAt:)`, `events_api.dart` has
    `create(endsAt:)`, the models are missing `kind`). **Not** Pages editing.
11. **Tests** for what is still uncovered: `EventAlarms.sync`,
    `PushDecryptor`, flush-on-resume, and the first screen widget tests.

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
git log --oneline -9   # 264aa28 style … fd98307 docs: audit
```
