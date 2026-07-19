# Mantle Companion — Architecture

A handover-oriented map of the app: what it is, how it's structured, and how it
talks to Mantle. Pair this with [styling-guide.md](styling-guide.md) for UI rules.

## What this is

A cross-platform (iOS + Android) Flutter app — a mobile companion for the
**self-hosted Mantle** personal assistant. It connects to a user's own Mantle
server over an authenticated REST API.

Scope, in order of build (all shipped as of **v1.6.0+13**):

1. **Chat** with the assistant — rich rendering, attachments, voice, and (v1.3–
   1.4) live token streaming with a thought trail
2. **Message-attached location** — coordinates stapled to a message, read
   on-demand at send time (foreground only → "When In Use", never "Always")
3. **Push notifications** from Mantle
4. **The brain's knowledge on the phone** (v1.5) — read-only **Pages**, and
   capture-first **Tasks** + **Journal**
5. **Events with real device alarms** (v1.6) — OS-scheduled local notifications
   that ring at the exact start time, offline, phone locked

The client is intentionally thin; Mantle is smart. The app sends raw input and
renders responses — no reverse-geocoding or POI logic on device. The one
deliberate exception is **event alarms**, which are mirrored onto the device's
alarm scheduler so they fire without network (see [Events](#events--device-alarms)).

## Tech stack

| Concern | Choice | Notes |
|---|---|---|
| SDK | **Flutter**, pinned via **fvm** | `.fvmrc`; always `fvm flutter …` / `fvm dart …` |
| UI | **shadcn_ui** | No Material design language (see styling guide) |
| State | **Riverpod 3** + code-gen (`@riverpod`) | `riverpod_generator`, `build_runner` |
| Local DB | **Drift** (SQLite) | `app_settings` KV today; domain tables as needed |
| Secrets | **flutter_secure_storage** | Keychain / Keystore — bearer token only |
| HTTP | **Dio** | Base URL + bearer interceptor |
| Nav | **go_router** | Auth-gated redirect |
| Models | freezed + json_serializable | Available; chat model hand-written for now |
| Markdown | **flutter_markdown_plus** (+ `markdown` parser) | Renders assistant replies; `url_launcher` opens external links |
| Tests | flutter_test + **mocktail** + in-memory Drift | 95 tests |

## Project layout

```
lib/
  core/
    network/         dio_provider.dart       — Dio + bearer/auth-failure interceptor
    lifecycle/       app_lifecycle.dart      — foreground/background provider
  data/
    db/              app_database.dart       — Drift DB (app_settings KV)
                     connection.dart         — native SQLite open
                     database_provider.dart  — appDatabaseProvider
    server/          server_config.dart      — base URL (Drift) + probeMantleServer
    auth/            token_store.dart         — bearer token (secure storage)
                     auth_api.dart            — mobile-login / mobile-logout
                     auth_repository.dart     — login/logout orchestration
    chat/            chat_message.dart        — unified message model
                     chat_api.dart            — turn/messages/stream endpoints
                     chat_repository.dart     — seam (future Drift cache/queue)
                     turn_event.dart          — one SSE turn event (+ v tripwire)
                     turn_meta.dart           — thought trail / tool-stat shapes
                     conversation_stream.dart — per-owner /api/assistant/stream
                     chat_attachment.dart     — attachment model
    agents/          agent.dart               — agent model (slug/name/accent/hasAvatar)
                     agent_api.dart           — GET /api/agents, agent avatar SVG
    conversations/   conversation_models.dart — inbox row (preview + unread)
                     conversations_api.dart   — GET /api/assistant/conversations, POST /read
    dashboard/       dashboard_models.dart    — summary + health models
                     dashboard_api.dart       — GET /api/dashboard/summary, /api/health
    pages/           pages_api.dart, pages_models.dart      — index/meta/markdown/backlinks
    tasks/           tasks_api.dart, tasks_models.dart      — CRUD + done flip
    journal/         journal_api.dart, journal_models.dart  — list + capture
    events/          events_api.dart, events_models.dart    — CRUD + done tag
                     event_alarms.dart        — OS alarm mirror (zonedSchedule + sync)
    location/        location_ping.dart, location_service.dart
    pending/         pending_api.dart, pending_models.dart  — approvals
    profile/         profile_api.dart
    push/            push_api.dart, push_notifier.dart, push_keys.dart, …
                     local_notifications.dart — ONE shared plugin init + tap handler
                     deep_link.dart           — notification payload → route
  features/
    auth/            session_controller.dart  — AuthStatus gate
                     server_setup_screen.dart
                     login_screen.dart
    agents/          agent_controller.dart     — agent list (names/avatars)
                     agent_avatar.dart         — SVG avatar w/ initials fallback
    conversations/   conversations_controller.dart, conversations_screen.dart (inbox)
    chat/            chat_controller.dart      — per-agent thread (family by slug)
                     chat_screen.dart          — agent header, marks read on open
                     turn_trail.dart           — thought-trail rendering (kind→icon)
                     turn_stage_controller.dart, chat_composer.dart, …
    dashboard/       dashboard_controller.dart — summary + best-effort health
    home/            home_screen.dart          — landing dashboard (stats + actions)
    pages/           pages_controller.dart, pages_screen.dart (tree),
                     page_view_screen.dart     — markdown + authed images + links
    tasks/           tasks_controller.dart, tasks_screen.dart
    journal/         journal_controller.dart, journal_screen.dart (mic capture)
    events/          events_controller.dart, events_screen.dart (+ add sheet)
    pending/         pending_controller.dart, pending_screen.dart — approvals
    settings/        theme_mode_controller.dart, settings_repository.dart
                     color_theme_controller.dart  — selected color theme id
                     random_theme_controller.dart — shuffle mode + scheduler
                     location_controller.dart     — location sharing opt-in
                     push/                        — push enrollment screens
                     settings_screen.dart      — sections → subscreens
                     appearance_screen.dart    — mode + color picker + shuffle
  widgets/           mantle_header.dart         — shared primary header bar
  routing/           app_router.dart           — go_router + redirect
  theme/             mantle_theme.dart          — theme builder + MantleColors
                     mantle_themes.g.dart       — generated: all 42 color themes
  main.dart          ShadApp.router root
```

## Layered architecture

```
UI (screens, ConsumerWidget)
      ↓ watch / read
Controllers (Riverpod Notifiers/AsyncNotifiers)
      ↓
Repositories (orchestration; the seam for caching/queues)
      ↓
Data sources (Api over Dio · Drift DB · secure storage)
```

Dependencies point inward. **Every boundary is a Riverpod provider**, so tests
override it (in-memory Drift, mocked repos/APIs). Don't reach across layers — UI
never touches Dio/Drift directly.

## State management (Riverpod 3)

- **Code-gen**: annotate with `@riverpod`; run `fvm dart run build_runner build`
  after changing a provider or model.
- **keepAlive** (`@Riverpod(keepAlive: true)`) for app-singletons: database,
  repositories, dio, session, router. Feature controllers (chat) auto-dispose.
- **AsyncNotifier** for async-backed state (theme mode, session, chat).
- Riverpod 3 gotcha: `AsyncValue.value` is the nullable getter — **`valueOrNull`
  was removed**.

## Persistence

- **Drift** — `app_settings(key, value)` key/value store holds the server URL
  (`server_base_url`) and theme mode (`theme_mode`). Add typed domain tables as
  features need them (chat cache, send-queue). Migrations live in Drift's
  `schemaVersion`/`onUpgrade`. Tests use `AppDatabase.forTesting(NativeDatabase.memory())`.
- **Secure storage** — only the bearer token (`mantle_bearer_token`).

## Networking

`dioProvider` builds a Dio whose base URL comes from `ServerConfig` (so it
rebuilds when the server changes). The interceptor:

- **onRequest** — injects `Authorization: Bearer <token>` from `TokenStore`.
- **onError** — on **401** OR a **3xx redirect to `/login`** (a revoked-but-
  unexpired token; see Auth), clears the token and invalidates the session →
  router bounces to login. Login opts out via `extra: {'skipAuthHandler': true}`
  (a 401 there means "wrong password", not "log out").
- `followRedirects: false` so the 3xx-to-login case is observable.

## Authentication

Per-device **bearer token** (chosen over cookie/pairing).

Flow: **Server setup** (validate via public `GET /api/version`) → **Login**
(`POST /api/auth/mobile-login` → token saved to Keychain) → **Home**.
`SessionController` exposes `AuthStatus { needsServer, loggedOut, loggedIn }` and
is the single source of truth the go_router `redirect` follows.

Mantle side (in the `mantle` repo, see its commit): a `mobile_tokens` table; the
token is HMAC-signed like the session cookie but carries a `jti` + `k:'m'`;
`getSessionUser()` and the Edge `middleware` accept it, so **every existing
endpoint works with the mobile token, no per-route changes**. `mobile-logout`
revokes by `jti`.

## Chat

- `ChatApi` — `GET /api/assistant/messages?before=&limit=&agent=` (history,
  oldest-first page) and `POST /api/assistant/turn` `{text, agentSlug?}` →
  `{inbound, outbound, reply}` (120s timeout).
- `ChatController` — exposes `ChatState { messages, hasMore, loadingMore, active }`.
  Loads the latest page on build (`chatPageSize` = **30**), **pages older history**
  via `loadMore()` (cursor = oldest loaded `createdAt`; prepends, de-dupes by id;
  `hasMore` = last page was full). The screen's reversed `ListView` fires
  `loadMore()` when scrolled near the older end. **Optimistic send** (user message
  shows as `sending`, then `sent` + reply appended, or `failed`).

### Live turn streaming (v1.3) + the thought trail (v1.4)

A sent turn no longer waits for one atomic response — the reply **types out
token by token**, mirroring the web's `TurnStream`:

- **Wire.** The turn id *is* the client-minted idempotency-key, so the client
  can open `GET /api/assistant/turn/:id/stream` (SSE) immediately after the
  `POST` and correlate. Events are `TurnEvent {v, turnId, seq, round, type,
  data}` ([`data/chat/turn_event.dart`](../lib/data/chat/turn_event.dart)) —
  `turn-start | status | reasoning-delta | text-delta | tool-start | tool-end |
  done | error`. `seq` doubles as the `Last-Event-ID` **resume cursor**; a new
  `round` resets the visible reply so only the final answer types out.
  **Schema tripwire:** `kTurnEventSchemaVersion` — an event with a higher `v`
  than the client understands ends the stream (falls back to refetch) rather
  than mis-parsing; a test pins it against drift.
- **`ActiveTurn`** accumulates the live state: `reply`, `reasoning`, the
  **thought trail** (`steps` — `status` events upserted by `stepId`, so a
  grounded line upgrades to its narrated version in place instead of
  duplicating), a **tool tally** (`toolsStarted/Done/Failed`), and a token
  count (streamed **estimate** that swaps for the provider-reported exact
  `tokensOut` on `done`).
- **UI** ([`turn_trail.dart`](../lib/features/chat/turn_trail.dart)): each step
  renders with a Lucide icon mapped from its coarse `kind` (`web`, `compute`,
  `file`, `person`, … — open-ended set, wrench default) + elapsed time; the
  reasoning trace is a collapsible "Thinking" block; the tally and token count
  sit under the streaming bubble.
- **Persistence.** When the brain has trail-persistence on, a landed outbound
  row carries `thoughts` / `toolStats`
  ([`turn_meta.dart`](../lib/data/chat/turn_meta.dart)) so the trail survives a
  reload — same shapes as live, minus the `stepId`.
- **Stop & resume.** Stop cancels the POST *and* the stream
  (`POST /api/assistant/turn/:id/cancel` exists server-side). A mid-turn app
  reload shows pending/failed bubbles from history and the persisted
  thought-process record; a foreground resume refetches (bounded ~2 min).
- **Inbox live-ness.** `conversation_stream.dart` subscribes the per-owner
  `GET /api/assistant/stream` (SSE ping per turn on any channel) — the inbox
  and open thread refetch on ping; the old `/api/assistant/turn/stage` poll
  remains only as the coarse label fallback.
### Conversations (two-tier chat)

Mantle keeps **one forever-thread per (owner, agent)**, so the chat is a
messaging-style inbox:

- **Tier 1 — inbox** (`conversations_screen.dart`, route `/chat`): one card per
  agent (avatar · name · last-message preview · time · unread badge) from
  `GET /api/assistant/conversations`. Tap → the thread.
- **Tier 2 — thread** (`chat_screen.dart`, route `/chat/:slug`):
  `ChatController` is a **family keyed by `agentSlug`**; history/turn/paging all
  scope to that slug. The header shows the agent (avatar + wordmark name) + back;
  there's no picker — the inbox *is* the selector. Opening the thread calls
  `markRead(slug)` (clears unread); a successful turn invalidates the inbox so
  its preview/unread refresh.
- **Unread** is server-tracked: `assistant_read_cursors(owner, agent, last_read_at)`
  in Mantle; unread = outbound messages newer than the cursor.
- **Avatars**: `AgentAvatar` fetches `GET /api/agents/{slug}/avatar` (Mantle
  server-renders the boring-avatars SVG via `renderToStaticMarkup`, hex palette
  so flutter_svg can parse it) and renders it with `flutter_svg`; falls back to
  the slug-accent initials circle (matching Mantle's null-avatar fallback) when
  the agent has no avatar or the fetch fails.
- `AgentController` (keepAlive) still serves the agent **list** (names/avatars for
  the thread header). Its `active`/`select`/`activeAgentSlug` are no longer used
  by the chat (the inbox selects); kept for now.

### Rendering assistant replies

The message `text` is **raw markdown** in Mantle's GFM-superset dialect (no HTML,
no pre-structured blocks); two side-channels carry media — `artifacts[]`
(tool-generated, base64) and `attachments[]` (file-node refs fetched from
`/api/files/files/{nodeId}?raw=1`, **which needs the Bearer header**).

[`features/chat/markdown/mantle_markdown.dart`](../lib/features/chat/markdown/mantle_markdown.dart)
(`MantleMarkdown`) renders replies via **flutter_markdown_plus**, with a
`MarkdownStyleSheet` derived entirely from `ShadTheme` tokens (so light/dark and
the bubble colour drive it). User messages stay plain `Text`. Built in phases:

1. **GFM text (done)** — paragraphs, headings, lists, task lists, tables, fenced
   /inline code, blockquotes, emphasis, links (external links open via
   `url_launcher`; relative/internal links are a TODO).
2. **Mantle custom syntax (done)** — `:::info/success/warning/danger` callouts
   (left accent + Lucide icon), `:::aside chart-N` (gradient note),
   `:::columns … +++ … :::` (stacked on the narrow bubble), `==highlight==`,
   `[text]{color=chart-N}`/`{highlight=chart-N}`. Parsed in
   [`markdown/mantle_syntax.dart`](../lib/features/chat/markdown/mantle_syntax.dart)
   as custom `BlockSyntax`/`InlineSyntax` (fences store raw inner markdown →
   rendered by a nested `MantleMarkdown`; the `chart-N` palette lives in
   `mantle_theme.dart`). Invalid colour tokens are baked out of the inline regex
   so they fall through to plain text. Inline spans flatten nested emphasis (v1).
3. **Images & attachments (done)** — see [Attachments & voice](#attachments--voice).
4. **Math & syntax highlighting** — `$…$` / `$$…$$` (flutter_math_fork) and
   code-block highlighting.

### Attachments & voice

The composer ([`features/chat/chat_composer.dart`](../lib/features/chat/chat_composer.dart))
is a two-row layout — the text field on top (grows to 6 lines), with the attach
button (photo library / camera via **image_picker**, document via
**file_picker**), the mic, and the send/stop button on the row below. Both
attach and voice reuse Mantle's existing endpoints — no new server work:

- **Send.** A picked file rides on the turn as multipart
  (`POST /api/assistant/turn`, field `image` for pictures / `file` for the
  ingestable doc types `pdf,docx,xlsx,xls,csv,txt,md,json,yaml,yml`); text-only
  turns stay JSON. The user's bubble shows the picked file immediately (from
  disk); the server strips image bytes from the reply, so we keep rendering the
  local preview after the turn lands. Each send carries a fresh `idempotency-key`
  header (128-bit, `ChatController._newIdempotencyKey`) so a retried/replayed
  POST that already completed server-side replays the cached turn instead of
  creating a duplicate.
- **Stop & edit.** While a turn is in flight the send button becomes a red ■.
  Tapping it cancels the POST via a Dio `CancelToken` *and* the SSE turn stream,
  drops the optimistic bubble, and restores the text + attachment to the field
  for editing. `send` returns a `SendOutcome` (`sent`/`failed`/`cancelled`) so
  the composer knows when to restore. Server-side, `POST
  /api/assistant/turn/:id/cancel` stops the responder; a turn that already
  completed can still resurface on the next refresh.
- **Typing indicator.** While a turn is in flight, an assistant "typing" bubble
  ([`chat_screen.dart`](../lib/features/chat/chat_screen.dart) `_TypingBubble`)
  shows animated dots plus the responder's coarse **stage label** ("Thinking…",
  "Searching the web…", …). `turnStageProvider` polls `GET
  /api/assistant/turn/stage` every ~900ms (mirroring the web — it's a poll, not a
  stream) only while the optimistic `sending` message exists, and stops the
  moment the turn lands. Label is null between mapped steps → dots only.
- **Retry & copy.** A failed turn (e.g. flaky connection) keeps its bubble with a
  one-tap **Retry** (`ChatController.retry` drops the failed bubble and re-sends
  the text + attachment, reconstructed from the local preview). Long-pressing any
  message opens a sheet to **copy** its text (and retry, if it failed).
- **Voice.** Tap the mic to record (**record** → `.m4a`/aac to a temp file, with
  a live timer + cancel); tap send to stop → `POST /api/assistant/transcribe`
  (Mantle's default STT worker) → the transcript is sent as a normal turn. A
  missing STT worker (412) / failed transcription (422) surfaces the server's
  message inline.
- **Render** ([`features/chat/attachment_view.dart`](../lib/features/chat/attachment_view.dart)).
  `ChatMessage.attachments` (`ChatAttachment`) drives it: an image shows inline —
  from `localPath` when just-sent, else fetched authed by `nodeId` via
  `fileBytesProvider` (`GET /api/files/files/{nodeId}?raw=1`, the path on history
  reload); any other kind (document) is a labeled chip with its file type.
  History rows carry `attachments[]`; the just-completed turn's inbound
  `artifacts[]` are echoed but the client prefers its own local preview.
- **Voice reply (assistant → you).** Saskia can answer with audio via Mantle's
  built-in *"Send a voice reply"* tool (needs a default **TTS** worker; she calls
  it when asked — "send that as a voice note" — or on her own). The turn returns
  an outbound `artifacts[]` entry (`kind:'audio'`, mp3 base64 on the web surface
  the companion uses — **Telegram's opus/sendVoice path is untouched**).
  `ChatApi.sendTurn` decodes it to a temp file and hangs it on the reply as an
  `audio` `ChatAttachment`; [`audio_bubble.dart`](../lib/features/chat/audio_bubble.dart)
  (`AudioBubble`, **just_audio**) plays it inline (play/pause + progress). These
  bytes are live-only (not persisted for web turns), so a voice reply doesn't
  survive a history reload — same as the web `/assistant`.
- **Native permissions**: iOS `NSMicrophoneUsageDescription` /
  `NSPhotoLibraryUsageDescription` / `NSCameraUsageDescription` /
  `NSLocationWhenInUseUsageDescription` (the last for the planned
  message-attached location feature — see Theming/roadmap; the string is also
  required to clear App Store validation 90683 from a linked SDK); Android
  `RECORD_AUDIO` (the pickers use the system UIs, so no storage permission).

## Theming (color themes)

The app ships all **42 of Mantle web's color themes** (Clean Slate, Claude,
Cosmic Night, …), each with light + dark variants, plus the existing
light/dark/system **mode** toggle. Two independent axes: *mode* (when to be
dark) and *color theme* (which palette).

- **Generated registry.** [`tool/generate_themes.dart`](../tool/generate_themes.dart)
  reads the web repo (`apps/web/lib/themes.ts` + `app/globals.css`), converts
  every token from oklch/hex/hsl → sRGB, and emits
  [`theme/mantle_themes.g.dart`](../lib/theme/mantle_themes.g.dart): a const
  `kMantleThemes` list of `MantleThemeDef` (id, label, radius, picker swatches,
  light/dark `ShadColorScheme`, chart ramps). Re-run it when web themes change —
  it is **not** part of `build_runner`. Output is committed.
- **Building a theme.** `MantleTheme.light(id)` / `.dark(id)` look the def up and
  build a `ShadThemeData` (shared text scale + per-theme radius). `MantleColors`
  is an `InheritedWidget` placed above `ShadApp` that exposes the active theme's
  `chart-1..5` ramp to the markdown renderer (charts have no shadcn home).
- **Selection + persistence.** `ColorThemeController` (mirrors
  `ThemeModeController`) holds the selected id, persisted by `SettingsRepository`
  (`color_theme` key, falls back to default if a stored id was removed from web).
- **Random rotation.** `RandomThemeController` owns the on/off + cadence
  (hour…week); `RandomThemeScheduler` (keepAlive, watched once from the app root)
  reshuffles on the interval and catches up on resume using a persisted
  `last-random-at` timestamp — only while foregrounded (a timer is pointless when
  suspended). A manual pick turns rotation off. UI:
  [`features/settings/appearance_screen.dart`](../lib/features/settings/appearance_screen.dart).

App icon is likewise generated, not hand-cut:
[`tool/generate_app_icon.dart`](../tool/generate_app_icon.dart) composes the
masters from the brand logo (white "m" on Mantle indigo) and
**flutter_launcher_icons** fans them out (no-alpha iOS marketing icon + Android
adaptive icon). See Build & codegen.

## Location (message-attached, opt-in)

The app can attach a device location fix to each turn so the assistant is
location-aware (Mantle reverse-geocodes lazily, server-side — backend shipped in
v0.27.0; contract: `mantle/docs/handover-companion-location.md`).

- **Wire format.** A `LocationPing` ([`data/location/location_ping.dart`](../lib/data/location/location_ping.dart),
  lat/long required, everything else best-effort) rides *on the existing turn* —
  no new endpoint. JSON turn: a `location` key on the body; multipart turn: a
  `location` form field holding `jsonEncode(ping)`. Both handled in
  `ChatApi.sendTurn`.
- **Source.** [`data/location/location_service.dart`](../lib/data/location/location_service.dart)
  wraps **geolocator** + **battery_plus**. `currentPing()` is read-only and
  time-bounded (a short `getCurrentPosition` then last-known fallback) so a send
  is never held waiting; it returns null if permission isn't granted.
- **Opt-in + consent.** Off by default. `LocationController` + the Settings →
  Privacy toggle request *when-in-use* permission on enable and only persist if
  granted (`location_sharing` key). `ChatController.send` attaches a ping only
  when the toggle is on; otherwise the turn is byte-for-byte as before.
- **Native:** iOS `NSLocationWhenInUseUsageDescription`; Android
  `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`.
- **Retry:** location is metadata on the turn; the idempotency-key path resends
  the same ping (a retried send re-fetches, but the server dedups the turn).

## The brain's knowledge on the phone (v1.5)

Three read/capture surfaces over Mantle's existing owner-gated JSON routes — no
new backend was needed. All follow the same layering (Api → controller →
screen) and live under `/pages`, `/tasks`, `/journal`.

- **Pages** (read-only). `PagesApi.list` (`GET /api/pages`) returns the whole
  hierarchy as flat rows (`mode:'tree'`) — the client builds the tree from
  `parentId`; a search/tag filter switches the server to `mode:'list'`.
  Content: **`GET /api/export/{id}?format=md`** — the HTTP twin of the MCP
  `export_node` tool — so the client renders markdown with the same
  `MantleMarkdown` the chat uses and needs **no ProseMirror renderer**.
  In-content images resolve via the authed files route (Bearer header, same as
  chat attachments); links open externally via `url_launcher` (the Android
  `<queries>` manifest entries make `canLaunchUrl` truthful on Android 11+).
  Backlinks come from `GET /api/pages/{id}/backlinks`.
- **Tasks** (capture-first). `GET/POST /api/tasks`, `PATCH /api/tasks/{id}`
  (`status: open|done`), `DELETE`. Server orders open → done, due-date asc,
  then recency; the list renders in server order. Quick-add field on top,
  check-off toggles, long-press → delete.
- **Journal** (capture-first). `GET/POST /api/journal` — entries are plain
  text; the server derives a title when none is given. The capture field
  reuses the chat's mic flow: record → `POST /api/assistant/transcribe` →
  transcript fills the field → save.

## Events & device alarms (v1.6)

Events (`/events`) are the headline v1.6 surface: CRUD over `GET/POST
/api/events`, `PATCH/DELETE /api/events/{id}`, plus **real OS alarms** so an
event rings at its exact start time — offline, app killed, phone locked.

- **"Done" is a tag.** The server has no event status field; the client
  persists the reserved `done` tag via `PATCH {tags}` (`kEventDoneTag`). A
  first-class status field is a flagged backend follow-up.
- **Alarms mirror the server, never replace it.**
  [`data/events/event_alarms.dart`](../lib/data/events/event_alarms.dart)
  `zonedSchedule`s a local notification at `startsAt` plus a heads-up at
  `remindAt` — the same fields the server's events-reminders worker pings on —
  via the **shared** flutter_local_notifications plugin
  ([`local_notifications.dart`](../lib/data/push/local_notifications.dart):
  ONE `initialize`, one tap handler for push display AND alarms; payload
  `event-alarm:<id>:<ms>:<kind>` deep-links to `/events`).
- **Reconcile, don't accumulate.** `EventAlarms.sync` diffs the OS's pending
  schedule against the latest upcoming events by payload after every
  fetch/mutation — a moved event produces a new payload (new alarm + stale
  cancel), a done/deleted event's alarm is cancelled. `eventAlarmSyncProvider`
  (keepAlive, watched from the app root) re-syncs on login and foreground
  resume, so events created on the web or by the assistant also ring on the
  phone. Recurring events carry only their next occurrence (the server rolls
  the row forward); each sync re-arms the following one.
- **Platform specifics.** Android: exact alarms (`SCHEDULE_EXACT_ALARM`,
  runtime grant on 12+, silent inexact fallback when declined),
  `POST_NOTIFICATIONS` on 13+ (requested even when push was never set up),
  boot-persistent receivers (`RECEIVE_BOOT_COMPLETED`). iOS:
  `InterruptionLevel.timeSensitive` + the **Time Sensitive Notifications**
  entitlement, so alarms break through Focus.
- Alarm bookkeeping is deliberately **best-effort** (never throws into the
  caller) — the durable reminder is the server worker's push; the local alarm
  is decoration that also works offline.

## Mantle integration contract

- **Base URL**: user-entered, stored locally.
- **Auth**: `Authorization: Bearer <token>` on every call.
- **Endpoints used**: `/api/version` (probe), `/api/auth/mobile-login`,
  `/api/auth/mobile-logout`, `/api/agents` (agent list),
  `/api/assistant/messages`, `/api/assistant/turn` (JSON or multipart upload),
  `/api/assistant/turn/{id}/stream` (SSE token stream),
  `/api/assistant/turn/{id}/cancel` (stop),
  `/api/assistant/stream` (per-owner SSE ping → refetch),
  `/api/assistant/turn/stage` (coarse stage label, fallback),
  `/api/assistant/transcribe` (voice → text), `/api/files/files/{id}?raw=1`
  (attachment/page image bytes), `/api/dashboard/summary` (landing stats —
  **added to Mantle**), `/api/health` (system vitals),
  `/api/assistant/conversations` (inbox — **added**), `/api/assistant/read`
  (read cursor — **added**), `/api/agents/{slug}/avatar` (avatar SVG —
  **added**), `/api/pages` + `/api/pages/{id}` + `/api/pages/{id}/backlinks` +
  `/api/export/{id}?format=md` (Pages), `/api/tasks` + `/api/tasks/{id}`
  (Tasks), `/api/journal` (Journal), `/api/events` + `/api/events/{id}`
  (Events), `/api/push/*` (enrollment/preferences — see
  [push-notifications.md](push-notifications.md)).
- **Auth-failure contract**: treat **401 OR 3xx→/login** as "session invalid →
  clear token → re-login".

## Testing strategy

- Pure logic / models → plain unit tests.
- Repositories → real **in-memory Drift** + mocked remote.
- Controllers/providers → `ProviderContainer` with overridden deps (mocktail).
- One widget smoke test (boots to server-setup when unconfigured).
- Run: `fvm flutter analyze` (must be clean) + `fvm flutter test`.

## Build & codegen

```bash
fvm flutter pub get
fvm dart run build_runner build      # after provider/model/Drift changes
```

Generated `*.g.dart` are **committed** (repo builds on clone without a codegen
step). Re-evaluate (gitignore + CI-generate) when CI lands.

Two standalone generators (not `build_runner`, run by hand, output committed):

```bash
fvm dart run tool/generate_themes.dart      # color themes ← web globals.css
fvm dart run tool/generate_app_icon.dart    # icon masters ← assets/icon/source
fvm dart run flutter_launcher_icons         # then fan the icon out to platforms
```

## Local dev

App:

```bash
fvm flutter run -d <device-id>
```

Mantle backend to test against (in `~/Projects/mantle`):

```bash
colima start && pnpm infra:up && pnpm db:migrate   # Postgres + migrations
# Mantle web dev server runs on http://localhost:3000 (next dev --turbo)
```

The iOS simulator reaches the host's `http://localhost:3000` directly;
`ios/Runner/Info.plist` has `NSAllowsLocalNetworking` (dev only) to permit
cleartext to local hosts. Production Mantle is HTTPS.

## Known caveats

- **`custom_lint` / `riverpod_lint` removed** — `custom_lint` is pinned to
  analyzer ^8, which conflicts with `drift_dev` 2.34 (needs analyzer ≥10).
  Re-add when `custom_lint` supports analyzer 10+.
- **freezed** resolves to a prerelease (`3.2.6-dev.1`) for analyzer-12 support;
  not yet used in code (chat model is hand-written).

## Roadmap

Shipped through v1.6.0: chat (rich rendering, attachments, voice, streaming +
thought trail), location, push, pages/tasks/journal, events + device alarms.
Still open:

- **Math & syntax highlighting** in markdown (Phase 4 under
  [Chat](#rendering-assistant-replies))
- Drift message **cache + offline send-queue** (the `ChatRepository` seam exists)
- **Events: first-class server status field** (today "done" is the reserved
  `done` tag — flagged as a backend follow-up)
- **Write surfaces for Pages** (currently read-only)
- Migrate Android to **AGP built-in Kotlin** so the `file_picker` 8.x pin can
  lift (see `android/gradle.properties`)
