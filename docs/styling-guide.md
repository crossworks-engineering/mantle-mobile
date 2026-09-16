# Jackdaw (mobile) — Styling Guide

The rulebook for UI. **Read this before building or tweaking any screen**, so the
whole app stays visually consistent. When in doubt, match the existing screens
(`server_setup_screen`, `login_screen`, `chat_screen`, `home_screen`).

## Non-negotiables (TL;DR)

1. **No Material.** Build on `shadcn_ui` (`ShadApp`, `ShadButton`, `ShadInput`,
   `ShadCard`) + raw `flutter/widgets`. The only allowed Material import is
   `import 'package:flutter/material.dart' show ThemeMode;`.
2. **Theme tokens only.** Colors come from `ShadTheme.of(context).colorScheme.*`,
   text from `.textTheme.*`. **Never hardcode a `Color`, font size, or
   `TextStyle`.** This is what keeps light/dark working.
3. **Standard screen scaffold** (below) for every screen — no `Scaffold`/`AppBar`.
4. **Pair every fill with its own foreground** (`primary`+`primaryForeground`,
   `muted`+`mutedForeground`, …). Never mix pairs.
5. Both **light and dark** must look right. Tokens make this automatic — verify
   with the Theme toggle.

## Theme

The default palette is **Jackdaw**, hand-written in
[`lib/theme/jackdaw_theme.dart`](../lib/theme/jackdaw_theme.dart) from the app's
own mark: brand brown `#2D1500` and cream `#FDE7BC`, radius 8. `primary` is the
brown and `primaryForeground` the cream, so the header bar reproduces the app
icon; dark mode inverts the pair. The chart ramp is the badge's sunset stripes.

It sits OUTSIDE the generated registry on purpose —
`tool/generate_themes.dart` rewrites `mantle_themes.g.dart` wholesale, so a
theme added there would vanish on the next run.
[`mantle_theme.dart`](../lib/theme/mantle_theme.dart) prepends it to
`kMantleThemes` and names it as `defaultId`. The other 42 themes are still
ported from Mantle web's `globals.css` and remain selectable. Don't hardcode
colours — read tokens from `ShadTheme.of(context)`.

Theme mode follows the system by default; the in-app **Theme** button cycles
system → light → dark and **persists** (`ThemeModeController` → Drift).

## Color tokens — `ShadTheme.of(context).colorScheme`

| Token (+ its `…Foreground`) | Use for |
|---|---|
| `background` / `foreground` | screen background + default text |
| `card` / `cardForeground` | raised surfaces (`ShadCard`) |
| `primary` / `primaryForeground` | primary action, **user** chat bubble |
| `secondary` / `secondaryForeground` | secondary fills |
| `muted` / `mutedForeground` | subdued surfaces (assistant bubble) + secondary text |
| `accent` / `accentForeground` | subtle highlights |
| `destructive` / `destructiveForeground` | errors, destructive actions |
| `border`, `input`, `ring` | outlines, input borders, focus rings |

Rule: a fill and its text must come from the **same pair** — no
`bg primary, text foreground`.

## Typography — `ShadTheme.of(context).textTheme`

| Style | Use for |
|---|---|
| `h1` / `h2` | screen titles (auth screens use `h2`) |
| `h3` | app / top-level header (Home) |
| `h4` | card titles, sub-headers (Chat header) |
| `p` | body text (chat bubbles) |
| `muted` | secondary / explanatory text |
| `small` | captions, footnotes, **inline errors** (with `destructive` color) |
| `lead` / `large` | larger emphasis when needed |

Pick the nearest scale entry; never hardcode `fontSize`. Override **only color**
via `.copyWith(color: …)`.

**The whole scale is shadcn +1pt** (set in `mantle_theme.dart`): `small`/`muted`
**15**, body `p` **17**, `large` 19, `lead`/`h4` 21, `h3` 25, … `h1Large` 49. So
**15 is the app's minimum** font size and there's a clear step from the smallest
text to body. Nothing should render smaller than `small`/`muted` — if text looks
too small you're hardcoding a size; use a scale entry instead.

## Standard screen scaffold

Every screen is:

```dart
Container(
  color: theme.colorScheme.background,
  child: SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: /* Column(...) */,
    ),
  ),
)
```

