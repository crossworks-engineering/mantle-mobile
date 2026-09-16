# Jackdaw (mobile)

The phone client for a [Mantle](https://github.com/crossworks-engineering/mantle)
brain. iOS and Android, built with Flutter and themed with
[shadcn/ui for Flutter](https://flutter-shadcn-ui.mariuti.com/), no Material
design language. You point it at your own self-hosted Mantle server and sign in
with your Mantle login; nothing goes through a third party except push
delivery (see below).

Current version: **1.11.1+19**. The full system map is in
[docs/architecture.md](docs/architecture.md); UI rules are in
[docs/styling-guide.md](docs/styling-guide.md).

## What is shipped

- **Chat** with your assistant: markdown rendering, attachments, voice in and
  voice out, live token streaming with a visible thought trail, stop and edit,
  retry, and a two-tier inbox (one card per agent, then the thread).
- **Message-attached location**: your coordinates ride along with a message
  when you opt in. Read on demand at send time, foreground only, so the app
  only ever asks for "When In Use" permission, never "Always".
- **Push notifications** from the brain, end-to-end encrypted through a blind
  relay.
- **The brain's knowledge on the phone**: read-only Pages, capture-first Tasks
  and Journal, Notes with tag filter and markdown edit, a Files browser with
  camera, library and document upload.
- **Events with real device alarms** that ring at the start time, offline,
  phone locked.
- **Global search** over the brain's hybrid full-text and vector engine, with
  type filters and deep links.
- **Offline chat**: a local read cache plus an idempotent send queue, so a
  message typed without signal lands once when you are back online.
- **Math and code highlighting** in replies: TeX inline and display, fenced
  code coloured from the active theme.

The client is intentionally thin and the brain is smart: the app sends raw
input and renders responses, with no reverse geocoding or place lookup on the
device. The one deliberate exception is **event alarms**. They are mirrored
onto the device's own alarm scheduler so they fire with no network at all.
The mirror is reconciled against the server after every fetch or change and
is best-effort; the durable reminder is still the brain's push.

## Installing today

There is no public TestFlight, no store listing and no APK download yet, and
no release pipeline. CI (`.github/workflows/verify.yml`) runs the analyzer,
the tests, a generated-code check and both release builds on every push, but
publishes nothing. The only way to get Jackdaw onto a phone today is to build
it from source with your own developer tooling.

```bash
brew install fvm                 # once, on macOS
git clone https://github.com/crossworks-engineering/jackdaw-mobile.git
cd jackdaw-mobile
fvm install                      # installs the Flutter release pinned in .fvmrc
fvm flutter pub get
```

Then, per platform:

- **iOS**: open `ios/Runner.xcworkspace` in Xcode, select your own signing
  team, and run on a device or simulator with `fvm flutter run`, or build an
  archive with `fvm flutter build ipa`. Push and alarms need a real device.
- **Android**: the build applies the Google Services plugin, so drop your own
  Firebase `google-services.json` into `android/app/` first (the file is
  git-ignored; without it the Gradle build fails). Then `fvm flutter run` or
  `fvm flutter build apk`.

Always run Flutter through fvm (`fvm flutter ...`, `fvm dart ...`) so you build
against the pinned SDK.

## Connecting to your brain

1. On first launch, enter your Mantle server's URL. The app probes it with a
   public `GET /api/version` and only continues once a Mantle answers.
2. Sign in with your Mantle email and password. The app calls
   `POST /api/auth/mobile-login` and stores the returned per-device bearer
   token in the platform keychain (`flutter_secure_storage`); the server URL
   and theme live in a local settings table.
3. Every request carries that token. A 401, or a redirect to the login page,
   means the session is invalid: the app clears the token and sends you back
   to sign in.
4. Signing out calls `POST /api/auth/mobile-logout`, which revokes the token
   server-side, then wipes it from the device.

Push is a separate one-tap step under Settings once the brain is set up for it.

## What your brain needs

- **Mantle v0.148.0 or newer.** That release added `GET /api/search`, which
  global search depends on; older servers reject it and the app treats that as
  a signed-out session. Everything else the app uses (mobile login, push
  enrollment, push preferences, events, notes, files) landed earlier.
- **A push relay**, if you want notifications. The brain must be configured
  with a Mantle Push relay; the app asks the brain for an enrollment ticket,
  enrols with the relay directly, and hands the routing token back to the
  brain. The relay only ever carries ciphertext. Details, keys and the
  protocol are in [docs/push-notifications.md](docs/push-notifications.md).
- **Location tools on the brain** (reverse geocoding, places nearby) if you
  turn on message-attached location; the phone sends coordinates only.

## Development

```bash
fvm flutter run                       # device or simulator
fvm dart run build_runner build       # after provider, model or Drift changes
fvm flutter analyze                   # must be clean before a commit
fvm flutter test
```

Riverpod 3 with code generation for state, Drift for the local database,
Dio for HTTP, go_router for navigation. Layering is UI, controller,
repository, data source, with a Riverpod provider at each boundary; tests use
`ProviderContainer` overrides, in-memory Drift and mocktail. Read
[CLAUDE.md](CLAUDE.md) for the non-negotiables before changing code.

## License

MIT, see [LICENSE](LICENSE).
