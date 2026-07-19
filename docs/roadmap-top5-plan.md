# Top-5 feature plan — companion v1.7 → v1.11

_Written 2026-07-19. Gap analysis of companion v1.6.0+13 against the Mantle
server API surface (v0.147.0 + `e4601abd`), ranked by mobile value ÷ risk.
Implementation phases below are ordered by dependency, not rank._

## How the top 5 were chosen

The full bearer-reachable server surface was inventoried (see
`mantle/docs/mobile-companion-backend.md` and `apps/web/app/api/**`). Features
the app does NOT yet consume: notes, files/folders, contacts, tables, email
(read), activity, traces, page drafts — plus one capability with **no HTTP
endpoint at all**: the hybrid FTS+vector search engine (`@mantle/search`),
today reachable only through MCP tools (`search_nodes` / `search_chunks`).

Mobile-first weighting: a phone is (a) the *capture* device — friction kills
capture; (b) the *retrieval* device — "find that thing" happens away from the
desk; (c) on flaky networks — reliability is a feature. That yields:

| # | Feature | Why it wins | Backend gap? |
|---|---------|-------------|--------------|
| 1 | **Global brain search** | Retrieval-on-the-go is the defining companion feature; engine already exists server-side | **Yes — new `GET /api/search`** |
| 2 | **Notes (capture + browse)** | The core second-brain capture primitive; full CRUD API exists | No |
| 3 | **Files browser + upload** | Photos/receipts/docs into the brain without a chat turn; full API exists | No |
| 4 | **Offline chat cache + send-queue** | Instant cold-start, offline reads, sends that survive dead spots; `ChatRepository` seam exists | No |
| 5 | **Markdown math + syntax highlighting** | Long-planned rendering Phase 4; felt daily in chat AND pages | No |

Explicitly deferred: **Pages editing** (ProseMirror-doc-shaped draft/commit API
— high risk, poor phone ergonomics; revisit with a markdown-append backend
route), contacts, tables, email (lower mobile value).

## Phase 1 — backend: `GET /api/search` (mantle repo)

The one server adaptation. New `apps/web/app/api/search/route.ts`, mirroring
the MCP tools' logic exactly:

- Owner-gated via `getOwnerOr401` (mobile bearer works automatically).
- Query params (zod): `q` (required), `mode=nodes|chunks` (default `nodes`),
  `type` (node-type enum), `branch` (ltree prefix), `tags` (comma-separated),
  `limit` (1–50, default 20).
- Embed the query via `@mantle/embeddings` `embed(ownerId, q)` in try/catch —
  failed embed degrades to FTS, never errors (same as `search_nodes`).
- `nodes` mode → `searchNodes` → `{results: [{id, type, title, path, tags,
  summary, updatedAt, url, supersededBy?}]}` (summary from `data.summary`,
  `url` via `nodeUrl` for open-on-web).
- `chunks` mode → `searchChunks` → `{results: [{nodeId, nodeTitle?, heading,
  ordinal, text}]}`.
- Vitest route test (mock search/embeddings); `pnpm verify` gates; update
  `docs/mobile-companion-backend.md`; release per repo convention
  (feature branch → changelog + bump → merge, **local only, no push**).

## Phase 2 — app: Notes (v1.7.0)

Mirror the tasks/journal pattern (Api → controller → screen):

- `data/notes/notes_api.dart` + `notes_models.dart` — `GET /api/notes?page&q&tag`
  → `{notes, total, page, pageSize, tags}`; `POST {title, content?, tags?}`;
  `GET/PATCH/DELETE /api/notes/{id}`. Digests stay hidden (server default).
- `features/notes/` — `notes_controller.dart` (list + paging + tag filter),
  `notes_screen.dart` (capture-first: quick-add title field on top, list below,
  tag filter chips), `note_view_screen.dart` (rendered via `MantleMarkdown`,
  edit sheet for title/content/tags, long-press delete).
- Routes `/notes`, `/notes/:id`; home-screen tile. Tests: model parse, controller
  with mocked api (ProviderContainer + mocktail).

