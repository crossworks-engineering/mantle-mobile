# Handover: the audit worklist, items 9 to 11

_Written 2026-09-16 at the end of the session that wrote the audit and did
items 1 to 6; updated 2026-09-17 after items 7 and 8. Items 7 and 8 are not
pushed. Pick up here._

> ### Start here
>
> 1. Run the `mantle-recall` skill first (fleet, ssh aliases, the
>    `jackdaw-ui-standards` map). Then this repo's `CLAUDE.md` and
>    `docs/styling-guide.md`; the guide's "Shared conventions" and "Status
>    colours" sections are new and are the rules items 5 and 6 established.
> 2. `fvm flutter analyze && fvm flutter test` — expect clean and **201**
>    passing. A failure before you touch anything is not yours.
> 3. The audit is `docs/audit-2026-09-16.md`; the worklist at its end is the
>    plan. Items 1 to 8 are done (commits `939d982` … `491c747`). This file
>    is what the doc does not say: the judgement calls, the traps, and where
>    item 9 starts.

---

## Where things stand

| What                     | State                                                                                                 |
| ------------------------ | ----------------------------------------------------------------------------------------------------- |
| Branch                   | `main`, four commits ahead of origin (item 7, its doc, item 8, this doc). Items 1 to 6 and the CI fix are on origin, so CI has run; items 7 and 8 are **not pushed**. Push is Jason's call. |
| Tests                    | 154 → 212. Analyzer clean.                                                                            |
| CI                       | `.github/workflows/verify.yml` exists but has never run (nothing pushed). The Android job uses `tool/ci/google-services.ci.json`; that placeholder was proven to build a release APK locally. |
| Simulator                | An iPhone 17 (iOS 26) on the Mac has the app installed and **signed in to the dev brain**. `fvm flutter build ios --simulator --debug`, then `xcrun simctl install booted build/ios/iphonesimulator/Runner.app` and `xcrun simctl launch booted crossworks.engineering.jackdaw`. The login survives reinstalls. Do NOT sign it out; a session cannot type credentials. |
| Brain                    | Task "Act on the jackdaw-mobile audit" (tag `mantle-roadmap`) has 8 of 12 ticked and a comment per item. Audit page `adcc0b73…` has an uncommitted draft with the scope rule. |
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

## Items 9 to 11, briefly

Item 9 starts with the audit doc's "Layout and accessibility" list; the
`ShadButton` size question is a theme-level one (`lib/theme/mantle_theme.dart`).

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
git log --oneline -13  # 491c747 feat(settings) … fd98307 docs: audit
```
