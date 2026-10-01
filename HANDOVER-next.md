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
   passing. A failure before you touch anything is not yours.
3. The plan has three phases. This file says where each stands.

## Where things stand

| What | State |
| --- | --- |
| Branch | `feat/folder-tree`, based on `main` at `a31ac85` (1.12.1+24). Not pushed. Nothing is tagged or uploaded. |
| Landed on it first | `feat/multi-login` (three commits, replayed; one conflict in the server setup screen, both sides kept) and `feat/file-open` (two commits; conflicts in the session wipe and the files screen). `feat/pages-list-rollup` was NOT landed: it builds on `parentId` and `childCount`, which the brain no longer sends. |
| Phase 1 | Done: Pages, Notes and Files on the folder tree, the Folder index block, capture and upload into the open folder, the older-brain fallback. |
| Phase 2 | Not started. The brain contract is on mantle branch `feat/mobile-roles`, `docs/mobile-companion-backend.md`, section "Three roles on the phone". It is in security review and not merged; ask the brain session before relying on a route. |
| Phase 3 | Not started. No version bump, no store upload, until the audit session says GO and the owner agrees. |

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
  root marks it until the brain or the login changes. The pages fallback is
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