## Phase 3 — app: global Search (v1.8.0)

- `data/search/search_api.dart` + models over the new endpoint (`nodes` mode
  first; `chunks` reserved).
- `features/search/search_controller.dart` — debounced (~350 ms, ≥2 chars)
  query + optional type filter; `search_screen.dart` — search field, type
  filter chips (All / Pages / Notes / Files / Tasks / Events / Journal /
  Email / Contacts), result rows (type→Lucide icon, title, summary, relative
  time).
- Tap routing by type: `page`→`/pages/:id` view, `note`→`/notes/:id`,
  `task`→`/tasks`, `event`→`/events`, `journal`→`/journal`, `file`→bytes route
  (image → inline preview screen, else detail sheet); anything else → detail
  sheet with "Open in Mantle" (server URL + `url`) via `url_launcher`.
- Entry points: search icon in the home header + home tile; route `/search`.
- Tests: controller debounce/filter logic, model parsing, api mock.

## Phase 4 — app: Files browser + upload (v1.9.0)

- `data/files/files_api.dart` + models — folders: `GET /api/files/folders?parent=`
  (+ `?tree=1`), `POST` create; files: `GET /api/files/files?parent=`,
  `POST` multipart `{parentPath, file}`, `DELETE`; bytes via existing
  `/api/files/files/{id}?raw=1` provider.
- `features/files/` — folder-drill navigation (breadcrumb), file rows
  (mime→icon, size), image files → inline authed preview, other types →
  detail sheet ("Open in Mantle"). Upload FAB: camera / photo library
  (image_picker) / document (file_picker) → multipart POST → refresh;
  duplicate-name 409 surfaced inline.
- Reuses the attachment pickers' permission strings — no new native perms.
- Tests: models, controller (mock api), upload flow unit test.

## Phase 5 — app: offline chat cache + send-queue (v1.10.0)

The `ChatRepository` seam becomes real:

- Drift `schemaVersion` 1→2: `cached_messages` (agentSlug, id, json, createdAt;
  PK (agentSlug, id)) and `outbox_turns` (id, agentSlug, text, locationJson?,
  createdAt, state `queued|sending`, attempts). Attachment turns are NOT queued
  (fail fast, as today) — bytes lifetimes on disk aren't worth the complexity.
- Read-through: controller renders cache instantly on build, network refresh
  reconciles (server wins; cache pruned to last ~200/agent). Offline cold-start
  shows history + an "offline" banner.
- Write-behind: a send failing on a *connectivity* error (Dio connection/timeout
  errors, not 4xx/5xx) enqueues to outbox; bubbles show `queued`. Flush attempts:
  app foreground resume, thread open, and before any new send (serialized,
  oldest-first, existing idempotency-key per queued turn so replays are safe).
- Tests: repository with in-memory Drift (cache round-trip, prune, outbox
  enqueue/flush/ordering, idempotency-key stability), controller offline path.

## Phase 6 — app: markdown math + syntax highlighting (v1.11.0)

- **Math**: `flutter_math_fork` — inline `$…$` / block `$$…$$` as custom
  `InlineSyntax`/`BlockSyntax` in `mantle_syntax.dart` (delimiter guards so
  currency "$5" never triggers), element builders render TeX; parse errors fall
  back to plain code text.
- **Highlighting**: `re_highlight` (pure-Dart highlight.js port) in the fenced-
  code builder — language from the fence info string, theme mapped from
  `ShadTheme` tokens (both modes), graceful plain-text fallback for unknown
  languages. Applies to chat AND page rendering (same `MantleMarkdown`).
- Tests: syntax-parse units (math delimiters, currency guard, fence language
  extraction), golden-free render smoke.

## Cross-cutting rules

Every phase: `fvm dart run build_runner build` after provider/model changes →
`fvm flutter analyze` clean → `fvm flutter test` green → version bump in
`pubspec.yaml` → commit on `main` (no attribution trailer, no push).
Backend phase: `pnpm verify` + live smoke against the dev stack.
Finish with a full-session audit (diff review + analyze/test + docs update).
