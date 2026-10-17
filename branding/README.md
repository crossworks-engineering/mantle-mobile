# Branding

## MantleOS marks (`mantleos-*`) — this app's brand

On 2026-10-17 Jackdaw and Mantle merged into one brand, **MantleOS** (always
written so: capital M, capital OS). The phone app is just "MantleOS"; the web
and desktop client is "MantleOS Desktop".

These files are copies. The source of truth is
[`brand/` in the mantle repo](https://github.com/crossworks-engineering/mantle/tree/main/brand)
(`mantle-sun-icon.svg`, `mantle-logo-os.svg`, `mantle-logo-os-sun-icon.svg`).
All three are true vectors with the text converted to curves, so they render
the same anywhere, no font needed. If a mark changes, it changes there first
and gets copied here.

| file | what it is | use it for |
|---|---|---|
| `mantleos-icon.svg` / `mantleos-icon-2048.png` | The sun badge: a deep rust ring (`#5C1E02`) round a rust sun over amber, orange and rust bands. Fully **opaque** inside the circle, transparent outside, cut tight (no margin). | App icons, and anywhere small or square |
| `mantleos-logo.svg` / `mantleos-logo-2048w.png` | The wordmark: rust script "mantle" plus a rust rounded tag with a cream "OS". 1829×441 (≈4.15:1), cut tight. | Anywhere with horizontal room |
| `mantleos-stacked.svg` | Badge above wordmark in one square. | Rare big square placements only — never at small sizes. Nothing here uses it. |

The wordmark is **one artwork for light and dark grounds** — there is no
light/dark pair. The PNGs are what the generators read; the SVGs are the
masters. To render another size from an SVG, any SVG renderer (resvg,
`rsvg-convert`) will do.

### Brand colours

| swatch | hex |
|---|---|
| Cream | `#FDE7BC` |
| Brown | `#2D1500` |
| Amber | `#EB9F13` |
| Orange | `#E46E08` |
| Rust | `#C83C04` |

The in-app themes come from mantle via `tool/sync_themes.sh`; never edit
`lib/theme/mantle_themes.g.dart` by hand. (The default theme's id and label
are still `jackdaw` / "Jackdaw" there — that is mantle's to rename.)

### ⚠️ Keep the badge off brown

The badge's outer ring is a deep rust that all but disappears on the brand
brown, leaving a half-sun with no edge. Every place this app composes it puts
it on **cream**: the app icon ground, the Android adaptive background, and the
cream icon disc on the Android 12+ launch screen (which also shows in dark
mode, where the launch background is brown).

## Generated app icon and splash

Neither is committed by hand — both are generated, and **regenerating is a
deliberate step**: it changes the installed app icon and needs a rebuild.

```
fvm dart run tool/generate_app_icon.dart   # badge → assets/icon/app_icon*.png + splash_android12.png
fvm dart run flutter_launcher_icons        # fan out to iOS + Android

fvm dart run tool/generate_lockups.dart    # wordmark → assets/brand/mantleos_{logo,wordmark}.png
fvm dart run flutter_native_splash:create  # fan the launch screen out to iOS + Android
```

The composed look:

- **App icon** — the badge on cream, 86% of the canvas for iOS (clear of the
  squircle mask); the Android adaptive foreground is sized to the 66dp safe
  zone over a cream background.
- **Launch screen** — the full-colour wordmark centred on cream in light mode
  and on brown in dark mode. Android 12+ masks its splash icon to a circle, so
  it gets the badge alone (`splash_android12.png`, sized inside that circle) on
  a cream icon disc.

Configuration lives at the bottom of `pubspec.yaml`.

## In-app brand assets (`assets/brand/`)

| asset | used by | why |
|---|---|---|
| `mantleos_logo.png` | `MantleOSLockup` — server setup + sign-in, and the launch screen | Full colour, never tinted. One file serves light and dark. |
| `mantleos_wordmark.png` | `MantleOSWordmark` — the home header | One flat colour with the "OS" knocked out of the tag, so `BlendMode.srcIn` tints it to any theme token and the bar colour shows through the "OS". One file serves all the themes; the full-colour mark would vanish on a rust or red header. |
