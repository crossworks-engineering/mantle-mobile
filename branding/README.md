# Branding

## Jackdaw marks (`jackdaw-*`) — this app's brand

The app's own marks, as of the 2026-08-21 rename. These are copies — the source
of truth is [`brand/redesign/` in the jackdaw repo](https://github.com/crossworks-engineering/jackdaw/tree/main/brand/redesign).
If the mark changes, it changes there first and gets copied here.

`dark` / `light` name the **background the mark is drawn for**, not the mark's
own colour: the `dark` variants have a cream ring and cream wordmark and belong
on a dark ground; the `light` variants have a dark brown ring and belong on a
pale one.

| file | what it is |
|---|---|
| `jackdaw-icon-logo-{dark,light}-trans.png` | The badge alone — the jackdaw in a ringed circle |
| `jackdaw-name-logo-{dark,light}-trans.png` | The wordmark alone |
| `jackdaw-icon-name-logo-{dark,light}-row-trans.png` | Horizontal lockup — badge left, wordmark right |
| `jackdaw-icon-name-logo-{dark,light}-trans.png` | Stacked lockup — badge above wordmark |

### Brand colours

| swatch | hex | where it comes from |
|---|---|---|
| Brand brown | `#2D1500` | the ring of the light-background badge; the darkest swatch in the Affinity palette |
| Brand cream | `#FDE7BC` | the ring and wordmark of the dark-background variants (the wordmark is 100% this one colour) |

### ⚠️ The badge's cream field is semi-transparent

Only about **32% opaque**. The artwork was drawn against a light page, so
compositing it straight onto the brand brown turns the whole interior a muddy
olive — it looks fine in any image viewer (which shows it on white) and wrong
in the app.

Both generators handle this by sliding an opaque `#FDE7BC` disc underneath the
badge first, inset slightly so its edge hides beneath the cream ring. If you
ever composite the badge yourself, do the same.

## Generated app icon and splash

Neither is committed by hand — both are generated, and **regenerating is a
deliberate step**: it changes the installed app icon and needs a rebuild.

```
fvm dart run tool/generate_app_icon.dart   # badge  → assets/icon/app_icon*.png
fvm dart run flutter_launcher_icons        # fan out to iOS + Android

fvm dart run tool/generate_lockups.dart    # lockups → assets/brand/jackdaw_lockup_{dark,light}.png
fvm dart run flutter_native_splash:create  # fan the launch screen out to iOS + Android
```

The composed look: the badge on brand brown for the icon, and the horizontal
lockup centred on brand brown for the launch screen — identical in light and
dark, so a dark-mode launch never flashes white. Configuration lives at the
bottom of `pubspec.yaml`.

## In-app brand assets (`assets/brand/`)

| asset | used by | why |
|---|---|---|
| `jackdaw_wordmark.png` | `JackdawWordmark` — the home header | One flat colour, so `BlendMode.srcIn` tints it to any theme token. One file serves all 43 themes. |
| `jackdaw_lockup_{dark,light}.png` | `JackdawLockup` — server setup + sign-in, and the launch screen | The badge is illustrated, so it can NOT be tinted. Two files, picked by brightness. |

The colours also drive the app's default **Jackdaw theme**
(`lib/theme/jackdaw_theme.dart`): brown `primary` carrying a cream
`primaryForeground`, so the header bar reproduces the icon.

## Mantle marks (`mantle-logo-*`, `mantle_logo*`) — the brain's brand, not this app's

Kept for reference only. Mantle is the system this app talks to, and its marks
still appear in that context — but they are **no longer this app's brand** and
nothing here generates from them any more. Source of truth is
[`brand/` in the mantle repo](https://github.com/crossworks-engineering/mantle/tree/main/brand).
Safe to delete from this repo once nothing refers to them.
