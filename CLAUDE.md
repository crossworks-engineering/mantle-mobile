# MantleOS (mobile) — repo guide

The app was called **Jackdaw** until 2026-10-17; the brand is now **MantleOS**
(written exactly so). Identifiers keep the old name on purpose: the repo, the
Dart package `jackdaw`, bundle/application IDs `crossworks.engineering.jackdaw`,
the keychain group, `jackdaw.sqlite`, the `jackdaw` theme ids.

Cross-platform Flutter companion app for the self-hosted **Mantle** assistant
(chat, notifications, message-attached location).

**Before UI work, read [`docs/styling-guide.md`](docs/styling-guide.md). For the
system map, read [`docs/architecture.md`](docs/architecture.md).**

## Non-negotiables

- **fvm** — always `fvm flutter …` / `fvm dart …` (version pinned in `.fvmrc`).
  Never bare `flutter`.
- **No Material** — build on `shadcn_ui`. The only Material import allowed is
  `show ThemeMode`.
- **Theme tokens only** — colors/text from `ShadTheme.of(context)`; never
  hardcode a color, size, or `TextStyle`. Keeps light/dark working. (Full rules:
  styling guide.)
- **State = Riverpod 3 code-gen** (`@riverpod`). After changing a provider,
  model, or Drift schema: `fvm dart run build_runner build`. Generated
  `*.g.dart` are committed.
- **Layering** UI → controller → repository → data source, every boundary a
  Riverpod provider. Mirror it in tests: `ProviderContainer` overrides +
  in-memory Drift (`AppDatabase.forTesting`) + `mocktail`.
- **Secrets** (bearer token) → `flutter_secure_storage` only. Config (server
  URL, theme) → Drift `app_settings`.
- **Before commit**: `fvm flutter analyze` (must be clean) + `fvm flutter test`.
  Commit on `main` with NO agent co-author trailer (this repo is public and the commits are the owner's work); **don't push unless asked**.

## Gotchas

- Riverpod 3: `AsyncValue.value` (nullable) — `valueOrNull` was removed.
- `custom_lint` / `riverpod_lint` are **removed** (analyzer-version conflict with
  drift 2.34). `freezed` is on a prerelease; not yet used (chat model is
  hand-written).
- **Mantle auth contract**: send `Authorization: Bearer <token>`; treat **401 OR
  3xx→/login** as "session invalid". See architecture doc.

## Test against local Mantle

In `~/Projects/mantle`: `colima start && pnpm infra:up && pnpm db:migrate`; the
web dev server is `http://localhost:3000`. The iOS simulator reaches it directly
(Info.plist `NSAllowsLocalNetworking`, dev only).