No `Scaffold` / `AppBar`. The scaffold above is for **plain content/form**
screens (they own the full `SafeArea`). A screen **with a header** instead leads
with the primary header bar (see [Headers](#headers)), which owns the top inset —
in that case don't wrap the whole screen in a `SafeArea`. For screens with a
bottom input, pad the bottom by `MediaQuery.viewInsetsOf(context).bottom` (or the
view-padding bottom when the keyboard is closed) so the composer rides above the
keyboard / home indicator (see `chat_screen.dart`).

## Form / centered screens (setup, login)

- `Center` → `SingleChildScrollView` → `ConstrainedBox(maxWidth: 420)`.
- Order: title (`h2`) → `muted` subtitle → 24 gap → inputs (12 between) →
  error (`small` + `destructive`) → 20 gap → **full-width** primary button.
- Full-width button: `SizedBox(width: double.infinity, child: ShadButton(...))`.
- While submitting: disable inputs + button, swap the label to "…ing"
  (e.g. "Signing in…"). **No spinner.**

## Spacing

Use a 4-based scale via `const SizedBox(height: N)` / `EdgeInsets`:
**4, 8, 12, 16, 20, 24**. Screen padding `24`. Between stacked fields `12`.
Section gaps `16`–`24`.

## Buttons — `ShadButton` variants

| Variant | Use |
|---|---|
| `ShadButton` | the **one** primary action of a view |
| `ShadButton.outline` | secondary action |
| `ShadButton.ghost` | header / toolbar actions (Theme, Sign out, Back) |
| `ShadButton.link` | tertiary / inline ("Change server") |
| `ShadButton.destructive` | destructive confirm |

Labels are verb-first, sentence case ("Sign in", "Open chat", "Connect").
Disable with `onPressed: null`.

**Height rule:** a button sitting **beside an input** (same `Row`) must be the
**same height as that input**. Wrap the row in `IntrinsicHeight` and set
`crossAxisAlignment: CrossAxisAlignment.stretch` so the button tracks the input's
height (see the chat composer in `chat_screen.dart`). Don't hand-tune a fixed
`height:` to fake the match.

## Inputs — `ShadInput`

- `placeholder` is a **Widget** (`Text`). Set `keyboardType`, `obscureText` for
  passwords, `autocorrect: false` for credentials/URLs.
- Multiline (chat composer): `minLines` / `maxLines` + `textInputAction`.
- Error display: a `Text` below the field — `theme.textTheme.small` +
  `colorScheme.destructive`. **No** inline banners or dialogs for field errors.

## Cards — `ShadCard`

`title:` (`Text` `h4`) + `description:` (`Text`) + optional `child:`
(wrap actions in `Padding(top: 16)`).

### Flat accent list cards (the conversations inbox)

For a tappable list of rows that should read as distinct cards (e.g. the agents
inbox), use a **flat `accent` card**: `Container(color: scheme.accent,
borderRadius: 16)`, generous padding, a small outer margin so cards separate
(`Padding(fromLTRB(12, 4, 12, 4))` over a `ListView` with vertical padding).
No shadow, no border — flat fill + rounded corners.

**The pairing rule is load-bearing here.** A coloured fill only guarantees
contrast with its **own** `…Foreground`, so on an `accent` card *every* piece of
text comes from `accentForeground`, tinting secondary text with opacity
(`accentForeground.withValues(alpha: 0.6)`) — **never** `mutedForeground` or
`foreground`, whose contrast against `accent` isn't guaranteed. A badge or chip
that needs to pop carries its own pair instead (the unread count is
`primary` + `primaryForeground`). This is the Flutter mirror of Mantle web's
rule "`bg-accent` is fine only where text is `accent-foreground`" — see the
[surface-fill table](#which-fill-where) below.

### Which fill where

A fill and its text must come from the **same pair** (see [Color tokens](#color-tokens--shadthemeofcontextcolorscheme)). What each surface is *for*:

| Fill | Foreground | Use it for |
|---|---|---|
| `background` | `foreground` | the screen itself |
| `card` | `cardForeground` | neutral raised panels (`ShadCard`) |
| `accent` | `accentForeground` | a **soft highlighted surface** — list cards, selected/emphasised rows |
| `secondary` | `secondaryForeground` | a quieter filled chip/segment |
| `muted` | `mutedForeground` | the most subdued surface (assistant bubble) + secondary text on `background` |
| `primary` | `primaryForeground` | the one brand/action accent — header bar, user bubble, badges, primary button. Don't tile large areas with it (it's saturated). |
| `destructive` | `destructiveForeground` | errors / destructive actions only |

Rule of thumb: **`accent` is the "card accent" you reach for; `primary` is the
single pop on top of it; `muted`/`secondary` are the quiet ones.** Never tint a
surface with one token and text it with another's foreground.

## Shared conventions (one of each)

Four things every screen used to do its own way. Each now has one home; use
it, don't re-derive it.

- **Header title.** `MantleHeaderTitle(text, wordmark: false)` for a
  sub-screen, which draws with `headerTitleStyle(theme)` (`h4` in
  `primaryForeground`). The chat header's agent name uses the same style.
  The script face is the Jackdaw wordmark only; never set it on other text.
- **Dates.** `lib/core/format/dates.dart`: `formatWhen` for a past instant
  (`5m`, `3h`, `2d`, `18 Sep`), `formatDay` for a calendar day (`Today`,
  `Tomorrow`, `Fri 18 Sep`), `formatDue` for a deadline (`In 3 days`,
  `3 days overdue`). No screen formats a date by hand.
- **Destructive confirm.** `confirmDestructive(context, title:, description:,
  action:)` in `lib/widgets/confirm_dialog.dart` — a `ShadDialog.alert` with
  Cancel and a red verb. Every delete, reject, reset and sign-out goes through
  it. Never a one-tap ghost row in a sheet.
- **Adding things.** A capture screen (Notes, Tasks, Journal) puts a quick-add
  row directly under the header: `ShadInput` + a `ShadButton` with the plus
  icon. A screen whose new item is a form (Events) puts a plus in the header
  that opens a sheet. Nothing captures from the bottom of the screen except
  the chat composer.

## Chat bubbles

- **User** (inbound): align right, `bg primary`, `text primaryForeground`.
- **Assistant** (outbound): align left, `bg muted`, `text foreground`.
- `maxWidth` 78% of screen, radius 16, padding H14 / V10.
- `sending` → 0.6 opacity; `failed` → "Failed to send" (`small` + `destructive`)
  below the bubble.
- **Assistant** replies are **markdown**, rendered by `MantleMarkdown`
  (`features/chat/markdown/`) — never a raw `Text`. Its `MarkdownStyleSheet` is
  built from theme tokens, so the same "tokens only" rule applies: if you need a
  new markdown style, derive it from `ShadTheme`, don't hardcode. User messages
  stay plain `Text` (they type plain text).

## Loading / error / empty states

- **Loading**: centered `Text('Loading…', style: textTheme.muted)` — no Material
  spinner.
- **Error**: centered `muted` message + `ShadButton.outline('Retry')`.
- **Empty**: centered `muted` hint (e.g. "No messages yet. Say hello 👋").

## Headers

Every screen with a header uses **one** pattern: a **flat primary-filled bar**
that runs edge-to-edge under the status bar, with identity on the left and
actions on the right. This is the app's header — don't invent per-screen
variations. **Use the shared
[`MantleHeader`](../lib/widgets/mantle_header.dart) widget** (`leading` +
`trailing`); only its contents change per screen. `MantleHeaderTitle` renders a
wordmark title for screens without an interactive identity (e.g. the home
landing's `mantle` title). Reference uses: `home_screen.dart` (title + theme
toggle) and `_ChatHeader` in `chat_screen.dart` (agent identity + back).

**Fill & foreground.** Background is `colorScheme.primary`; *everything* on the
bar (text, icons, chevrons) uses `primaryForeground`. Secondary marks (e.g. the
picker chevron) may drop to `primaryForeground.withValues(alpha: 0.85)`. Never
mix in another foreground token.

**Structure & placement.** The bar owns the top safe-area inset, so the fill
reaches the screen's top edge:

```dart
// Screen = Container(background) → Column[ header, Expanded(body), composer? ]
Container(
  color: scheme.primary,
  child: SafeArea(
    bottom: false,
    child: SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 4, 0),
        child: Row(/* identity … back */),
      ),
    ),
  ),
)
```

- The header is the **first** child of the screen's `Column`. The body below it
  is wrapped in `SafeArea(top: false, bottom: false)`; the screen `Container`
  uses `background`. (So the header is the *only* thing that owns the top inset —
  don't wrap the whole screen in a `SafeArea`.)
- Content height is **52**; horizontal padding `14` leading / `4` trailing (the
  trailing ghost button supplies its own padding).

**Layout — identity left, back right.**

- **Leading: identity.** A round accent avatar + a name. When the identity is
  interactive (e.g. switches agent), it's a single tap target ending in a
  `LucideIcons.chevronDown`, and opens a bottom sheet (`showShadSheet`). Wrap the
  name in `Flexible` + `TextOverflow.ellipsis` so long names truncate.
- **Trailing: back.** `ShadButton.ghost` with `LucideIcons.arrowLeft` (size 20,
  `primaryForeground`) → `context.pop()`, on the **right**.

**Wordmark font.** Identity/brand text (the agent or app name) is set in
`BukhariScript` — Mantle's logo font (`assets/fonts/`, family `BukhariScript`),
at ~24px in `primaryForeground`. Apply via
`TextStyle(fontFamily: 'BukhariScript')`. This font is **only** for header
identity text — never body copy, labels, or buttons. A header with no identity
(plain title screen) may use the wordmark for the title; back still sits right.

## Navigation

`go_router`; each screen is a route in
[`lib/routing/app_router.dart`](../lib/routing/app_router.dart). A back affordance
is a `ShadButton.ghost` with `LucideIcons.arrowLeft` → `context.pop()` (right side
on filled headers; left otherwise).

## Checklist for a new screen

1. Standard scaffold (`background` + `SafeArea`).
2. Tokens only — no hardcoded colors / sizes / text styles.
3. Typography from `textTheme`.
4. Buttons / inputs / cards from shadcn.
5. Handle loading / error / empty.
6. Looks right in **light and dark** (toggle to check).
7. Register the route in `app_router.dart`.
