# Handover → next session: mantle-companion + mantle (post top-5 cycle)

_Updated 2026-07-20 on the Mac M4, at the end of the top-5 feature session
(v1.7–v1.11 + audit). Supersedes the post-v1.6 handover text._

## Where everything stands

**mantle-companion** — `main` = **v1.11.1+19**, pushed to origin 2026-07-20
(before the device pass — see open thread 3). This session shipped, each analyze+test
gated and commit-per-phase:

- v1.7.0 **Notes** (quick-add, tag facets, paging, markdown view/edit)
- v1.8.0 **Search** (debounced hybrid search over the NEW `/api/search`,
  type chips, per-type deep links) — **requires Mantle ≥ v0.148.0**
- v1.9.0 **Files** (folder drill, authed image preview, camera/library/
  document upload)
- v1.10.0 **Offline chat** (Drift v2: raw-row read cache pruned to 200/agent
  + idempotency-keyed send-queue, queued bubbles, offline banner)
- v1.11.0 **Math + syntax highlighting** (TeX w/ currency guards; re_highlight
  with a CURATED language set — `languages/all.dart` blows kernel compiles to
  30+ min; colours from theme tokens)
- v1.11.1 **audit fix pass** — an adversarial review found and fixed: send()
  flushing without refetch, queued bubbles sorting mid-thread, no flush
  latch, missing ref.mounted guards in the three new controllers, a search
  debounce stale-response window, `'409'`-in-URL upload misclassification,
  notes page-cursor desync + loadMore snapshot clobber, lost code-block
  padding, and `$$`-prefixed prose swallowing messages.

**Verified**: analyze clean, **144/144 tests**, release builds compile on BOTH
platforms (iOS `build ios --no-codesign` 56s; Android `build apk` 118s —
apk now 77 MB, flutter_math fonts included). **NOT yet device-run** — the
v1.7–v1.11 surfaces need a phone pass (checklist below).

**mantle** — `main` = `142583c4`, **v0.148.1**, tags v0.148.0 + v0.148.1
created — ALL LOCAL, nothing pushed. Contains: `GET /api/search`
(nodes|chunks, owner-gated, embed-with-FTS-fallback) + audit hardening
(pgArrayLiteral tags binding — also fixes the latent `search_nodes` MCP tags
bug — ltree length caps, strict-integer limit, chunks supersededBy parity),
a pre-existing `apps/api` typecheck fix, and the companion-contract doc
section. `pnpm verify` green (2384 tests). The M4's `workstation` remote and
the TitanKing origin both still hold e4601abd — **push + deploy is an open
thread** (the companion Search screen errors against v0.147.0 servers).

**Machines** — unchanged (auto-memory `dev-topology`): stack on the
workstation `.75` (check for a RUNNING one first), ONE frontend dev server on
the M4 `.47`, Android tests on the physical phone, workstation SSH =
`jasons` + ControlMaster only. Worktrees are mandatory for parallel mantle
work (`scripts/new-worktree.sh`); the original clone is the integrator.

## Open threads (in order)

1. **TestFlight upload (v1.6.0+13)** — the signed IPA is still intact at
   `build/ios/ipa/mantle_companion.ipa` (25 MB, built 2026-07-19 22:25).
   Jason drags it into Transporter → export-compliance "standard/exempt" →
   internal tester. OR: skip to v1.11.1 — but device-verify first, then
   `LANG=en_US.UTF-8 fvm flutter build ipa` (~2 min; overwrites the v1.6
   IPA).
2. **Push mantle v0.148.x + deploy to dev** — until the dev brain runs
   ≥ v0.148.0, the companion Search screen has no endpoint. Push main + tags
   to origin (TitanKing) and the workstation remote, then deploy per the
   changelog ("tag-only bump — no migration").
3. **Device-verify v1.7–v1.11 on both platforms** (main is already pushed):
   notes add/edit/tag-filter; search as-you-type + each deep-link type +
   "Open in Mantle"; files drill/upload (camera + document, duplicate-name
   409 message) + image pinch-zoom; offline: airplane-mode → thread shows
   cached history + banner, send queues, reconnect → queued turn delivers
   exactly once IN ORDER and the reply lands; math `$x^2$`/`$$…$$` + a
   ```dart fence in chat and in a page; "costs $5 and $6" stays prose.
4. **Events: first-class status field (mantle)** — unchanged from last
   handover; "done" is still the reserved `done` tag the app depends on
   (`docs/mobile-companion-backend.md` §Companion v1.4–1.6).
5. **Android release keystore** — release APK still debug-key signed.
6. **Built-in Kotlin migration** — lifts the file_picker 8.x pin
   (breadcrumbs in `android/gradle.properties`).
7. **Roadmap remainder** — Pages write surfaces (needs a markdown-append
   backend route first; the draft/commit API is ProseMirror-shaped).

## Known small gaps (deliberate, documented)

- Offline cache serves up to 200 rows regardless of requested limit; the
  chunks search mode is implemented server-side but unconsumed by the app.
- Delete-sheet destructive labels use the tasks-screen's bare
  `TextStyle(color: destructive)` precedent; offline-banner Retry uses the
  failed-bubble's primary-on-secondary precedent.
- A queued turn's text can flash twice for one merge cycle if an SSE refetch
  races `flushOutbox`'s row delete (transient, self-heals).

## Working rules that bit us (don't relearn)

- All prior rules stand: fvm always; no Material; theme tokens only;
  build_runner after provider changes; analyze + test before commit; NO
  Claude attribution trailer; don't push unless asked.
- **markdown package**: an InlineSyntax must NEVER return false from
  `onMatch` after its regex matched — match-without-consume = synchronous
  infinite loop = flutter_tester pinned at 100% CPU, immune to test
  timeouts. Emit the text and return true.
- **re_highlight**: never import `languages/all.dart` (~190 grammars) —
  kernel compile of the test bundle goes 30+ min. Import grammars singly.
- Harness gotchas (M4): background Bash + `| tail` buffers output until
  process exit — stream to a file instead when watching; `zsh`'s `=word`
  expansion eats `===LABEL===` echo separators; foreground `sleep` is
  blocked — use Monitor/until-loops.

## Verify quickly (any fresh session)

```bash
cd ~/Projects/mantle-companion && fvm flutter analyze && fvm flutter test
git log --oneline -3   # 74c8617 docs / 5346c65 fix(audit) / 70bd366 math
cd ~/Projects/mantle && git log --oneline -2  # 142583c4 v0.148.1 merge
pnpm verify            # 2384 tests
```
