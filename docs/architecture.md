# Mantle Companion — Architecture

A handover-oriented map of the app: what it is, how it's structured, and how it
talks to Mantle. Pair this with [styling-guide.md](styling-guide.md) for UI rules.

## What this is

A cross-platform (iOS + Android) Flutter app — a mobile companion for the
**self-hosted Mantle** personal assistant. It connects to a user's own Mantle
server over an authenticated REST API.

Scope, in order of build:

1. **Chat** with the assistant (done)
2. **Message-attached location** — coordinates stapled to a message, read
   on-demand at send time (foreground only → "When In Use", never "Always")
3. **Push notifications** from Mantle

The client is intentionally thin; Mantle is smart. The app sends raw input and
renders responses — no reverse-geocoding or POI logic on device.

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
| Tests | flutter_test + **mocktail** + in-memory Drift | ~23 tests |

## Project layout

```
lib/
  core/network/      dio_provider.dart      — Dio + bearer/auth-failure interceptor
  data/
    db/              app_database.dart       — Drift DB (app_settings KV)
                     connection.dart         — native SQLite open
                     database_provider.dart  — appDatabaseProvider
    server/          server_config.dart      — base URL (Drift) + probeMantleServer
    auth/            token_store.dart         — bearer token (secure storage)
                     auth_api.dart            — mobile-login / mobile-logout
                     auth_repository.dart     — login/logout orchestration
    chat/            chat_message.dart        — unified message model
                     chat_api.dart            — turn + messages endpoints
                     chat_repository.dart     — seam (future Drift cache/queue)
    agents/          agent.dart               — agent model (slug/name/accent/hasAvatar)
                     agent_api.dart           — GET /api/agents, agent avatar SVG
    conversations/   conversation_models.dart — inbox row (preview + unread)
                     conversations_api.dart   — GET /api/assistant/conversations, POST /read
    dashboard/       dashboard_models.dart    — summary + health models
                     dashboard_api.dart       — GET /api/dashboard/summary, /api/health
  features/
    auth/            session_controller.dart  — AuthStatus gate
                     server_setup_screen.dart
                     login_screen.dart
    agents/          agent_controller.dart     — agent list (names/avatars)
                     agent_avatar.dart         — SVG avatar w/ initials fallback
    conversations/   conversations_controller.dart, conversations_screen.dart (inbox)
    chat/            chat_controller.dart      — per-agent thread (family by slug)
                     chat_screen.dart          — agent header, marks read on open
    dashboard/       dashboard_controller.dart — summary + best-effort health
    home/            home_screen.dart          — landing dashboard (stats + actions)
    pending/         pending_screen.dart       — approvals (placeholder)
    settings/        theme_mode_controller.dart, settings_repository.dart
                     settings_screen.dart      — theme select + sign out
  widgets/           mantle_header.dart         — shared primary header bar
  routing/           app_router.dart           — go_router + redirect
  theme/             mantle_theme.dart          — Clean Slate tokens (light/dark)
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
  `{inbound, outbound, reply}` (120s timeout; the assistant generates inline).
- `ChatController` — exposes `ChatState { messages, hasMore, loadingMore }`.
  Loads the latest page on build (`chatPageSize` = **30**), **pages older history**
  via `loadMore()` (cursor = oldest loaded `createdAt`; prepends, de-dupes by id;
  `hasMore` = last page was full). The screen's reversed `ListView` fires
  `loadMore()` when scrolled near the older end. **Optimistic send** (user message
  shows as `sending`, then `sent` + reply appended, or `failed`).
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
3. **Images & attachments** — extend `ChatMessage`/`ChatApi` to parse
   `artifacts[]`/`attachments[]`; a Dio-backed `ImageProvider` (carries the
   Bearer header, resolves relative URLs) feeds the markdown `imageBuilder` and
   inline media below the bubble.
4. **Math & syntax highlighting** — `$…$` / `$$…$$` (flutter_math_fork) and
   code-block highlighting.

## Mantle integration contract

- **Base URL**: user-entered, stored locally.
- **Auth**: `Authorization: Bearer <token>` on every call.
- **Endpoints used**: `/api/version` (probe), `/api/auth/mobile-login`,
  `/api/auth/mobile-logout`, `/api/agents` (agent list),
  `/api/assistant/messages`, `/api/assistant/turn`, `/api/dashboard/summary`
  (landing stats — **added to Mantle**), `/api/health` (system vitals),
  `/api/assistant/conversations` (inbox — **added**), `/api/assistant/read`
  (read cursor — **added**), `/api/agents/{slug}/avatar` (avatar SVG — **added**).
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

- **Rich reply rendering** — Phases 1–2 (GFM text + Mantle custom blocks/inline)
  done; Phases 3–4 (images/attachments, math/highlighting) outlined under
  [Chat](#rendering-assistant-replies)
- Drift message **cache + offline send-queue** (the `ChatRepository` seam exists)
- **Message-attached location** (geolocator, When-In-Use)
- **Push notifications** (FCM/APNs — needs new Mantle infra + a device-token
  registration endpoint)
- Persist the selected agent across restarts (picker + switching: done)
