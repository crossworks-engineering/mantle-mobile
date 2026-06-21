# Mantle Companion — Handover

_Last updated: 2026-06-20._

A checkpoint for picking the work back up. For the system map read
[architecture.md](architecture.md); for UI rules read
[styling-guide.md](styling-guide.md). This doc covers **both platforms** — the
Flutter app (this repo) and the Mantle backend additions it depends on
(`~/Projects/mantle`).

## What this is

A cross-platform (iOS + Android) Flutter companion for the self-hosted **Mantle**
assistant. Connects to a user's own Mantle server over an authenticated REST API
(per-device bearer token). Open source, MIT.

## Latest checkpoint (2026-06-20) — themes + app icon + composer shipped; TestFlight build for push test

A feature + polish session on top of the working push pipeline. Everything below is committed and
pushed to `origin/main`. Version is now **1.1.0+5** (bumped twice: feature minor + a build number
for the location-fix re-upload).

### Shipped this session
1. **All 42 web color themes** ported with a picker, persistence, and random rotation. A generator
   (`tool/generate_themes.dart`) reads `~/Projects/mantle/apps/web/{lib/themes.ts,app/globals.css}`,
   converts oklch/hex/hsl → sRGB, and emits `lib/theme/mantle_themes.g.dart`. New: `MantleColors`
   inherited widget (theme-aware chart ramp), `ColorThemeController`, `RandomThemeController` +
   `RandomThemeScheduler`, and `features/settings/appearance_screen.dart` (Settings → "Theme &
   appearance"). See architecture.md → Theming. Verified: generated Clean Slate == old hand-written.
2. **App icon** for iOS + Android — white "m" on Mantle indigo (#6366F1). `tool/generate_app_icon.dart`
   composes the masters from `assets/icon/source/mantle_logo.png`; **flutter_launcher_icons** fans
   them out (no-alpha iOS marketing icon ✓, Android adaptive icon). Shows in the **next** IPA build.
3. **Composer rework** — two rows (text field on top, actions below) + **stop & edit**: cancel an
   in-flight send (Dio `CancelToken`), drop the optimistic bubble, restore text for editing.
   `ChatController.send` now returns `SendOutcome`. Caveat: client-side abort only (no server cancel
   endpoint), so a turn already processed can resurface on refresh.
4. **App Store validation fix** — added `NSLocationWhenInUseUsageDescription` (Transporter 90683).
   Location is an intended feature (geo context for the assistant, reverse-geocoded server-side);
   not yet implemented in code. When built: when-in-use scope; Android will then need
   `ACCESS_FINE/COARSE_LOCATION`.
5. **Typing indicator** — an assistant "typing" bubble (animated dots + the responder's stage
   label: "Thinking…", "Searching the web…") ported from web. `turnStageProvider` polls
   `GET /api/assistant/turn/stage` (~900ms) only while a send is in flight; no backend changes.
6. **Tooling** — `check_push_env.sh` reports a build's effective `aps-environment` (sandbox vs
   production); accepts `.ipa`/`.xcarchive`/`.app`. Composer input text bumped `muted` → body size.

### ➡️ NEXT STEP — start here
Confirm a **delivered + decrypted** push on **TestFlight** (the carry-over goal below). For the
build: bump the build number, `fvm flutter build ipa`, then
`./check_push_env.sh build/ios/ipa/mantle_companion.ipa` should report **production** for the app
*and* the NotificationService extension before uploading via Transporter.

## Previous checkpoint (2026-06-19) — iOS push ENROLLMENT device-verified; next = TestFlight delivery

**The iOS build → archive → TestFlight pipeline works, AND Mantle Push now enrolls on a real
device, end to end.** The full spine — Settings → Notifications → Connect → Mantle `/connect` →
relay `/enroll` → `/subscribe`, with the libsodium keypair — is proven on hardware, not just in
code. The two on-device blockers that stood in the way were found and fixed this session (see
"Resolved" below). What's left is a real *delivered + decrypted* push, which needs a **TestFlight**
build (debug registers with the APNs **sandbox**; the relay key is **production-only**).

### ➡️ NEXT STEP — start here
1. **Bump the build number** in `pubspec.yaml` (match the NSE `CURRENT_PROJECT_VERSION`), then
   archive → **TestFlight** (`mantle/docs/update-prod.md` for the relay/Mantle side is already live).
2. Trigger an assistant message and confirm the **decrypted** banner lands on the lock screen —
   real title/body via the NSE, not the generic "You have a new message." fallback (which means the
   NSE couldn't open the sealed box → check the shared keychain access group / entitlements).
3. Sanity-check the server side actually enrolled: prod `push_instance` / `push_subscriptions` and
   relay `devices` should now be **1** (were 0).
Then: M4 Android (Play-services device) and M6 (Play-less device) on-device verification remain.

### Resolved this session — the two on-device blockers
1. **Launch SIGABRT** `Library not loaded: @rpath/Sodium.framework/Sodium`. The swift-sodium
   `Sodium` CocoaPod (NSE) builds a **dynamic `Sodium.framework`** that case-collides with the Dart
   `sodium` 4.x **native-asset** `sodium.framework` on case-insensitive macOS; Runner links the
   capital name, which is absent on the case-sensitive device → crash at launch. **Fix:**
   **static-link** the pod — `use_frameworks! :linkage => :static` in the NSE Podfile target (emits
   no dynamic framework, so nothing collides; `import Sodium` unchanged). Verifiable on a *simulator*
   build (the bad name resolution happens at link time on the Mac). Considered but rejected as
   heavier: a `Clibsodium` C-only podspec. Memory: `mantle-companion-ios-sodium-framework-collision`.
2. **"Connecting…" forever.** `_connect()` called `disable()` on the **Android-only**
   `directPushControllerProvider`, which on iOS is never watched → it auto-disposed mid-`await` →
   the post-await `state =` threw "Cannot use Ref after disposed", aborting `_connect` **before** it
   reached the network (so the per-step timeouts in `connect()` never even ran, and prod showed 0
   connects). **Fix:** only stop the direct connection on Android, and harden `enable`/`disable`
   with `if (ref.mounted)`. Regression test: `test/features/direct_push_controller_test.dart`
   (deterministically reproduces the crash on the old code).

### Also this session — discontinued-package swap + a known-benign warning
- **`sqlite3_flutter_libs` (EOL, `0.6.0+eol`) → `sqlite3` 3.x** as a direct dep. sqlite3 was already
  bundled via Dart native assets and the EOL package was a no-op; no Dart changes (drift's
  `NativeDatabase`). (`sodium` also bumped `4.0.2 → 4.0.2+1`.)
- **Known/benign:** on iOS, FirebaseCore logs *"Could not locate configuration file:
  'GoogleService-Info.plist'."* iOS uses **raw APNs** and never calls `Firebase.initializeApp()`
  (Android-only, gated in `main.dart`); the `firebase_messaging` iOS pod is compiled in but inert.
  Cosmetic — **left as-is**. (Adding a real iOS plist would only silence the log, not fix anything.)

> **Commit state:** uncommitted on `main`. Logical commits: the sqlite3 swap, the sodium
> static-linkage fix (Podfile/Podfile.lock), and the Connect-hang fix + test — plus a build-number bump.

### iOS pipeline — solved this session (don't re-derive)
- **App Store Connect:** app record created (`crossworks.engineering.mantle`); App ID already had Push
  enabled; **Program License Agreement accepted** (it re-prompts periodically — re-accept at
  developer.apple.com/account if "PLA Update available" / "No iOS Distribution certificate" shows up).
- **NotificationService extension target** created in Xcode 26; the wizard clobbered the repo's real
  `NotificationService.swift` + `Info.plist` (restored from git); wired
  `CODE_SIGN_ENTITLEMENTS = NotificationService/NotificationService.entitlements`; NSE deployment target
  15.0; it's a `PBXFileSystemSynchronizedRootGroup` so its files auto-include.
- **`objectVersion` 70 → 77** in `project.pbxproj` (CocoaPods' xcodeproj 1.27 has no mapping for 70 → `pod install` fails).
- **Build-phase cycle fix:** in the Runner target, **"Embed Foundation Extensions" must run before "Thin Binary"**.
- **dSYM collision fix:** native-assets emits duplicate dSYMs (`sodium`/`objective_c`/`sqlite3`) and the
  `Sodium` CocoaPod's dSYM collides during archive → set **`DEBUG_INFORMATION_FORMAT = dwarf`** (no dSYMs)
  in the Runner project **and** the Podfile `post_install`. Cost: no crash symbolication (fine for testing).
- **`aps-environment`:** the local archive shows `development` but `flutter build ipa` re-signs the exported
  IPA to **production** (App Store profile) — verified correct, not a problem.
- **Versioning:** `CFBundleShortVersionString = $(FLUTTER_BUILD_NAME)` from pubspec — **bump the version in
  `pubspec.yaml`, never Xcode**, and **match the NSE `CURRENT_PROJECT_VERSION` to the build number** or ASC
  rejects the upload. Currently **1.0.2+3** everywhere. (Jason's rule: bump the build number every commit.)
- **`refresh.sh`** (new, repo root) re-syncs after any pubspec change: pub get → build_runner →
  `flutter build ios --config-only` (regens `Generated.xcconfig` + `pod install`) → arm64e strip. UTF-8 LANG.

### libsodium / sodium journey
- Began on `sodium_libs 3.4.6+4` (libsodium as a prebuilt **SPM xcframework**) → TestFlight rejected its
  **arm64e slice** (built with an old SDK; Apple now requires iOS 26 SDK for arm64e). Strip is automated in `refresh.sh`.
- Migrated to **`sodium 4.0.2`** (`sodium_libs` is discontinued — literally `export 'package:sodium/sodium.dart'`).
  4.x uses **Dart native assets**: kills arm64e at the root, but caused two follow-on issues, both now fixed —
  the dSYM collision (→ `DEBUG_INFORMATION_FORMAT = dwarf`) and the `sodium.framework` vs swift-sodium
  `Sodium.framework` **case-collision** that crashed the app at launch on device (→ static-link the NSE's
  `Sodium` pod; see this session's "Resolved" notes above). The Connect hang was **unrelated** to sodium — it
  was a Riverpod auto-dispose bug (also fixed above).
- Compile fixes from the bumps: `sodium_provider` made `async`; `file_picker 11.x` → `FilePicker.pickFiles(...)` (static).

### Backend test work this session (uncommitted, both repos)
- **`~/Projects/mantle-push`:** `node:test` units for the security-critical primitives —
  `src/lib/{ticket,tokens,ratelimit}.test.ts` (36 tests), `"test": "node --test"` added. `pnpm test` + `typecheck` green.
- **`~/Projects/mantle` (`apps/web`):** vitest for the push send path — `lib/push/notify.test.ts` (gating + delivery, 18),
  extracted `lib/push/preferences-sanitize.ts` + `.test.ts` (10), `lib/push/{tokens,ticket}.test.ts` (wire-compat).
  Full repo suite 1507 green; web typecheck clean.

### Pending decision (not started) — dev workflow
Jason (remote, 8 GB M2) wants to **drop Colima** and run **local `next dev` against the prod DB**. Agreed
guardrails: workers stay prod-only (local = web/API only, or duplicate notifications); migrations deliberate +
`scripts/db-dump.sh` first; keep a prod dump; reach prod Postgres via SSH tunnel → local `.env DATABASE_URL`.
Phone app must point at **prod** (`https://jason.crossworks.network`), never localhost.

### Environment & prod
- **macOS 26 (Tahoe) + Xcode 26 (iOS 26 SDK)** — now required for App Store upload. Disk freed to ~51 GB.
- Relay **live + credentialed** at `push.crossworks.network` (APNs prod + FCM both authenticate;
  `scripts/smoke-live.ts`). Baseline **0 instances / 0 devices** — clean, ready for the real device. Mantle **v0.26.0** live.
- Relevant memories (auto-load): `mantle-companion-ios-versioning`, `mantle-companion-ios-libsodium-arm64e`, `xcode-mcp`.

---

## State at this checkpoint (prior session — 2026-06-15)

> **Latest session (2026-06-15) — the ENTIRE push project (M1–M6) was built; the
> whole server side is deployed and live in prod.** This was a long session that
> went from "no push at all" to "everything built + server deployed." Three repos.
>
> **Done & in production (server side — nothing left to deploy):**
> - **`mantle-push` relay — LIVE + CREDENTIALED** at `https://push.crossworks.network`
>   (`provider:"live"`). Node+TS+Hono, own Postgres, co-located on the prod box as
>   its own compose stack (`mantle_push` + `mantle_push_db`) behind Caddy. APNs
>   (prod) + FCM both **authenticate** (smoke-live: fake token → APNs `BadDeviceToken`
>   / FCM `INVALID_ARGUMENT`). Public repo, now with `docs/architecture.md`.
> - **Mantle v0.26.0 deployed to prod.** Migrations 0089–0093 all applied (drizzle
>   94, data intact). Live: the mobile-companion API (M2: `/api/push/connect|
>   subscriptions|reset`, the seal+send `worker_push` off `conversation_changed`)
>   **and** M5 (push_prefs, `/api/push/preferences`, the worker's prefs-gating +
>   tz-aware quiet hours + the **approvals trigger** off `pending_changed`).
> - **Credentials provisioned** (Apple `.p8` `2TJ76S5L69` topic-specific/**production**,
>   Firebase `pusher-5bacc`). Secret files on the prod box at `~/mantle-push/secrets/`.
>   Bundle id `crossworks.engineering.mantle`; Android pkg `me.schoeman.mantle_companion`.
>
> **Built, code-complete, NOT yet device-verified (the companion app halves):**
> - **M3 iOS** — Dart Connect + libsodium keypair (`sodium_libs`) + the Swift
>   **Notification Service Extension** (decrypt). Needs Xcode (capabilities + the NSE
>   target + signing) and **TestFlight** (our APNs key is production-only). Runbook:
>   `ios/PUSH_SETUP.md`.
> - **M4 Android** — `firebase_messaging` + a Dart background-isolate decrypt → local
>   notification. Needs a **Play-Services** device. Runbook: `android/PUSH_SETUP.md`.
> - **M6 direct connection (no-Google Android)** — a foreground service holding the
>   SSE stream open → local notification, straight from the user's Mantle (no
>   relay/FCM/ntfy/crypto). Chosen over UnifiedPush. Needs a **Play-less** device.
>
> **➡️ NEXT SESSION — pick from, in priority:**
> 1. **On-device verification** (yours to run): M3 on TestFlight, M4 on a
>    Play-Services device, M6 on a Play-less device. The whole spine is proven in
>    code; this is the only thing between "built" and "a notification on a phone."
> 2. **Unit-test gap** (the live question when this session ended — a good coding
>    task): **`mantle-push` has ZERO unit tests** (only `scripts/smoke.ts`, an
>    integration test needing a running server) — and its untested code is
>    security-critical (ticket HMAC verify, token hashing, rate limiter). Add
>    **`node:test`** (built-in, zero deps, runs TS via the same strip mode) tests for
>    `src/lib/ticket.ts` (round-trip / tampered / expired / wrong-key / malformed),
>    `tokens.ts`, `ratelimit.ts`. Mantle backend is thin too (only
>    `apps/web/lib/push/quiet-hours.test.ts`) — worth adding `notify.ts` gating +
>    the prefs-route sanitizer. The app is OK (64 tests, incl. push controllers).
> 3. Other open items below (Pending screen, account settings).
>
> **Commit/deploy state:** all three repos clean on `main`. `mantle` +
> `mantle-push` fully pushed to origin. `mantle-companion` was merged/pushed by
> Jason. Durable detail is in the `mantle-push` project memory (loads automatically).
> Model in use: **Opus 4.8**. Deploy loop = build-on-VPS (`mantle/docs/update-prod.md`);
> always pre-dump (`scripts/db-dump.sh`) before a migration.
>
> **Prior session (2026-06-13).** Backend verified live + committed; avatar
> endpoint fixed; dashboard theme-color fix; inbox redesigned as flat accent
> cards; a backend audit (JSON 401 gate + read-body validation); **live chat over
> SSE shipped** (both repos); and the **Mantle Push** notification design was
> approved (`docs/push-notifications.md`). Everything committed on `main` in both
> repos, **nothing pushed.**

**Working & verified in the app** (`fvm flutter analyze` clean, **57 tests pass**):

- **Auth** — server setup → bearer login → session gate (go_router redirect).
- **Dashboard landing** (`/`) — `mantle` header, 3 action tiles (Chat / Pending /
  Settings), stat cards (Spend 7d, Pending, Brain nodes, Vectors) + a Server card
  (CPU/RAM/Disk meters + service dots).
- **Two-tier chat** — inbox (`/chat`) = **flat accent cards** (avatar · name ·
  preview · time · unread badge) → per-agent thread (`/chat/:slug`) with markdown,
  scroll-up paging (30/page), optimistic send, read-on-open.
- **Live chat (SSE)** — the open thread + inbox update in real time off
  `/api/assistant/stream`; pauses while backgrounded (see open item 5).
- **Markdown** — GFM + Mantle's custom blocks (`:::callouts`, `:::aside`,
  `:::columns`, `==highlight==`, `[text]{color}`); images/math still TODO.
- **Avatars** — boring-avatars SVG from Mantle, initials fallback.
- **Settings** (`/settings`) — theme select + sign out.

**Verified live on local dev (2026-06-13)** — the **Mantle backend** additions.
Migrations 0090 + 0091 applied; all routes smoke-tested with a mobile bearer
(dashboard summary, conversations, read cursor, avatar, SSE stream); owner-gate
returns a clean **401** for JSON routes / **307** for pages. `apps/web` typecheck
clean.

## Mantle backend additions (in `~/Projects/mantle`, committed on `main`, not pushed)

JSON API routes gate with **`getOwnerOr401()`** (clean 401); page routes use
`requireOwner()` (307→/login). All work with a mobile bearer token. See
`~/Projects/mantle/docs/mobile-companion-backend.md` for detail.

| Area | Files | Notes |
|---|---|---|
| Bearer auth | `apps/web/lib/auth.ts`, `middleware.ts`, `schema/mobile-tokens.ts`, migration `0089` | Per-device token; `getOwnerOr401` for JSON routes. |
| Dashboard | `app/api/dashboard/summary/route.ts` | Aggregates existing `lib/dashboard.ts`/`metrics.ts`. |
| Conversations | `app/api/assistant/conversations/route.ts`, `lib/assistant-inbox.ts` | Per-agent last message + unread. |
| Read state | `app/api/assistant/read/route.ts`, `schema/assistant-read-cursors.ts`, migration `0090` | `assistant_read_cursors(owner, agent, last_read_at)`; body `safeParse`d → 400. |
| Avatars | `app/api/agents/[id]/avatar/route.ts`, `lib/avatar-svg.ts` | Pure-string port of boring-avatars (no React — `react-dom/server` can't render its `useId()` in a route). Under the existing `[id]` segment, resolves uuid-or-slug. Parity pinned by `lib/avatar-svg.test.ts`. |
| Live chat (SSE) | `app/api/assistant/stream/route.ts`, `lib/realtime.ts`, migration `0091` | Per-owner SSE; `conversation_changed` NOTIFY (trigger) → bridge → `data:{agentSlug,direction}`. Mirrors `/api/realtime`. |

**To run the backend:** in `~/Projects/mantle`: `pnpm db:migrate` (applies 0089–
0091), then the `next dev` server hot-loads the new routes. **Note:** `lib/realtime.ts`
keeps its LISTEN bridge in a `globalThis` singleton that survives HMR, so a
newly-added LISTEN channel needs a **dev server restart** to register (prod evals
once, fine) — verify realtime changes with a fresh-eval script, not the running
dev server.

## How to run

```bash
# Backend (~/Projects/mantle)
colima start && pnpm infra:up && pnpm db:migrate   # Postgres + migrations
# next dev runs on http://localhost:3000

# App (this repo)
fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs   # after provider/model changes
fvm flutter run                                    # full restart needed after new deps/assets
fvm flutter analyze && fvm flutter test
```

The iOS simulator reaches the host's `http://localhost:3000` directly
(`ios/Runner/Info.plist` `NSAllowsLocalNetworking`, dev only).

## Open items / next steps

**Done this session (2026-06-13):**
- ~~Verify the Mantle backend live~~ — 0090/0091 applied, routes smoke-tested,
  **avatar endpoint fixed** (segment conflict + `react-dom/server`/`useId` crash →
  pure SVG port).
- ~~"Incorrect in Mantle" stat~~ — it was a **hardcoded `amber` colour** on the
  Pending KPI card, not a bad calculation. Fixed to the `primary` theme token
  (Mantle `8ffc62a`); documented "which fill where" in both style guides.
- ~~Live chat (SSE)~~ — shipped (Mantle `9783d61`, companion `765df23`). See the
  backend table; the companion stream pauses while backgrounded.

**Next, in rough priority:**
1. **Mantle Push** (push notifications) — [`push-notifications.md`](push-notifications.md).
   - ~~**M1 — the relay (`mantle-push`)**~~ **DONE** (2026-06-14). Built + smoke-
     tested on the mock provider; see `~/Projects/mantle-push/README.md`. Deploy is
     wired (Caddy block + `docs/deploy.md`) but **gated** — ships when Jason says.
     APNs/FCM creds (Apple Dev account, Firebase project) don't exist yet; only
     needed at M3/M4 when the app flips the relay to `live`.
   - ~~**M2 — Mantle side**~~ **DONE** (2026-06-14, Mantle v0.25.0). Migration 0092
     (`push_instance` + `push_subscriptions`), the connect/subscribe/reset routes,
     `lib/push/*` (libsodium `crypto_box_seal` + relay client + token/ticket
     wire-compatible with the relay), and **`worker_push`** off `conversation_changed`.
     **DEPLOYED to prod (Mantle v0.25.0)**; relay is **live + credentialed** at
     `push.crossworks.network` (APNs prod + FCM both authenticate).
   - ~~**M3 iOS**~~ **CODE-COMPLETE (2026-06-14)**: `data/push/*` + `PushController`
     + Settings→Notifications (Dart, analyze+tests clean), `AppDelegate` APNs bridge,
     and the **Notification Service Extension** (swift-sodium decrypt). Remaining =
     **Xcode + TestFlight** (Apple-account-only) — see `ios/PUSH_SETUP.md`. Our APNs
     key is production-only, so a real decrypted push verifies via TestFlight.
   - ~~**M4 Android**~~ **CODE-COMPLETE (2026-06-14)**: `firebase_messaging` FCM
     token + Dart background-isolate decrypt (`sodium_libs` seal-open) →
     `flutter_local_notifications`; gradle/manifest wired, Firebase kept
     Android-only. Remaining = run on a Play-services device (`android/PUSH_SETUP.md`).
   - ~~**M5** Settings & polish~~ **CODE-COMPLETE (2026-06-14)**: per-trigger toggles
     + quiet hours + approvals trigger (Mantle v0.26.0, migration 0093, worker
     enforces them), and the Settings → Notifications UI (switches, quiet hours,
     device unpair, reset). analyze + tests clean both sides.
   - ~~**M6** no-Google Android~~ **CODE-COMPLETE (2026-06-14)**: a **direct
     connection** (foreground service holding the SSE stream open → local
     notifications, straight from the user's Mantle; no relay/FCM/ntfy/crypto) —
     chosen over UnifiedPush. Settings toggle, Android-only, mutually exclusive
     with FCM. See `android/PUSH_SETUP.md`.
   - **Push is now M1–M6 built end to end.** Remaining = on-device verification
     (M3 TestFlight, M4 Play device, M6 Play-less device) + deploy Mantle v0.26.0.
2. **Pending screen** is a placeholder — build the real approvals list +
   approve/reject (`GET /api/pending`, `PATCH /api/pending/{id}`).
3. **Settings** — account/profile management (only theme + sign out exist).
4. Roadmap (not started): Drift message **cache + offline send-queue**,
   **message-attached location** (geolocator, When-In-Use), markdown **images +
   math** (Phases 3–4), in-app routing for internal links.

## Gotchas (carried forward)

- **fvm** always (`fvm flutter`/`fvm dart`). New font/native dep → full `flutter
  run` restart, not hot reload.
- **No Material** — shadcn_ui only; status colours (green/amber/red on the server
  card) are a deliberate exception (no success token in the palette).
- Riverpod 3: `AsyncValue.value` (nullable); `ChatController` is a **family** keyed
  by agent slug.
- `custom_lint`/`riverpod_lint` removed (analyzer conflict); `freezed` prerelease,
  unused.
- mocktail: `any(named:)` matches omitted args and the **last** matching stub wins
  — use one stub branching on the arg (see `chat_controller_test`).
- **Live chat**: `ChatController`/`ConversationsController` `ref.listen` the live
  `conversationEventsProvider` (SSE). Unit tests for them **must override it** with
  `const Stream<ConversationEvent>.empty()`, or they pull in Dio + open a socket.
- Generated `*.g.dart` are committed.
- Local Mantle password was shared for testing only — never store it; rotate.
