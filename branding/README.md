# Branding

## Official logo files (`mantle-logo-*`)

The current official Mantle marks. These are copies — the source of truth is
[`brand/` in the mantle repo](https://github.com/crossworks-engineering/mantle/tree/main/brand),
which carries the full usage notes. If the mark changes, it changes there first
and gets copied here.

| file | what it is |
|---|---|
| `mantle-logo-icon.svg` / `.png` | Icon (`m` in a filled circle), solid black |
| `mantle-logo-icon-color.svg` / `.png` | Icon, blue gradient with a white `m` |
| `mantle-logo-full.svg` / `.png` | Full wordmark, solid black |
| `mantle-logo-full-color.svg` / `.png` | Full wordmark, blue-to-purple gradient |

SVG is the master; the PNGs are transparent RGBA exports (icon 2000x2000,
wordmark 1400x400).

## Older files (`mantle_logo*`)

`mantle_logo.png`, `mantle_logo.svg` and `mantle_logo_full.png` are the earlier
exports from July 2026. Same artwork, but looser crops, and the icon predates
the circle badge. They are kept only so nothing referencing them breaks —
**use the `mantle-logo-*` files above for anything new.**

## Note on the app launcher icon

The Flutter launcher icons under `assets/icon/` are generated separately and
were **not** regenerated when these files landed, so they still derive from the
older artwork. Refreshing them is a deliberate step (it changes the installed
app icon and needs a rebuild), not something that follows automatically from
dropping new files in here.
