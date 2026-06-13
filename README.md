# Mantle Companion

A cross-platform mobile companion for the Mantle personal assistant. Built with
Flutter, themed with [shadcn/ui for Flutter](https://flutter-shadcn-ui.mariuti.com/)
— no Material design language.

## Scope

Two features to start:

1. **Advanced chat** — a richer mobile chat surface for talking to your Mantle
   assistant.
2. **Notifications** — push from Mantle to your phone.

Plus a supporting capability:

- **Message-attached location** — when you send a message, your current location
  rides along with it, so the assistant can answer "what's a good restaurant near
  me?" or "how far to …?". This is **not** a background tracker: location is read
  on-demand at send time, in the foreground, so the app only ever needs
  **"When In Use"** permission — never "Always".

## Architecture

The client is intentionally dumb; Mantle is smart.

- The app sends `{ lat, lon, accuracy, timestamp }` stapled to a message.
- It does **no** reverse geocoding or POI lookup on-device. Mantle owns the
  reverse-geo / "places near me" tools and enriches the raw coordinates.
- Coordinates reach Mantle through a small, platform-agnostic telemetry gateway,
  so the client plumbing stays swappable without touching the server.

## Tech

- **Flutter** (pinned via [fvm](https://fvm.app/) — see `.fvmrc`)
- **shadcn_ui** for theming and components (Tailwind-style design tokens, slate
  color scheme, light/dark)
- **geolocator** (planned) for on-demand foreground location

## Getting started

This project pins its Flutter version with fvm so everyone builds against the
same SDK.

```bash
# Install fvm once (macOS):
brew install fvm

# From the project root — installs the pinned Flutter version:
fvm install

# Run on a connected device / simulator:
fvm flutter run

# Analyze / test:
fvm flutter analyze
fvm flutter test
```

## License

MIT — see [LICENSE](LICENSE).
