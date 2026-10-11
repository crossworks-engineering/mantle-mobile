# Jackdaw (mobile) — Architecture

A handover-oriented map of the app: what it is, how it's structured, and how it
talks to Mantle. Pair this with [styling-guide.md](styling-guide.md) for UI rules.

## What this is

A cross-platform (iOS + Android) Flutter app — a mobile companion for the
**self-hosted Mantle** personal assistant. It connects to a user's own Mantle
server over an authenticated REST API.

Scope, in order of build:

1. **Chat** with the assistant — rich rendering, attachments, voice, and (v1.3–
   1.4) live token streaming with a thought trail
2. **Message-attached location** — coordinates stapled to a message, read
   on-demand at send time (foreground only → "When In Use", never "Always")
3. **Push notifications** from Mantle
4. **The brain's knowledge on the phone** (v1.5) — read-only **Pages**, and
   capture-first **Tasks** + **Journal**
5. **Events with real device alarms** (v1.6) — OS-scheduled local notifications
   that ring at the exact start time, offline, phone locked
6. **Notes** (v1.7) — the capture primitive: quick-add, tag filter, markdown
   view + edit
7. **Global search** (v1.8) — the brain's hybrid FTS+vector engine over
   `GET /api/search` (**needs Mantle ≥ v0.148.0**), type filters, deep links
8. **Files** (v1.9) — folder browser, authed image preview, camera/library/
   document upload into any folder
