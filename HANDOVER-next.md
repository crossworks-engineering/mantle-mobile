# Handover: folders done, three roles next

_Written 2026-10-01 at the end of Phase 1 (the folder tree) of the "folders
and three roles" work. Older handovers are history: `docs/handover.md` (to
2026-06), `docs/handover-audit-worklist.md` (the 2026-09 audit)._

## Start here

1. Run the `mantle-recall` skill (fleet, ssh aliases, how to start a brain
   safely). Then `CLAUDE.md`, `docs/styling-guide.md` and
   `docs/architecture.md`; its sections "Several logins" and "The folder
   tree" are what this work added.
2. `fvm flutter analyze && fvm flutter test`: expect clean and **474**
   passing on `feat/folder-tree` (367 on `feat/home-last-message`). A
   failure before you touch anything is not yours.
3. The plan has three phases. This file says where each stands.

## Where things stand

| What | State |
| --- | --- |
| `feat/folder-tree` | Phase 1. Based on `main` at `a31ac85` (1.12.1+24). Analyze clean, 474 tests, release APK and iOS `--no-codesign` both exit 0. Not pushed. |
| Landed on it first | `feat/multi-login` (three commits, replayed; one conflict in the server setup screen, both sides kept) and `feat/file-open` (two commits; conflicts in the session wipe and the files screen). `feat/pages-list-rollup` was NOT landed: it builds on `parentId` and `childCount`, which the brain no longer sends. |
| `feat/home-last-message` | Three commits on `main` (NOT on folder-tree), asked for by the owner through the audit session so they can ship ahead of the role work: plain-text notification previews with a Swift twin for the iOS extension, the last-message card on Home, and a `Podfile.lock` entry main was missing. Analyze clean, 367 tests, both release builds exit 0, `tool/check_push_text_swift.sh` passes. Not yet seen on a device: its build has the v2 database, so do not install it over a folder-tree build. |
| Phase 1 seen on | iOS simulator (a CLONE named "jdm iPhone 17", so the original keeps its real sign-in) and the owner's Galaxy S20 Ultra (release build, fresh install at the owner's choice, signed in to the test brain only). |
| Phase 1 report | Sent to the session "Recall and folder systems audit" on 2026-10-01 (queued there; it may be held for its user's approval). No GO yet. Screenshots are under `build/shots/` (git-ignored) and were sent to the owner. |
| Phase 2 | Not started. First step: branch `feat/roles` from `feat/folder-tree` and merge `feat/home-last-message` into it (expect a small conflict in `home_screen.dart`). The brain contract is mantle branch `feat/mobile-roles`, `docs/mobile-companion-backend.md`, section "Three roles on the phone" (read it with `git -C ~/Projects/mantle show feat/mobile-roles:docs/mobile-companion-backend.md`). It passed a security review round and is not merged. |
| Phase 3 | Not started. No version bump, no store upload, until the audit session says GO and the owner agrees. |

## Phase 2: what is known, what is asked

Known from the contract: `POST /api/auth/device-login` (admin or member,
answers `role` and `loginId`, 30 days, `POST /api/auth/token/refresh` at
launch and always store the token it answers); a client signs in with
`POST /api/auth/client-code {email, device: true}` then `.../verify` with the
`requestId`; `GET /api/auth/whoami` answers the role, the shell route and the
push base; push routes are the admin's shapes under the role's `pushBase`;
push payloads for a member or client carry `kind` (`chat`, `review`,
`comment`), `itemId` and a `/portal/...` deep link (the router and the
deep-link allowlist know none of those yet); unread is
`GET {role}/chat/unread` and `POST {role}/chat/read`; chat is push plus
refetch, no stream; a member token reaches only member routes.

Answered by the brain session on 2026-10-01 (brain head then `882de3a4`,
verify green, not merged, waiting for the audit GO):

- **Older brains.** `POST /api/auth/device-login` answers 404 `{error: "not
  found"}` on a brain before this release, and so does `whoami`. 404 means
  old brain: fall back to the frozen `mobile-login` (admins only). A wrong
  password on a new brain is 401 `{error: "Invalid email or password."}`.
- **What `mobile-login` says to the other roles** (the app shows "Could not
  reach Mantle" for these today, `lib/data/auth/auth_api.dart`): member 403
  `{error: "Member logins use the web app. Sign in from a browser instead.",
  reason: "member-login"}`; client 403 `{error: "This login cannot use this
  app.", reason: "client-login"}`. Show the brain's `error` as it is.
- **Admins move to `device-login`** on a brain that has it (role, loginId,
  30 days, refresh). An old 1-year `mobile-login` token still works with
  `whoami` (role admin) and with refresh.
- **QR pairing** stays admin only, payload version 1. Its answer is
  `{token, expiresIn, expiresAt, deviceId, email}`, with no role: call
  `whoami` after a claim.
- **Refresh, changed in the last review round.** A lost refresh answer: retry
  with the OLD token and the same new token comes back, with no time limit,
  until the new one is first used. A rotated token presented after its
  successor was used ends every session of the login. So store the newest
  token and use only it; keep the token on any refresh failure that is not
  401 (a 403 or a network error is not a sign-out).
- **Push.** `mobile-logout` removes only the push devices this token
  enrolled. The collapse key of a member or client push is opaque: read
  `kind` and `itemId` from the sealed payload.
- **The demo brain cannot serve members or clients as it is.** Its edge
  refuses every write with 403 before the brain: `device-login`, refresh,
  the client code routes, push enrol, both chat POSTs and the read cursor.
  Only `mobile-login` and `mobile-logout` pass (the edge answers them with a
  static owner token). GETs work with a valid bearer; there are no pushes.
  The brain session advises against a "no-mail sign-in" flag in the brain
  and proposes that the demo edge answer `device-login` and the client code
  routes statically with pre-minted tokens (a client token lasts at most 30
  days, so it must be re-minted monthly). That is demo-branch work and the
  owner's call. If App Review must see working chat, it needs a writable
  review brain. THIS IS THE OPEN RISK FOR THE STORE REVIEW OF THE MEMBER AND
  CLIENT ROLES.
- **Timing.** No dates promised: audit GO, a rebase, then the owner merges,
  releases and rolls. "Two weeks is possible if GO comes this week."

The member and client route shapes are in `docs/phase2-brain-routes.md`
(read from the brain's code). Its headline: those roles get pages as
ProseMirror documents and cannot export markdown, so the Library needs either
a brain route or a renderer on the phone. Ask the brain session first.

The session table needs a `role` (Drift v4), set from the sign-in answer and
re-read from `whoami`; navigation and the home screen follow it, and a
member or client build path must never construct an admin screen.

## The showcase (about two weeks from 2026-10-01)

- Admins: realistic. Folders, several logins, the home card and plain-text
  notifications are built; they need the audit's GO, a version bump and one
  review cycle.
- Members and clients: possible but tight. It needs the brain branch merged
  and rolled to the brains that will be shown, roughly a week of app work
  (sign-in for three roles, role-driven home, member and client chat with an
  offline queue, the read-only library, items, push with the new deep links)
  and a pass on real phones for push. It should be submitted about five days
  before the date to survive one rejection. The reviewer's client login is
  the open risk.

## The test rig left running (tear down when done)

- A throwaway brain from mantle `feat/mobile-roles` at `1701a87a`: systemd
  user unit `jdm-web` and container `jdm_pg` on the workstation, worktree
  `.claude/worktrees/jdm` there (ref `jdm-live`), data under `/tmp/jdm-*`.
  The Mac reaches it on port 3947 through an `ssh -f -N -L` tunnel; the
  phone through `adb reverse tcp:3947 tcp:3947` (the address in the app is
  the loopback one). Web process only: no workers, so no summaries and no
  chat replies. It is seeded with folders for pages, notes and files; the
  fixtures in `test/fixtures/tree/` came from it.
- The owner login's generated test credentials are in a `creds.env` in the
  scratchpad of the session that built it (under `/private/tmp/claude-501/`),
  which may not survive. If it is gone, tear the brain down and build a new
  one from the recipe.
- Teardown: stop the unit, `docker rm -f -v jdm_pg`, remove the worktree and
  the `jdm-live` branch, `rm -rf /tmp/jdm-*` on the workstation; kill the
  tunnel and `xcrun simctl delete "jdm iPhone 17"` on the Mac.
- An AOSP emulator image (`system-images/android-35/default`) was downloaded
  before the owner said to use the phone instead. No AVD was made.

## What Phase 1 decided, and why

- **One browser for three screens** (`lib/features/tree/`). Drilling is state
  inside the screen, not a route per folder, so the trail can jump to any
  level. `?folder=<id>` opens it on a folder (the Folder index uses that).
- **Folders are read, not managed.** The phone does not create, rename, move
  or share folders. It files into them: a note is a create followed by the
  tree's move (the notes route takes no folder), an upload names the
  folder's path.
- **A shared folder asks first.** The brain answers 409 `visibility` and
  writes nothing; the app says who will read the item and repeats with
  `confirm` on a yes. A note the person declines to share stays at the top
  level and the screen says so.
- **The older-brain fallback is per kind and remembered**: a 404 on a kind's
  root marks it until the brain or the login changes, or the app returns to
  the front more than ten minutes later. The pages fallback is
  a flat list, not the old `parentId` hierarchy.
- **Tree reads do not auto-retry.** Riverpod 3 retries a failed provider
  with backoff; the tree's refusals are answers, so `noTreeRetry` turns it
  off there. Without it a 404 kept the screen on "Loading" for a minute.

## Traps this phase met

- **A provider that returns a helper holding `Ref`** breaks when the
  provider is auto-disposed mid-await (`ref.read(x).doSomethingAsync()` from
  a widget: nothing keeps `x` alive). `NoteFiling` and `FileFiling` hold the
  API clients instead. A widget test caught it; a unit test did not.
- **A provider may not change another provider while it is being built**,
  even from a `catch`. `TreeFolderController` marks the older-brain kind in
  a microtask.
- **A cursor page of the tree carries no folders.** Keep the first page's.
- **A horizontal `ListView` is lazy in widget tests** (the test font is
  wide), so a pill or a crumb past the edge is simply not built.
- The simulator named in the audit handover is signed in to a real brain.
  This phase cloned it (`xcrun simctl clone`) and tested on the clone, so
  the original keeps its sign-in. The multi-login migration kept the
  clone's sign-in: Drift v2 to v3 on a real install is proven.

## Testing against a brain

Reads only on the dev brain. For writes, and for member and client logins,
use a throwaway brain on the workstation: the recipe is in the mantle
memory notes "throwaway-brain-ui-test-recipe" and "Workstation live-test
recipe" (a fresh worktree and pg, the server under `systemd-run --user`, an
`ssh -L` tunnel, a first-run sign-up for the owner, never a minted
session). The fixtures under `test/fixtures/tree/` were taken from one.

## Verify quickly

```bash
fvm flutter analyze && fvm flutter test
git log --oneline main..feat/folder-tree
```
