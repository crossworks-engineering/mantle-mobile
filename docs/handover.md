# Mantle Companion — Handover

_Last updated: 2026-06-14._

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

> **Latest session (2026-06-14).** **Mantle Push M1 — the relay MVP — built and
> verified.** New repo `~/Projects/mantle-push` (Node + TS + Hono, its own
> Postgres): TOFU `/instances`, ticket-gated `/enroll`, instance-token `/notify`,
> `/refresh`, `DELETE /device`, `/instance`; APNs (HTTP/2 + ES256 `.p8`) + FCM v1
> providers, plus a credential-less **mock** provider; per-instance rate limits.
> The whole spine passes a **14-check end-to-end CLI smoke test** on the mock
> provider (register → enroll → notify → list → rotate → unpair, every security
> boundary asserted). Caddy site block for `push.crossworks.network` wired into
> the Mantle Caddyfile (inert until the container is up). **Not deployed** (gated).
> `mantle-push` is uncommitted pending Jason's go-ahead.
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
   - **M2 — Mantle side** (next): in `~/Projects/mantle`, add `push_instance` +
     `push_subscriptions` schema, the `POST /api/push/connect` (lazy instance-token
     gen + ticket mint), `/api/push/subscriptions`, `/api/push/reset` routes, and
     the **send-worker off the existing `conversation_changed` signal** (migration
     0091) that seals a teaser to each device pubkey and calls the relay's
     `/notify`. The ticket/token wire format to mirror is in
     `mantle-push/src/lib/ticket.ts` + `tokens.ts`.
   - **M3 iOS** (keypair + Keychain group + NSE decrypt + one-tap Connect),
     **M4 Android** (FCM data handler), **M5** Settings/quiet-hours, **M6**
     UnifiedPush. Push is the only path for *backgrounded* proactive messages
     (SSE pauses when backgrounded).
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