9. **Offline chat** (v1.10) — Drift read cache + an idempotent send-queue
   (see [Chat](#offline-cache--send-queue-v110))
10. **Markdown math + code highlighting** (v1.11) — `$…$`/`$$…$$` TeX and
    theme-token syntax highlighting (closes rendering Phase 4)
11. **Several logins** on one phone, on one brain or many (see
    [Several logins](#several-logins)), and QR sign-in
12. **The folder tree**: Pages, Notes and Files browse the brain's one
    folder tree (see [The folder tree](#the-folder-tree))

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
| Math | **flutter_math_fork** | `$…$` / `$$…$$` TeX in chat + pages |
| Code highlighting | **re_highlight** | Curated language set — NOT `languages/all.dart` (the full registry ground kernel compiles to 30+ min) |
| Tests | flutter_test + **mocktail** + in-memory Drift | 138 tests |

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
                     chat_repository.dart     — Drift read cache + offline send-queue
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
    tree/            tree_models.dart         - the folder tree's wire shapes (ONE file)
                     tree_api.dart            - GET /api/tree/:kind (+search, marks, move)
    pages/           pages_api.dart, pages_models.dart      — index/meta/markdown/backlinks
    nodes/           nodes_api.dart           — GET /api/nodes/{id} (type resolver), draw SVG
    notes/           notes_api.dart, notes_models.dart      — CRUD + tag facets
    search/          search_api.dart, search_models.dart    — GET /api/search hits
    files/           files_api.dart, files_models.dart      — folders/files/upload
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
                     last_message_card.dart    - the newest message received, on top
    tree/            tree_controller.dart      - one folder (family by kind + folder),
                                                 search, Recent, the older-brain marker
                     tree_browser.dart         - the shared folder browser
                     tree_rows.dart            - folder/item tiles, glyph, badge, trail
    pages/           pages_controller.dart, pages_screen.dart (folder browser),
                     page_view_screen.dart     — markdown, chips, images, backlinks
                     folder_index.dart         - the Folder index block
    notes/           notes_controller.dart, notes_screen.dart,
                     note_view_screen.dart     — markdown view + edit sheet
    search/          search_controller.dart (debounce + stale guard),
                     search_screen.dart        — filter chips + per-type routing
    files/           files_controller.dart (family by folder path),
                     files_screen.dart, file_image_screen.dart
    tasks/           tasks_controller.dart, tasks_screen.dart
    journal/         journal_controller.dart, journal_screen.dart (mic capture)
    events/          events_controller.dart, events_screen.dart (+ add sheet)
    pending/         pending_controller.dart, pending_screen.dart — approvals
    settings/        theme_mode_controller.dart, settings_repository.dart
                     color_theme_controller.dart  — colour theme id to paint
                     brain_appearance_sync.dart   — follows the brain's theme
                     random_theme_controller.dart — shuffle mode + scheduler
                     location_controller.dart     — location sharing opt-in
                     push/                        — push enrollment screens
                     settings_screen.dart      — sections → subscreens
                     appearance_screen.dart    — mode + color picker + shuffle
  widgets/           mantle_header.dart         — shared primary header bar
                     secret_input.dart          — masked field + show/hide eye
                     pull_to_refresh.dart       - the Material-free pull to reload
  routing/           app_router.dart           — go_router + redirect
  theme/             mantle_theme.dart          — theme builder + MantleColors
                     mantle_theme_def.dart      — the shape of one theme
                     mantle_themes.g.dart       — generated: every web theme
                     app_tints.dart             - the 13 folder tints, mixed per theme
                     lucide_names.dart          - the web's curated folder icons by name
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

- **Drift** (schema v3): `sessions` holds the logins (see Several logins);
  `app_settings(key, value)` holds the server URL
  (`server_base_url`) and theme mode (`theme_mode`); `cached_messages` is the
  chat read cache (raw history-row JSON per agent, pruned to the newest 200);
  `outbox_turns` is the offline send-queue (row id = the turn's idempotency
  key). Migrations live in Drift's `schemaVersion`/`onUpgrade`. Tests use
  `AppDatabase.forTesting(NativeDatabase.memory())`.
- **Secure storage**: only bearer tokens, one item per login held
  (`mantle_bearer_token.<sessionId>`), plus the push keypair.

## Networking

`dioProvider` builds a Dio whose base URL comes from `ServerConfig` (so it
rebuilds when the server changes). The interceptor:

- **onRequest**: injects `Authorization: Bearer <token>` from `TokenStore`,
  but ONLY when the active login belongs to the brain this client was built
  for. A bearer is never sent to a brain that did not mint it, whatever order
  a switch happens in.
- The client is rebuilt on `sessionEpochProvider`, bumped whenever the login in
  use changes. The address alone would miss a switch between two logins on one
  brain, and what was fetched as the last login would be served to this one.
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
`getSessionUser()` and the gate accept it, so **every existing endpoint works
with the mobile token, no per-route changes**. `mobile-logout` revokes by `jti`.

### Several logins

The phone holds several logins, on one brain or many
(`data/auth/session_repository.dart`). A **session** is one (brain address,
login) row in the Drift `sessions` table; its bearer is a keychain item under
its id; exactly one is active (`active_session_id`). The `server_base_url` and
`account_email` settings are kept as **mirrors of the active session**, so the
Dio client, Settings and everything else that reads them needs no idea that
there can be more than one. `TokenStore.read/write/clear` are likewise a view
over the active session.

- **Adding a login steps OUT of the one in use first** (`startAddLogin`), then
  walks the same setup → login screens as a first sign-in; "Back to the login I
  was using" returns. Nothing runs alongside, because the client is built from
  the active address and must never be pointed at a second brain while the
  first login's bearer is attached.
- A sign-in makes its session active BEFORE the token is minted, so the token
  lands under the right id; a failed one removes a row made for it and nothing
  else. Signing in again as a held login reuses its row.
- `cached_messages` and `outbox_turns` are keyed by session. An unsent message
  is sent as the login that wrote it or not at all. Work that spans an await
  (a fetch, a send, a flush) reads the session id once, when it starts, and
  files its rows under that id; a flush stops when the active login changes.
- The way back while a login is being added (`resume_session_id`) is kept in
  `app_settings`, so it survives the app being killed. The sign-in screen
  lists the logins still held: after a refused bearer, or a restart mid-add,
  the others are a tap away with no password.
- Data controllers watch their API provider, so a switch (even between two
  logins on one brain) fetches the screens again as the new login. A request
  that went out with no bearer (mid-switch to another brain, before the
  address catches up) never signs the login in use out on a 401.
- Push: the keypair is the device's, the subscription id is per login, and the
  keypair goes only when no login is connected. Event alarms and the Android
  direct-connection stream follow the ACTIVE login: the session wipe stops
  them, and the alarm sync and `DirectPushFollow` start them again for the
  next login. Wanting the direct connection is a device setting
  (`direct_push_wanted`), not a login's; an install updated from a build
  before several logins keeps it on.
- Screens: Settings → Logins (`features/auth/logins_screen.dart`) and the quick
  switch, a bottom sheet opened from the home wordmark. A list with tap to
  switch, sign out and add. No editor, per the phone's scope rule.
- The update from the single-login build (schema v2 → v3) turns the saved
  server and email into session #1, gives unsent messages to it, and records
  it as the ONE owner of the old keychain item, which moves under it at the
  next start-up. Nobody is signed out. Without a recorded owner (an iOS
  reinstall keeps the Keychain but not the database) the old item is never
  adopted, so another brain never receives it, and the next sign-in deletes
  it. The upgrade runs in one transaction and is safe to run twice.

**When a session ends** — the user signs out, or a request comes back 401 /
redirected to `/login` (`core/network/auth_failure.dart` is the one
definition, shared with the SSE stream and the direct-push isolate) — the
device is wiped, not just the token (`data/auth/session_wipe.dart`): the chat
read cache and the offline outbox (`AppDatabase.clearUserData`), the push
keypair and subscription marker, every scheduled event alarm, and the
direct-push foreground service. Sign-out also unpairs push server-side first,
while the token is still valid; the 401 path makes no network calls (it runs
inside the failed request) and is idempotent, so a burst of failures wipes
once. Only a failure to clear the *token* keeps the session, and sign-out
shows it inline.

With several logins, "the session" is the ACTIVE one and the wipe is scoped to
it. Signing out also forgets its row and lands on the next login held; a
refused bearer keeps the row, marked as needing a sign-in, switches to nobody,
and the login screen starts with that email.

**Server address rules** (`serverUrlProblem`): `https://` anywhere;
`http://` only for a private host (loopback, RFC 1918, link-local, `.local`,
a bare LAN name); no credentials in the address. A typed address without a
scheme is taken as `https://`. The probe does not follow redirects, so an
address that only works by redirecting is reported unreachable rather than
saved.

**Deep links from notifications** pass `sanitizeDeepLink`: absolute in-app
paths matching the router's own routes, nothing else. A route added to
`app_router.dart` is not reachable from a push until it is added to that
allowlist too; anything unmatched at the router lands on a themed
not-found screen. A tap also picks the login it was for and the item it
is about; see `docs/push-notifications.md` §9.2b.

### Which address is "the server" (Mantle ≥ v0.200.0)

Mantle's v0.200.0–v0.202.0 split carved the owner UI out of the server: a
deployment can serve the brain on one vhost and the owner app on another
(`app.<domain>`), and **the app must point at the brain** — the owner-app origin
carries no `/api` at all. That makes the address people see in their browser the
one thing guaranteed not to work.

`probeMantleServer` therefore returns a `ServerProbe`, not a bool:

- `ServerProbeBrain` — `GET /api/version` answered; save this address.
- `ServerProbeClientApp` — it's the owner app. `client/web` serves `/env.js`
  (public) advertising `serverOrigin`, so the app recovers the brain address,
  verifies it, and offers it. The setup screen **rewrites the field and says
  so** rather than connecting somewhere the user didn't type.
- `ServerProbeUnreachable` — neither.

Single-host installs — one hostname path-routing `/api` to the server and
everything else to the owner app, which is how `dev` and `jason-prod` are set
up — never reach the recovery branch, because `/api/version` answers first.
They also advertise their own hostname as `serverOrigin`, and an origin equal
to (or empty, meaning same as) the address just probed is rejected, so the
recovery can't loop back onto an address already found dead.

The split otherwise changed nothing for this app: the mobile bearer was the
mechanism the split was designed around, `/api/**` still answers a credential-less
request with a clean 401 (never an HTML redirect), CORS never engages because a
native client sends no `Origin`, and `mobile-login` is deliberately frozen at its
original path, shape and 1-year TTL. Contract details:
`mantle/docs/mobile-companion-backend.md` §The frontend/server split.

## Workspaces: every login on the phone (1.15.0, build 27)

From brain W7e on, any login the brain serves to the phone (an Admin user or
a member) signs in here. A client login is refused (403 `client-login`).

- **Build header.** Every request carries `X-Jackdaw-Mobile: <version>+<build>`
  (`core/network/mobile_build.dart`), on the app client, the identity
  client, the refresh and the Android direct connection. The brain serves a
  member only to build 27 or newer; an older build gets 426 `update-app`.
- **Sign-in.** `POST /api/auth/device-login` for every login (30 days); a
  brain without it (404) falls back to the frozen `mobile-login`. 426 says
  "Update Jackdaw"; 403 `client-login` shows the brain's words.
- **Refresh.** `POST /api/auth/token/refresh` at start, after a switch and on
  a stale resume (`data/auth/token_refresh.dart`). The newest token is
  always stored; a 401 signs that login out, anything else keeps the token.
  While a rotation runs, the app client holds its requests
  (`TokenRefreshGate`): a rotated token used after its successor ends every
  session of the login on the brain. The direct connection reads the bearer
  again before every connect for the same reason.
- **Access.** `GET /api/auth/whoami` (role, workspaces, areas, isOwner) is
  cached per login in `app_settings` (`login_access.<session>`), cache first
  (`features/auth/login_access_controller.dart`); a sign-in writes the role
  it answered so a member never sees an Admin user's surface while whoami
  is on its way. `currentAccessProvider` is null while it is being worked
  out. `LoginAccess` says what the phone offers: the Admin workspace's own
  items (tasks, journal, events, up next, alarms) to an Admin user, pending
  approvals and the brain stats with the settings area, the agent catalog
  and avatars with the assistants area, push settings to an Admin user. The
  router sends a refused screen home (`routeAllowed`).
- **Workspace in use.** Picked in the drawer (the quick switch sheet) and
  kept per login (`workspace.<session>`); home shows it as a pill. Chat goes
  to that workspace's assistant (`GET /api/workspaces` names it), the inbox
  in the Admin workspace.
- **Chat for a member.** Text only (no attach button; also for an Admin user
  with another workspace's assistant), no live turn stream: a 202 turn is
  polled from the thread until the reply lands. Refusals say why on the
  bubble (daily cap, token budget, a reused key, no assistant, text only).
- **Bytes.** Pictures load from `/api/files/files/:id?raw=1` and
  `/api/draws/:id/svg` for every login; a reply that names the deprecated
  member routes is read from these. A refused picture never signs out.
- **Pages for a member.** The markdown export is an Admin user's route; when
  it is refused the page view renders the page's ProseMirror document
  (`data/pages/prosemirror_markdown.dart`).
- **Tree chips.** Rows show the workspaces that read a folder or an item
  (two, then "+N") and "Public" for a live link.

Not in this build: push for a member (its routes are under `pushBase`,
`/api/member/push`, and its payload's deep links), Telegram pairing.

## Agents — the server owns the list and the default

`AgentController` merges two calls at launch:

- `GET /api/agents` — the rich rows (name, role, `avatar`), filtered by the
  server to conversational roles but **not** to `enabled`.
- `GET /api/assistant/thread?withMessages=0` — Mantle's own answer to *which
  agents may this login chat to* (`agents`: roles **and** enabled) and *which
  one is it talking to by default* (`agent`: `resolveAgentForActor`, which since
  Mantle v0.224 prefers the agent bound to this login over the brain-wide
  priority default). `withMessages=0` suppresses the 100-message thread the
  chat screen would refetch from its own cache anyway.

The two are intersected, so the app never re-implements either rule. Both
degrade safely: a failed or unrecognised thread response leaves the full list
and the first-by-priority default, exactly as before.

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

### The last message, on Home

`LastMessageCard` ([`features/home/last_message_card.dart`](../lib/features/home/last_message_card.dart))
sits above the home tiles: the newest message the person RECEIVED across
every agent (`latestReceived`: a thread whose last message is the agent's),
with the agent's avatar and name, the text rendered by `MantleMarkdown` and
cut to a few lines, when it arrived, and a "New" pill while it is unread.
Tapping it opens the thread, which marks it read. It reads the inbox
(`ConversationsController`), which refetches on foreground resume and on
every conversation-stream ping, so a message that arrived while the app was
away is there when Home opens, with no refresh. A chat push still deep-links
to `/chat/<slug>`; the card is for every other way of arriving. With nothing
received it takes no room.

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
4. **Math & syntax highlighting (done, v1.11)** — `$…$` / `$$…$$` TeX via
   flutter_math_fork, parsed by `MathInlineSyntax`/`MathBlockSyntax` in
   `mantle_syntax.dart`. Currency guards: the opening `$` can't precede
   whitespace, the closing `$` can't follow whitespace or precede a digit,
   and digits-plus-punctuation-only content is emitted as plain TEXT — and
   crucially it is *consumed* (an inline syntax must NEVER match without
   consuming: returning false from `onMatch` after a regex match loops the
   parser forever — this cost a debugging session, see the code comment).
   Invalid TeX falls back to the raw source in monospace. Fenced code blocks
   with a known language render through `code_highlight.dart` (re_highlight):
   a **curated ~26-language set** — importing `languages/all.dart` (~190
   grammars) blew test-bundle kernel compiles past 30 minutes — with the
   colour map is the active theme's own `code-*` inks, so
   highlighting follows light/dark and every colour theme. Unknown
   languages and inline code fall through to the default stylesheet path.
   A ```mermaid fence (the retired diagram engine; stored docs still carry
   the source) renders as plain code under a "legacy diagram" caption.
5. **Reference links and link routing (done)** — the page export invents
   round-trip syntaxes for editor-only nodes: `[Title](page:<id>)` (child
   page), `[label](mention:node|entity:<id>)`, `[name](media:<fileId>)`
   (file embed), `![alt](media:<fileId>)` (uploaded image), `![alt](draw:<id>)`
   (drawing). [`markdown/mantle_refs.dart`](../lib/features/chat/markdown/mantle_refs.dart)
   (`RefInlineSyntax`, registered BEFORE the stock link syntax) lifts them
   into `mantleRef` elements; [`markdown/ref_widgets.dart`](../lib/features/chat/markdown/ref_widgets.dart)
   renders chips (page → `/pages/<id>`; node mention → resolved by type via
   `GET /api/nodes/{id}` then routed like search results; entity mention → a
   name tag, not tappable; file → the image screen for pictures, else the
   web permalink until the file opener lands; drawing → the web) and images
   (`media:` through the authed `fileBytesProvider`, `draw:` through
   `GET /api/draws/{id}/svg`, http(s) direct; a failed fetch is an alt-text
   chip, never a spinner). Every other href goes through `MantleLink.parse`:
   http/https/mailto to the OS, `/pages/<id>` and `/notes/<id>` in-app,
   `/n/<id>` resolved by type, any other brain path to the web against the
   configured server, `#anchors` rendered as plain words. Chips and images
   carry `Semantics(button, label, excludeSemantics)` so a screen reader
   hears "Open page X" once. Inline widgets inside a selectable paragraph
   are real widgets (tap works) but sit in a `SelectableText`, so the tests
   find them by semantics label and scroll them into view first.

### Attachments & voice

The composer ([`features/chat/chat_composer.dart`](../lib/features/chat/chat_composer.dart))
is a two-row layout — the text field on top (grows to 6 lines), with the attach
button (photo library / camera via **image_picker**, document via
**file_picker**), the hold-to-talk mic, and the send/stop button on the row
below. Both attach and voice reuse Mantle's existing endpoints — no new server
work:

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
- **Voice (dictation into any field).** One mechanism app-wide, in three
  pieces:
  [`features/voice/voice_capture.dart`](../lib/features/voice/voice_capture.dart)
  `VoiceCapture` (the controller: permission → **record** → `.m4a` temp file
  → `POST /api/assistant/transcribe` via `voiceTranscriberProvider` → the
  words; a 60 s cap; a release that beats the recorder's start-up is a
  no-op; states `idle | recording | transcribing`),
  [`widgets/hold_to_talk_button.dart`](../lib/widgets/hold_to_talk_button.dart)
  `HoldToTalkButton` (press-and-hold: hold records, release transcribes,
  slide up/left discards; a plain tap toggles for anyone who cannot hold;
  haptics on start/stop; a pulsing dot + elapsed while held), and
  [`widgets/voice_text_field.dart`](../lib/widgets/voice_text_field.dart)
  `VoiceTextField` (a `ShadInput` with the button inside its right edge,
  height-neutral like `SecretInput`; `insertTranscript` puts the words at the
  caret with spacing so a second hold extends). Every new-item field is a
  `VoiceTextField`: task quick-add + edit title, note quick-add + edit
  title/body, event title, journal composer + entry sheet. The chat composer
  keeps its mic in the action row (a bare `HoldToTalkButton`) and inserts
  into the field the same way. **Nothing auto-submits** — the transcript is
  reviewed and then saved/sent by the normal button (Whisper invents words
  on silence; same policy as the web `use-voice-input.ts`). The chat's old
  tap-to-record → tap-to-send flow was retired 2026-09-17 for this. A failed
  transcription (422) surfaces the server's message in the field's error
  line; a missing STT worker (**412**) shows the hint once and
  `SttAvailability` hides every mic for the rest of the session.
  Recorders are built through `voiceRecorderFactoryProvider` and lazily, so
  a screen that merely shows a mic never touches the plugin — tests override
  the factory with `FakeVoiceRecorder` (`test/helpers/`).
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

### Offline cache & send-queue (v1.10)

The `ChatRepository` seam is now real — network-first with an on-device
fallback, in [`data/chat/chat_repository.dart`](../lib/data/chat/chat_repository.dart):

- **Read cache.** Every fetched LATEST page is written to Drift
  `cached_messages` as the **raw server row JSON** and re-parsed through the
  same `ChatApi.messageFromHistory` as the wire — cache and contract cannot
  drift. When a fetch fails on a *connectivity* error (`isOfflineError`:
  connection error/timeout, send timeout, SocketException — deliberately NOT
  `receiveTimeout`, the server may have the turn), the cache answers instead,
  flagged `HistoryPage.fromCache` → the thread shows an offline banner with a
  Retry. Only the latest page falls back; older pages can't be answered
  honestly offline. Pruned to the newest 200 rows per agent.
- **Send-queue.** A text-only turn failing on connectivity is queued in
  `outbox_turns` — **the row id IS the turn's idempotency key**, so a flush
  that races a half-delivered send replays instead of duplicating. The
  controller swaps the optimistic bubble for a `queued` one ("Queued — sends
  when back online"). Attachment turns are never queued (fail fast, as
  before). Flush points: thread open, app foreground resume, and before every
  new send (so an offline backlog lands in written order ahead of the new
  turn). A server-rejected row is retried across flushes and dropped after 3
  attempts so one poisoned turn can't wedge the queue. Delivered turns
  surface via a normal history refetch.

## Theming (color themes)

The app paints **every colour theme the web has** — 43 today, including the
brand themes `jackdaw`, `jackdaw-harvest` and `pinnacle` — each with light +
dark variants, plus the light/dark/system **mode** toggle. Two independent
axes: *mode* (when to be dark) and *color theme* (which palette). Nothing is
hand-written on the phone: the brand themes are authored once, in mantle's
seeds, and reach the phone through the same port as every other theme.

- **Source of truth.** mantle `packages/share-ui/themes/seeds.mjs` (authored)
  → mantle's generator → `styles/themes.css` + `src/lib/theme-registry.gen.ts`
  (generated). A copy of those two generated files is checked in under
  [`tool/themes/`](../tool/themes/) with the mantle commit recorded in
  `tool/themes/SOURCE`; [`tool/sync_themes.sh`](../tool/sync_themes.sh)
  refreshes the copy from a mantle checkout and regenerates.
- **Generated registry.** [`tool/generate_themes.dart`](../tool/generate_themes.dart)
  reads that copy and emits
  [`theme/mantle_themes.g.dart`](../lib/theme/mantle_themes.g.dart): the const
  `kGeneratedThemes` list of `MantleThemeDef` (shape in
  [`theme/mantle_theme_def.dart`](../lib/theme/mantle_theme_def.dart): id,
  label, radius, and per mode a `ShadColorScheme`, the picker swatches, the
  `chart-1..5` ramp, the `primary`/`destructive` inks, the `success` /
  `warning` / `info` roles as fill + `-foreground` + ink, and the five
  `code-*` inks). `--check` regenerates in memory and fails on drift. It is
  **not** part of `build_runner`; the output is committed.
- **Two CI gates** (`verify.yml`): the port must match the copy
  (`generate_themes.dart --check`), and the copy must match mantle `main`
  (the `themes-upstream` job, a sparse checkout of the two files). Either
  drifting fails the build, so a theme changed on the web cannot be missing on
  the phone without someone noticing.
  [`test/theme/theme_port_test.dart`](../test/theme/theme_port_test.dart)
  proves the same thing offline, token by token.
- **Building a theme.** `MantleTheme.light(id)` / `.dark(id)` look the def up and
  build a `ShadThemeData` (shared text scale + per-theme radius). `MantleColors`
  is an `InheritedWidget` placed above `ShadApp` that exposes the tokens
  beyond the scheme — chart ramp, status fills and inks, code palette — to
  the markdown renderer, the code highlighter and the status meters.
- **Fill vs ink.** The web's contract, kept here: a fill (`success`) sits behind
  its own `successForeground` (meters, dots, badges); an ink (`successInk`)
  is the same role solved for text or an icon on a themed surface. Never a
  fill as text. Callouts tint with the fill and draw their icon in the ink,
  exactly as the web's callout view does.
- **Selection + persistence.** `ColorThemeController` (mirrors
  `ThemeModeController`) holds the id to paint, resolved by
  `SettingsRepository.colorTheme()` in order: a theme picked on this phone
  (`color_theme`), else the brain's own theme (`brain_color_theme`), else
  the default. A pick no longer in the registry is skipped, not defaulted.
- **The brain's theme.** The colour theme is system-wide on the web, stored on
  the anchor owner's profile and served by the public `GET /api/appearance`.
  `BrainAppearanceSync` (keepAlive, watched from the app root like the alarm
  sync) reads it on sign-in and on every foreground resume and stores
  `colorTheme`, so a theme set on the web shows on the phone the next time it
  comes to the front. The Appearance screen shows it as "Brain's theme" at the
  top of the picker; picking any other theme is a local override, and tapping
  the brain row again clears it. Changing server clears the stored brain
  theme (it was the old server's). A brain theme the phone has no port for
  paints the default until the next regenerate.
- **Random rotation.** `RandomThemeController` owns the on/off + cadence
  (hour…week); `RandomThemeScheduler` (keepAlive, watched once from the app root)
  reshuffles on the interval and catches up on resume using a persisted
  `last-random-at` timestamp — only while foregrounded (a timer is pointless when
  suspended). A shuffle is a local pick (it overrides the brain); a manual pick
  turns rotation off. UI:
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

- **Pages** (read-only). The index is the pages tree (see
  [The folder tree](#the-folder-tree)): pages do not nest, a page's place is
  its folder. `PagesApi.list` (`GET /api/pages`, flat rows) is only read for
  a brain older than the tree.
  Content: **`GET /api/export/{id}?format=md`** — the HTTP twin of the MCP
  `export_node` tool — so the client renders markdown with the same
  `MantleMarkdown` the chat uses and needs **no ProseMirror renderer**.
  "Renders correctly" therefore means: every construct mantle's
  `doc-to-markdown.ts` can emit has a phone-side builder, including the
  round-trip syntaxes it invents for editor-only nodes (see "Reference
  links" under Rendering assistant replies). The proof is the **golden
  page** — dev brain page `90971a5c-95b3-4365-aac6-b070f7108eb5`, one of
  every node — whose server export is checked in as
  [`test/fixtures/golden_page.md`](../test/fixtures/golden_page.md) and
  asserted construct by construct in
  [`test/features/page_view_test.dart`](../test/features/page_view_test.dart).
  The export covers the COMMITTED doc only; a page with a body and a draft
  shows the body, a draft-only page says so instead of "empty".
  Backlinks come from `GET /api/pages/{id}/backlinks`. The page detail
  carries `folderId`, which the **Folder index** block reads (below).
- **Tasks** (capture-first). `GET/POST /api/tasks`, `PATCH /api/tasks/{id}`
  (`status: open|done`), `DELETE`. Server orders open → done, due-date asc,
  then recency; the list renders in server order. Quick-add field on top,
  check-off toggles, long-press → delete.
- **Journal** (capture-first). `GET/POST /api/journal` — entries are plain
  text; the server derives a title when none is given. The capture field
  reuses the chat's mic flow: record → `POST /api/assistant/transcribe` →
  transcript fills the field → save.

## Notes, Search, Files (v1.7–v1.9)

Three more surfaces over owner-gated JSON routes, same layering as v1.5:

- **Notes** (`/notes?folder=`, `/notes/:id`). The list is the notes tree
  with a capture field on top that saves into the OPEN folder and the kind's
  tags as filter pills. `POST /api/notes` takes no folder, so a capture into
  a folder is a create followed by the tree's item move (`NoteFiling`). The
  note view renders content with `MantleMarkdown`; the edit sheet PATCHes
  title, content and comma-separated tags (`GET/PATCH/DELETE
  /api/notes/{id}`). `GET /api/notes` (paged 50, tag facets) is only read
  for a brain older than the tree.
- **Search** (`/search`, also the magnifier in the home header).
  `GET /api/search?q&type&limit` — **added to Mantle in v0.148.0**; the
  server embeds the query for vector-led hybrid ranking and degrades to FTS
  if embedding fails. Controller debounces ~350 ms at ≥2 chars with a
  request-sequence guard (a stale response can never overwrite a newer one).
  Hits route by type: page/note → their view screens, task/event/journal →
  their lists; everything else opens a sheet with the summary and an "Open
  in Mantle" link (the server's absolute `/n/<id>` permalink resolves any
  node type web-side). A hit says the folder it is filed in, read off its
  ltree `path` (slugs, so `clients › acme corp`, not the folders' names).
- **Files** (`/files?folder=`). The list is the files tree with the upload
  row on top: camera, photo library or any document, uploaded into the OPEN
  folder by its ltree path (`POST /api/files/files`, multipart `{parentPath,
  file}`; 409 duplicate-name and 413 too-large surfaced inline). Image files
  open a full-screen authed preview (`fileBytesProvider` +
  `InteractiveViewer`); everything else gets the open sheet
  (`file_open_sheet.dart`): **Open**, **Share**, and "Open in Mantle". A tree
  row knows a file's id and name, so the row is fetched first (`GET
  /api/files/files/{id}`) for its type and size. A `media:` chip on a page
  for a non-image opens the same sheet. `GET /api/files/folders?parent=` and
  `/api/files/files?parent=` (`/files?path=`) are only read for a brain
  older than the tree.
- **Opening a file** (`FileOpenService`). A system viewer cannot send the
  bearer, so the file is downloaded INSIDE the app with the bearer and the OS
  is handed a local copy; no credential leaves the app. The download streams
  to disk (dio `download`, `.part` then rename, progress, cancel), never into
  memory. Hand-off is `open_filex` (Quick Look style preview on iOS,
  `ACTION_VIEW` through its bundled FileProvider on Android); when no app
  claims the type it falls back to the share sheet (`share_plus`). Copies live
  in the CACHE directory under `opened_files/<id>/<version>/<filename>` (the
  id escaped as one path segment, the version the file's last change and
  size, older versions removed), never
  Documents, are capped at 500 MB (oldest first) and are removed by the
  session wipe (sign-out and a dead token). Above 100 MB the button names the
  size, so a large download is chosen and not triggered by a row tap. Viewing
  only: editing stays on the web. `open_filex` declares storage and
  media-read permissions the app does not need; the manifest strips them
  (`tools:node="remove"`), which also keeps Play's photo and video policy out
  of the picture. Not built yet: in-app PDF and video viewers, HTTP Range on
  the server, and folding the two pick-then-upload copies into this service.

## The folder tree

The brain files every kind in ONE folder tree (mantle `docs/folder-tree.md`,
Mantle v0.232.366 and later): folders nest three deep, carry an icon and a
tint, can be shared with the team or with clients, and an item's place is
its folder. Pages, Notes and Files on the phone are that tree.

- **Wire shapes** are one file,
  [`data/tree/tree_models.dart`](../lib/data/tree/tree_models.dart),
  mirrored by hand from mantle `packages/client-types/src/tree.ts` (the
  brain has no OpenAPI). `test/fixtures/tree/` holds REAL responses and
  `test/data/tree_models_test.dart` parses each. The same shapes serve an
  admin, a member and a client: a client's tree leaves out the staff fields
  (level, share, state), so those are nullable here.
- **Reads are lazy** (`TreeApi`): `GET /api/tree/:kind?folder=&cursor=&sort=`
  answers one folder's subfolders (all of them) and one page of its items
  (50); the cursor is keyset, so paging never skips or repeats. A cursor
  page carries NO folders: the controller keeps the first page's.
  `…/search?q=&tag=` finds folders then items, each with the crumbs of where
  it lives; `…/marks?view=recent` is this login's recently opened items;
  `…/tags` the kind's tags. `POST /api/tree/items/:id/opened` counts an open
  (what Recent lists).
- **One browser** ([`features/tree/tree_browser.dart`](../lib/features/tree/tree_browser.dart))
  serves all three screens: folders first, then items; tap a folder to drill
  in (state inside the screen, not a route per level, so the trail can jump
  anywhere), tap the trail to climb out; items page in as the list scrolls;
  pull down to reload. It ALWAYS opens on Folders; Recent is one tap away
  and is never remembered (the web's rule). `?folder=<id>` opens it on a
  folder; Back from there returns to where the reader came from.
- **Controllers** ([`tree_controller.dart`](../lib/features/tree/tree_controller.dart)):
  `TreeFolderController` is a family by kind and folder id, so each level
  keeps its rows and going back up shows them at once. A refresh keeps the
  rows on screen. Tree reads have Riverpod's automatic retry turned OFF
  (`noTreeRetry`): the tree's two refusals are answers, not glitches.
- **An older brain.** `GET /api/tree/:kind` with no folder answering **404**
  is a brain from before the tree (`TreeUnavailable`): the kind is marked in
  `treeUnavailableKindsProvider` and its screen shows the list it had before
  (`PagesListScreen`, `NotesListScreen`, `FilesListScreen`), without asking
  again until the brain or the login changes, or the app comes back to the
  front more than ten minutes after the mark. A 404 WITH a folder named is
  that folder, gone or not shared (`TreeFolderMissing`).
- **Writes that change who can read.** Filing into a shared folder shares
  the item. The brain refuses such a write with **409** `{error:
  'visibility', changes, total}` and writes nothing
  (`TreeVisibilityRefusal`); the app shows who would read it and repeats the
  call with `confirm` (and `seen`, the total it showed) only on a yes. This
  covers a note captured into a shared folder (`POST /api/tree/notes/move`)
  and an upload into one (`confirm=true` as a form field ahead of the file).
  A note the person declines to share stays at the top level, and the
  screen says so. The phone does not create, rename, move or share folders:
  that is the web's job (the scope rule).
- **Tints and icons.** A folder's `color` is one of 13 keys, never a
  colour. [`theme/app_tints.dart`](../lib/theme/app_tints.dart) mixes the
  web's hue for the key into the theme in OKLab (18% over `background` for
  the fill, 72% into `foreground` for the ink), the web's own formula, so a
  tile is legible on every theme in both modes. `icon` is an emoji or
  `lucide:<name>`; [`theme/lucide_names.dart`](../lib/theme/lucide_names.dart)
  is the web's curated set by lucide's own names. An unknown tint or name
  draws the default tile.
- **The Folder index block** ([`features/pages/folder_index.dart`](../lib/features/pages/folder_index.dart)).
  A page can list a folder's pages live: `[Folder index](folder:<id>)` or
  `folder:here` (the page's own folder), alone on a line
  (`FolderIndexSyntax`). The viewer reads the folder through the pages tree,
  by name, up to ten pages of 50, then says the list was cut. `here` comes
  from the page detail's `folderId` via `PageFolderScope`; a brain that does
  not send it (and any markdown outside a page) shows the block's label
  alone, never the root. A folder the reader cannot open says so. The same
  link inside a sentence is an inert label, as on the web.

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
  (Events), `/api/notes` + `/api/notes/{id}` (Notes), **`/api/search`**
  (global search — **requires Mantle ≥ v0.148.0**; older servers 404→401 it),
  `/api/files/files` (multipart upload) + `/api/files/files/{id}` (Files),
  **`/api/tree/{kind}`** + `/search` + `/marks` + `/tags` + `/move` and
  `/api/tree/items/{id}/opened` (the folder tree for Pages, Notes and Files;
  **Mantle ≥ v0.232.366**; an older brain answers 404 and the app falls
  back to `/api/pages`, `/api/notes`, `/api/files/folders`),
  `/api/push/*` (enrollment/preferences — see
  [push-notifications.md](push-notifications.md)).
- **Auth-failure contract**: treat **401 OR 3xx→/login** as "session invalid →
  clear token → re-login".

## Testing strategy

- Pure logic / models → plain unit tests.
- Repositories → real **in-memory Drift** + mocked remote.
- Controllers/providers → `ProviderContainer` with overridden deps (mocktail).
- Screens → widget tests through `test/helpers/pump_screen.dart`.
- An API client's requests and refusals → a real Dio over
  `test/helpers/stub_dio.dart`, answered with real response bodies.
- Wire shapes → fixtures taken from a real brain (`test/fixtures/tree/`).
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
fvm dart run tool/generate_themes.dart      # color themes ← web globals.css (see caveat above)
fvm dart run tool/generate_app_icon.dart    # icon masters ← branding/
fvm dart run flutter_launcher_icons         # then fan the icon out to platforms
fvm dart run tool/generate_lockups.dart     # badge+wordmark lockups ← branding/
fvm dart run flutter_native_splash:create   # then fan the launch screen out
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

Shipped: chat (rich rendering, attachments, voice, streaming and thought
trail, offline cache and send-queue, math and code highlighting), location,
push, pages, tasks, journal, events and device alarms, notes, global search,
files and file opening, several logins, QR sign-in, the folder tree. Open:

- **Three roles**: members and clients sign in, chat with the team
  responder, browse what is shared with them and get pushes (the brain
  contract is mantle `docs/mobile-companion-backend.md`, "Three roles on the
  phone").
- **Events: first-class server status field** (today "done" is the reserved
  `done` tag)
- Drawings and tables in the folder tree (the tree serves them; the phone
  has no viewer for either yet)
- Pins and Most used beside Recent
