# Mantle Companion — Handover

_Last updated: 2026-06-13._

A checkpoint for picking the work back up. For the system map read
[architecture.md](architecture.md); for UI rules read
[styling-guide.md](styling-guide.md). This doc covers **both platforms** — the
Flutter app (this repo) and the Mantle backend additions it depends on
(`~/Projects/mantle`).

## What this is

A cross-platform (iOS + Android) Flutter companion for the self-hosted **Mantle**
assistant. Connects to a user's own Mantle server over an authenticated REST API
(per-device bearer token). Open source, MIT.

## State at this checkpoint

**Working & verified in the app** (`fvm flutter analyze` clean, **48 tests pass**):

- **Auth** — server setup → bearer login → session gate (go_router redirect).
- **Dashboard landing** (`/`) — `mantle` header, 3 action tiles (Chat / Pending /
  Settings), stat cards (Spend 7d, Pending, Brain nodes, Vectors) + a Server card
  (CPU/RAM/Disk meters + service dots).
- **Two-tier chat** — inbox (`/chat`) listing agents (avatar · name · preview ·
  time · unread badge) → per-agent thread (`/chat/:slug`) with markdown rendering,
  scroll-up paging (30/page), optimistic send, read-on-open.
- **Markdown** — GFM + Mantle's custom blocks (`:::callouts`, `:::aside`,
  `:::columns`, `==highlight==`, `[text]{color}`); images/math still TODO.
- **Avatars** — boring-avatars SVG from Mantle, initials fallback.
- **Settings** (`/settings`) — theme select + sign out.

**Verified live on local dev (2026-06-13)** — the **Mantle backend** additions.
Migration 0090 applied; all four route groups smoke-tested with a mobile bearer
(dashboard summary, conversations, read cursor, avatar all 200; owner-gate 307s
without a token). `apps/web` typecheck is now clean. The avatar route needed two
fixes during that pass — see the backend section.

## Mantle backend additions (in `~/Projects/mantle`, uncommitted there too)

All owner-gated (`requireOwner()`), so they work with a mobile bearer token. See
`~/Projects/mantle/docs/mobile-companion-backend.md` for detail.

| Area | Files | Notes |
|---|---|---|
| Bearer auth | `apps/web/lib/auth.ts`, `middleware.ts`, `schema/mobile-tokens.ts`, migration `0089` | Per-device token; verified E2E earlier. |
| Dashboard | `app/api/dashboard/summary/route.ts` | Aggregates existing `lib/dashboard.ts`/`metrics.ts`. |
| Conversations | `app/api/assistant/conversations/route.ts`, `lib/assistant-inbox.ts` | Per-agent last message + unread. |
| Read state | `app/api/assistant/read/route.ts`, `schema/assistant-read-cursors.ts`, migration `0090` | `assistant_read_cursors(owner, agent, last_read_at)`. |
| Avatars | `app/api/agents/[id]/avatar/route.ts`, `lib/avatar-svg.ts` | Pure-string port of boring-avatars (no React — `react-dom/server` can't render its `useId()` in a route). Under the existing `[id]` segment, resolves uuid-or-slug. Parity pinned by `lib/avatar-svg.test.ts`. |

**To run the backend:** in `~/Projects/mantle`: `pnpm db:migrate` (applies 0089 +
0090), then the `next dev` server hot-loads the new routes.

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

1. ~~Verify the Mantle backend live~~ — **done 2026-06-13** (Mantle commit
   `0f8afaf`): 0090 applied, all four routes smoke-tested 200, avatar endpoint
   fixed (segment conflict + `react-dom/server`/`useId` crash → pure SVG port).
2. **"Incorrect in Mantle" stat** — Jason flagged a dashboard value as computed
   wrong server-side but hasn't said which. Get the specific value, then fix the
   `lib/dashboard.ts`/`metrics.ts` query.
3. **Pending screen** is a placeholder — build the real approvals list +
   approve/reject (`GET /api/pending`, `PATCH /api/pending/{id}`).
4. **Settings** — account/profile management (only theme + sign out exist).
5. Roadmap (not started): Drift message **cache + offline send-queue**, realtime
   updates (`GET /api/realtime` SSE), **message-attached location** (geolocator,
   When-In-Use), **push notifications** (FCM/APNs — needs new Mantle infra),
   markdown **images + math** (Phases 3–4), in-app routing for internal links.

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
- Generated `*.g.dart` are committed.
- Local Mantle password was shared for testing only — never store it; rotate.
