# Design — Push notifications for Jackdaw mobile ("Mantle Push")

_Status: **approved — ready to build** · 2026-06-13 · owner: Jason_

How a **self-hosted** Mantle backend delivers a push notification to a user's
iPhone/Android when the companion app is **backgrounded or closed** — the one
thing the live SSE stream ([`handover.md`](handover.md) §5) can't do, because
SSE dies when the app is suspended.

It requires infrastructure only the app publisher can run (Apple/Google push
credentials), delivered as a hosted relay we call **Mantle Push** (repo
`mantle-push`, we host). **Free to start**, with a clean seam to add a paid tier
later — while the app and backend stay open-source.

---

## 0. Provisioning — Apple + Firebase (done 2026-06-13)

The publisher-side push credentials are registered. **Secrets are NOT in this
repo** — the APNs `.p8` and the FCM service-account JSON live only in the
`mantle-push` deployment's secrets. These are the non-secret identifiers the
relay/app wire up against.

> ### Rename 2026-08-21, resolved 2026-09-16
>
> The bundle id changed from `crossworks.engineering.mantle` to
> `crossworks.engineering.jackdaw`. Both App IDs (the app and
> `crossworks.engineering.jackdaw.NotificationService`) were registered by
> Xcode automatic signing on 2026-09-16, with Push Notifications and the
> Keychain Sharing group `crossworks.engineering.jackdaw.pushkeys`. The old
> topic-bound key was replaced by a team-scoped one (below) and the relay was
> switched the same day. Android was unblocked the same day with a re-issued
> `google-services.json` (see `android/PUSH_SETUP.md`).

**Apple (iOS / APNs), token auth (`.p8`):**

| Field | Value |
|---|---|
| App ID (bundle id / APNs topic) | `crossworks.engineering.jackdaw` ("Jackdaw", **Push Notifications** enabled) |
| APNs Auth Key | name **Jackdaw Push**, **Key ID `QJ6ZDWSSN4`**, **team scoped** (all topics, sandbox and production). Created 2026-09-16. |
| Team ID | `P6NLP32L8H` |
| Private key file | `AuthKey.p8` for `QJ6ZDWSSN4`, one-time download on 2026-09-16, kept in the owner's password manager and on the relay as `secrets/AuthKey.p8` |

> **Relay config (live since 2026-09-16):** `APNS_KEY_ID=QJ6ZDWSSN4`,
> `APNS_TEAM_ID=P6NLP32L8H`, `APNS_TOPIC=crossworks.engineering.jackdaw`,
> `APNS_ENV=production`. The relay talks to one APNs environment at a time and
> that is production, so push is testable on TestFlight and App Store builds
> only. An Xcode development build registers a sandbox token, which the
> production relay rejects and prunes.
>
> _History: `J65R8HBX33` ("pushy2", team scoped) lost its one-time `.p8` and
> was revoked on 2026-09-16 to free the team-scoped slot. `2TJ76S5L69`
> (topic specific, `crossworks.engineering.mantle`, 2026-06-14) served until
> the rename and is retired; its file stays on the relay as
> `secrets/AuthKey.2TJ76S5L69.bak`._

**Firebase (Android / FCM) — HTTP v1:**

| Field | Value |
|---|---|
| Firebase project | **pusher** · id `pusher-5bacc` · sender/project number `426833137509` (free Spark plan — FCM included) |
| Android app (package) | `crossworks.engineering.jackdaw` |
| `google-services.json` | ✅ downloaded (for the Flutter app at `android/app/`). Re-download: Firebase → pusher → ⚙ Project settings → Your apps → Jackdaw. Not a secret. |
| Service-account JSON | ✅ **generated 2026-06-14** (`firebase-adminsdk-m8shx@pusher-5bacc`) for the relay's FCM v1 sends → `mantle-push` `secrets/fcm-service-account.json`. **Server secret; never commit** (the relay repo is public). Re-generatable. |

> iOS does **not** need Firebase — it goes straight to APNs via the `.p8`. FCM is
> Android-only here.

---

## 1. The constraint we can't engineer around

A store-distributed app (one App Store / Play Store listing) has **one** bundle
id and **one** set of push credentials — Apple **APNs** key and Google **FCM**
sender — held by the **publisher** (us). Device push tokens are scoped to those
credentials, and **only the holder of the APNs key can deliver a push to the
app.**

Therefore a self-hoster's Mantle backend **physically cannot** push to the store
app on its own. A central relay that holds the app's push credentials is not a
design choice — it is mandatory for any store app. Apple enforces this strictly;
Google is looser (see UnifiedPush, §9.3).

The trick is to make that relay **a blind, end-to-end-encrypted pipe**, so it
never betrays the self-hosted/privacy promise — and turn the necessity into a
feature: _"your assistant's notifications are end-to-end encrypted; Mantle Push
can't read them."_

---

## 2. Goals / non-goals

**Goals**
- Deliver proactive/cross-channel messages (and approvals) to a backgrounded or
  closed app, reliably, on iOS and Android.
- Mantle Push learns **routing metadata only** — never notification content.
- **One-tap setup**: the user taps **Connect** in the app; Mantle self-generates
  its push token and the device enrolls automatically. Nothing to buy, nothing
  to paste, no per-user Apple/Google accounts — ever.
- **Free at first**, with a clean seam to add a paid tier later without closing
  the source.
- A fully self-hostable / free path where the platform allows it (Android).

**Non-goals**
- Replacing the in-app live stream. Push is an **enhancement**; the SSE stream +
  read cursors remain the source of truth, and the app reconciles on open
  (§13). A missed push is never lost data.
- Rich media / actionable notifications in v1 (text + deep link only).
- A general-purpose push product for third parties.

---

## 3. Principles

1. **Blind relay.** Mantle Push routes ciphertext. It cannot read content;
   neither can APNs/FCM. Compromise of the relay leaks _metadata_ (which device,
   when, size), never message bodies.
2. **Mantle self-generates the long-lived secret; devices hold short-lived
   ones.** A per-install **instance token** lives only in the user's Mantle
   backend. Devices get scoped, rotatable routing tokens.
3. **Push is best-effort.** Every push has an in-app fallback. Delivery failure
   degrades to "you'll see it when you open the app," never to data loss.
4. **Open protocol, open clients.** The relay's wire protocol is documented and
   `mantle-push` is self-hostable; only the convenience of a hosted, credentialed
   relay is (eventually) paid.

---

## 4. Architecture at a glance

```
   ┌─────────────────┐
   │  User's Mantle  │  (1) first Connect: self-generate instance token,
   │  backend (self- │      register it with Mantle Push (TOFU)
   │  hosted)        │                                   ┌──────────────────────┐
   │                 │   (4) POST /notify {routing,      │  Mantle Push         │
   │  instance token │        ciphertext}  ───────────▶  │  (mantle-push, we    │
   │  push_subs:     │                                   │  host; free at first)│
   │  routingToken,  │                                   │  holds APNs key +    │
   │  devicePubKey   │   (2) enroll (ticket + pushtoken) │  FCM creds; instance │
   └────────┬────────┘   ◀───────────────────────────── │  → devices map       │
            │ (3) store routing token + device pubkey    │  NEVER sees plaintext │
   ┌────────▼─────────┐                          ▲       └──────────┬───────────┘
   │  Companion app   │  ─────────────────────────┘                 │
   │  iOS / Android   │     enroll → routing token        ┌─────────▼─────────┐
   │  [ Connect ] tap │                                   │   APNs / FCM      │
   │  keypair + OS    │  ◀════════ ciphertext ════════════│  (ciphertext)     │
   │  push token      │                                   └───────────────────┘
   │  NSE/handler     │
   │  decrypts+shows  │
   └──────────────────┘
```

**Three components:**
- **Mantle backend** (open, self-hosted) — generates its instance token, stores
  each device's routing token + public key, encrypts notification bodies to the
  device, calls Mantle Push.
- **Mantle Push** (`mantle-push`, new, central, we host — _the relay_) — holds the
  APNs/FCM credentials and the `instance → devices` map; forwards opaque blobs.
- **Companion app** (open) — one-tap **Connect**, generates a keypair, enrolls its
  OS push token, decrypts and displays in a Notification Service Extension (iOS) /
  data-message handler (Android).

---

## 5. Identity & connection — one tap

Three credentials (no purchased account key — Mantle makes its own). Keeping them
separate is what makes the relay blind and the secret containment clean.

| Credential | Created by | Held by | Lifetime | Purpose |
|---|---|---|---|---|
| **Instance token** | the user's **Mantle**, auto-generated on first Connect | **Mantle only** (never on a device) | until reset | authenticates Mantle→Mantle Push; identifies this install |
| **OS push token** (APNs/FCM) | the OS | device → relay | rotates per OS | where APNs/FCM actually deliver |
| **Routing token** | Mantle Push, at enrollment | device → handed to **Mantle** | per device, revocable | opaque handle for "this device under this install"; Mantle sends to it |
| **Device keypair** | the device | private key on device (Keychain/Keystore); public key → Mantle | per device, rotatable | E2E: Mantle seals to the public key, device opens with the private key |

### 5.1 What "Connect" does (one tap, in the app)

Settings → Notifications → **Connect**. Behind that single tap:

```
1. App: request notification permission; get the OS push token (APNs/FCM);
   ensure a device keypair exists (secret key in Keychain/Keystore, shared to
   the iOS NSE via a Keychain access group).
2. App → Mantle:  POST /api/push/connect   (bearer-auth'd)
      { platform, osPushToken, publicKey }
   - First time ever: Mantle GENERATES its instance token (a high-entropy
     secret) and registers it with Mantle Push (POST /instances — trust-on-
     first-use; the token is unguessable, so registering it claims it).
   - Mantle mints a short-lived ENROLLMENT TICKET (signed with the instance
     token, ~5 min TTL) binding { instance, osPushToken }.
3. App → Mantle Push:  POST /enroll  { ticket, platform, osPushToken }
   Verifies the ticket came from a registered instance; creates a device row;
   returns a ROUTING TOKEN.
4. App → Mantle:  POST /api/push/subscriptions
      { routingToken, publicKey, platform, label }
```

No codes, no pasting, no account. The instance token is internal plumbing the
user never sees. (Mantle could mint the ticket and hand the relay base URL to the
app in step 2's response, so the app needs no hardcoded relay URL beyond a
default.)

### 5.2 Why a self-generated instance token (not a purchased key)

- **Free + zero friction**: nothing to buy or paste; Connect is the whole UX.
- **Bounded blast radius**: a Mantle install can only push to devices that
  **enrolled under its own instance token** (enrollment needs a ticket signed by
  that token). There is **no way to push to a stranger's device** — so a
  self-claimed, free token is safe. Rate limits cap volume/cost.
- **Trust-on-first-use** is sound here because the token is a 256-bit secret:
  unguessable, and the first registrant claims it. (Optional hardening later:
  bind an instance to a verified email or a signed Mantle build attestation.)

### 5.3 Lifecycle, rotation, revocation

- **OS push token rotates** (OS decides): the app silently re-enrolls and updates
  Mantle.
- **Unpair a device** (Mantle/app Settings): delete the `push_subscriptions` row
  + relay device row → no more pushes there.
- **Reset the instance** (Settings, e.g. after a suspected leak): Mantle rolls a
  new instance token, re-registers, and all old routing tokens are invalidated;
  devices re-Connect.
- **Key rotation**: device generates a new keypair, re-enrolls, updates Mantle's
  stored public key. Old in-flight ciphertext to the old key is simply undelivered.

---

## 6. End-to-end encryption

**Scheme: libsodium sealed boxes (`crypto_box_seal`). _Decided._**
- Device publishes its **public key**; Mantle seals each payload to it. Only the
  device's secret key opens it. Anonymous-sender, no shared secret, no key
  exchange round-trip — ideal for a one-way notification.
- Mantle side: `libsodium-wrappers` / `tweetnacl` (Node). Device side:
  `sodium_libs` / `flutter_sodium`. (`age`/X25519 was considered — same idea, but
  a heavier format per message and thinner Dart support; sealed boxes win on size
  + ecosystem for tiny single-device payloads.)

**Payload (plaintext, before sealing):**
```jsonc
{ "v": 1, "t": "Saskia", "b": "You've got 3 emails worth a look…",
  "agentSlug": "assistant", "deepLink": "/chat/assistant", "ts": 1782... }
```
Sealed → base64 → placed in the APNs/FCM **data** payload with
`mutable-content: 1` (iOS) so the app gets to transform it before display.

**Size:** APNs and FCM both cap ~4 KB. A sealed short notification is well under.
For long bodies: send a **teaser** + `deepLink`; the app fetches the full thread
on tap (it already has the SSE/REST path). No plaintext ever rides APNs/FCM.

**On-device display:**
- **iOS** — a **Notification Service Extension** intercepts the push
  (`mutable-content`), reads the secret key from a shared Keychain access group,
  opens the sealed box, rewrites `title`/`body`. ~50 lines of Swift.
- **Android** — an **FCM data message** wakes a background handler; it decrypts
  and posts a local notification. (Data messages, not `notification` messages,
  so our code always runs.)

---

## 7. The relay service — `mantle-push`

A small, stateless-ish service we host at **`https://push.crossworks.network`**
(its own repo). **Holds the APNs `.p8` key + FCM service account. Never holds
private keys or plaintext.**

> **Deployment (interim).** For development and until the first real client,
> `mantle-push` runs **co-located on the production server**, as another service
> behind the existing Caddy reverse proxy — `push.crossworks.network` points at
> prod. It moves to its **own small VPS** once there's usage. Because clients only
> ever know the `relay_url` (DNS), that migration is a transparent repoint — no
> client or token change. _Caveat to retire on the move:_ co-location puts the
> APNs `.p8` + FCM creds on the prod box, so a prod compromise would also expose
> push creds (and vice-versa); isolating them on a dedicated VPS is part of why we
> move.

### 7.1 API (sketch)

| Endpoint | Auth | Body | Notes |
|---|---|---|---|
| `POST /instances` | instance token | `{instanceToken}` | TOFU register/claim an install |
| `POST /enroll` | enrollment ticket | `{ticket, platform, osPushToken}` | verify ticket→instance; create device; return `{routingToken}` |
| `POST /notify` | instance token (Bearer) | `{routingToken, ciphertext, collapseKey?, priority?}` | look up device; forward to APNs/FCM |
| `POST /refresh` | routing token | `{osPushToken}` | OS token rotated |
| `DELETE /device` | routing token or instance token | `{routingToken}` | unpair |
| `GET /instance` | instance token | — | device list (metadata only), status |

`/notify` and `/enroll` are **rate-limited per instance**. `collapseKey` lets
repeated nudges supersede each other (APNs `apns-collapse-id` / FCM
`collapse_key`). **Free tier: no entitlement gate — just rate limits** (see §11
for the paid seam).

### 7.2 Data model (what it stores — note the absences)

```
instances(id, instance_token_hash, created_at, last_seen_at
          /* + plan, status, expires_at  ← added only when a paid tier lands */)
devices(id, instance_id, platform, os_push_token, routing_token_hash,
        pubkey_fingerprint?, last_seen_at, created_at)
-- NO private keys. NO message bodies. NO plaintext titles. NO Mantle URL.
```
It cannot link a device to a real identity beyond "instance N, device M" and the
OS push token. Bodies are opaque.

### 7.3 Build (decided)
`mantle-push` is **built and self-hosted** by us — ~a few hundred lines: APNs
HTTP/2 + JWT (the `.p8` key), FCM v1, a Postgres table, per-instance rate limits.
APNs/FCM **sends are free**; the cost is just a tiny always-on service — which is
why it can launch free and later carry a small fee comfortably. (A bought relay
— OneSignal / Pusher Beams / Pushy.me — remains a fallback if we ever want to
offload APNs/FCM plumbing; E2E means they'd see only ciphertext anyway.)

---

## 8. Mantle backend changes

- **Schema** `push_subscriptions(owner_id, device_id, routing_token,
  public_key, platform, label, created_at, last_push_at)` — one row per enrolled
  device. Plus a single-row **`push_instance(instance_token, relay_url,
  connected_at)`** for this install's relay identity (`relay_url` defaults to
  `https://push.crossworks.network`, overridable for self-hosters).
- **Routes** (owner-gated via the existing `getOwnerOr401`,
  [audit notes](../../mantle/docs/mobile-companion-backend.md)):
  `POST /api/push/connect` (lazily generate + register the instance token, mint
  the enrollment ticket), `POST /api/push/subscriptions` (store routing token +
  pubkey), `DELETE /api/push/subscriptions/:id`, `POST /api/push/reset` (roll the
  instance token).
- **Send hook**: reuse the **`conversation_changed` signal we already built** for
  SSE (migration 0091). A worker subscribes to it (or a DB-trigger NOTIFY drives
  a job); for **outbound** turns (and `pending_changed`), it: looks up the
  owner's devices → seals the teaser to each `public_key` → `POST /notify`.
  Suppress when a device pinged the SSE stream within ~15 s (it's foregrounded).
- **Settings UI** (Mantle web + app): Connect/disconnect, per-device list,
  per-trigger toggles, quiet hours.

---

## 9. Companion app changes

### 9.1 iOS
- Notification permission; APNs registration; **Notification Service Extension**
  for decrypt; **Keychain access group** shared app↔extension for the secret key.
- `flutter_sodium`/`sodium_libs` for sealed-box open.

### 9.2 Android
- FCM **data messages** + a background isolate handler that decrypts and posts a
  local notification (via `flutter_local_notifications`).

### 9.2a What the notification says: plain words

A reply is markdown, and the teaser a brain seals may still carry it (a brain
that cuts the reply to 140 characters without stripping it sends `**Done.**
See [the plan](page:…)` to the lock screen). So the app reduces title and body
to plain words before showing them, whatever the brain sent: emphasis and
heading marks go, a link is its text, an image its alt text, a reference chip
its label, a table its cells, a code fence its code. Then whitespace collapses,
a blank field takes its fallback, and the body is cut to 140 graphemes (what a
person sees as one character, so an emoji is never cut in half).

Only the first 2000 Unicode scalars of a message are read. Some strip rules
are quadratic on input they cannot match (a run of unmatched `[`), and a brain
sends whatever its reply holds. The home screen's last-message card cuts the
same way before it renders. A "word character" in the rules is a letter, mark
or digit in any script, spelled out in both twins, because Dart's `\w` is
ASCII and Swift's (ICU) is not.

It has to hold for two shapes of input: the whole reply with its lines (the
direct connection reads it from the inbox) and a teaser the brain already
flattened to one line and cut, where a block mark sits mid-line and a link may
be left unclosed.

- Android, both paths (FCM and the direct connection):
  `pushNotificationText` / `plainFromMarkdown` in
  [`lib/data/push/push_text.dart`](../lib/data/push/push_text.dart).
- iOS: the Notification Service Extension draws the notification and no Dart
  runs, so `PushText` in `ios/NotificationService/NotificationService.swift`
  is the same rules in Swift. `tool/check_push_text_swift.sh` runs it against
  the cases in `test/data/push_text_test.dart`; change both together. CI runs
  it in the iOS job.

### 9.2b Opening the item a push is about

A tap opens the item the notification is about, on the login it was for, on
a cold start and while the app is open. Every arrival path becomes one
`NotificationTap` (`lib/data/push/notification_tap.dart`):

| Path | Carries |
| --- | --- |
| iOS push (the extension copies the fields into `userInfo`, the AppDelegate hands them over the `mantle/push` channel as a map) | `deepLink`, `itemLink`, `brainId`, `loginId` |
| Android push (FCM data message, shown as a local notification) | the same four, as the local payload (JSON) |
| Direct connection (Android, no Google) | the chat link and the device-local `sessionId` of its stream |
| Event alarm this phone armed (`event-alarm:<id>:<ms>:<kind>`) | that event: `/events/<id>` |

**Where to.** `itemLink` (a brain from v0.239 sends `/events/<id>` on an event
reminder) wins when it is one of the app's routes; else `deepLink`. Both pass
`sanitizeDeepLink`. `/events/<id>` and `/tasks/<id>` open the list with that
item's sheet on top; an item that is gone, or not this login's, leaves the list
with a short message. Home goes under it, so Back lands on Home. No brain
sends a task push yet; the route is ready for one.

**Which login** (`resolveTap`, the contract in the brain's
`docs/mobile-companion-backend.md`, "Push routing on a device with several
logins"). Each held login stores the (`brainId`, `loginId`) pair `GET
/api/auth/whoami` answers (schema v4), learned when it is in use
(`BrainIdentitySync`) or, at tap time, by asking that login's own brain with
its own bearer. A push naming its pair switches to the held login with that
pair. The same brain id held at two addresses is ambiguous, and a pair no
held login has is for a login signed out here: both open Home and follow
nothing. A push naming no pair (an older brain, an alarm) opens on the login
in use, as before.

**Cold start.** The router waits for the session to settle before it acts
(navigating during the splash is undone by the auth gate). On iOS an alarm tap
that launched the app is read from the local-notification plugin at start-up;
the AppDelegate hands any notification without a `deepLink` (an alarm) to the
plugin through `super`, so alarm taps route on iOS too.

### 9.3 Android, the no-Google path — **built-in direct connection** (decided)

FCM needs **Google Play Services**, which de-Googled ROMs (GrapheneOS, /e/OS,
LineageOS-sans-Play) don't have — and that's exactly the audience a self-hosted
Mantle attracts. For them, the chosen path is a **built-in "direct connection"**,
not a third-party distributor:

- An Android **foreground service** keeps the app's existing **SSE stream**
  (`/api/assistant/stream`) alive while backgrounded, and posts a local
  notification when an outbound turn arrives. The message comes **directly from
  the user's own Mantle over TLS** — so this path needs **no relay, no FCM, no
  ntfy, no Google, and no sealed-box crypto** (there's no middleman to blind).
  It reuses the live-chat stack we already have.
- **Cost:** Android requires a persistent foreground-service notification
  ("Mantle is connected"), and it uses more battery than FCM's shared socket;
  aggressive OEM ROMs may need a battery-optimization exemption. Android-only —
  iOS suspends background sockets, so iOS is **always** APNs via the relay.
- **UnifiedPush + ntfy** remains a possible *secondary* option (shared, battery-
  friendlier distributor) but is **not** the default: it needs a second app
  installed, whereas the built-in path is self-contained and depends on no one
  but the user's own server.

**Per-device transport (the hybrid):** each device enrolls with exactly ONE
transport; the backend delivers to whichever it chose.

| Device | Transport | Path |
|---|---|---|
| iOS | APNs (E2E) | via Mantle Push relay — no alternative |
| Android + Google | FCM (E2E) | via Mantle Push relay |
| Android, no Google | **Direct connection** | foreground service ↔ the user's Mantle (no relay/FCM/ntfy) |

---

## 10. Trigger & delivery policy

- **What pushes** (configurable, in priority order): proactive/heartbeat
  outbound messages → pending approvals → @-mentions. Routine replies to a
  message you just sent do **not** push.
- **Suppression**: if the device is foregrounded (SSE connected), the client
  drops the local notification — it's already showing the message. Belt: Mantle
  skips push when it saw a stream ping from that device < ~15 s ago.
- **Collapse / batch**: use `collapseKey` per agent so "3 new from Saskia"
  supersedes rather than stacks; optional server-side debounce window.
- **Quiet hours**: enforced in Mantle (it owns the schedule) before calling the
  relay.

---

## 11. Free now, paid later (clean seam)

- **v1 is free.** Mantle Push has **no entitlement gate** — only per-instance rate
  limits. Connect just works.
- **The seam for a future paid tier** (so "free at first" costs no rework): add
  `plan / status / expires_at` to the relay's `instances` row and check it in
  `/enroll` + `/notify`; flip it via a billing webhook (Stripe). Nothing else in
  the architecture changes — same tokens, same flows, same crypto. Could gate on
  device count, push volume, or simply "supporter unlock."
- **Escape hatches (keep us honest)**:
  - **Android**: UnifiedPush + self-hosted ntfy → free, no relay.
  - **Power users**: `mantle-push` is open and self-hostable — but self-hosting it
    for *iOS* still needs your own Apple Developer account + an app rebuild with
    your own bundle id/APNs key (the friction Apple imposes, and the reason the
    hosted relay exists). For nearly everyone, the hosted Mantle Push is the path.

---

## 12. Threat model / privacy

| Party | Can see | Cannot see |
|---|---|---|
| **Mantle Push** | instance id, device id, OS push token, timestamps, ciphertext size, collapse key | notification content, Mantle URL, message history, private keys |
| **APNs / FCM** | device token, ciphertext, timestamps | content (sealed) |
| **Network attacker** | TLS metadata | everything inside TLS + the sealed box |
| **Compromised relay** | the metadata above; could **drop** or **spam** pushes (DoS), not read or forge content (no private keys; forged pushes fail to decrypt) | content; cannot impersonate the agent in-app |

Notes:
- **TOFU registration** is safe because the instance token is a 256-bit secret —
  guessing/collision is infeasible, and a push can only reach devices that
  enrolled under that exact token (so no spamming strangers).
- A **leaked instance token** lets an attacker enroll devices / exhaust rate
  limits and send blobs — but those blobs only decrypt on devices holding the
  matching private key (the user's own), so **no content exposure or forgery**.
  Mitigate with **instance reset** (§5.3) + rate caps.
- No content at rest anywhere central. Replay bounded by `ts` + collapse keys.

---

## 13. Failure modes & fallbacks

- **Relay down / push undelivered** → next app open, SSE + read cursors show
  everything. No loss.
- **Permission denied / no push token** → app silently runs SSE-only; Settings
  explains.
- **Token expired / OS rotated** → silent re-enroll on next foreground.

Push is strictly additive on top of the existing live stream.

---

## 14. Phased plan

1. **M1 — `mantle-push` MVP** — ✅ **BUILT (2026-06-14)**, repo
   `~/Projects/mantle-push` (Node + TS + Hono, own Postgres). APNs (HTTP/2 + ES256
   `.p8`) + FCM v1, `/instances` (TOFU), `/enroll`, `/notify`, `/refresh`,
   `DELETE /device`, `/instance`, per-instance rate limits, plus a **mock** provider
   so the spine is CLI-verifiable with no creds (14-check `scripts/smoke.ts` passes).
   **Deploy is wired but gated**: the Caddy site block `push.crossworks.network {
   reverse_proxy push:8787 }` is already added to the Mantle Caddyfile (inert until
   the container joins `mantle_default`); full steps in `mantle-push/docs/deploy.md`.
   Interim co-location on prod, own-compose joined to Caddy's network — no edit to
   Mantle's `docker-compose.yml` required.
2. **M2 — Mantle side** — ✅ **BUILT (2026-06-14, Mantle v0.25.0)**. Migration
   0092 (`push_instance` singleton w/ instance token sealed at rest +
   `push_subscriptions`); owner-gated `POST /api/push/connect` (lazy instance-token
   gen → relay register → enrollment-ticket mint), `POST|GET /api/push/subscriptions`,
   `DELETE /api/push/subscriptions/:id`, `POST /api/push/reset`; `lib/push/*`
   (token + HMAC ticket wire-compatible with the relay, **libsodium
   `crypto_box_seal`** to the device pubkey, relay client); **`worker_push`**
   LISTENs `conversation_changed` and forwards each outbound turn's sealed teaser
   to the relay `/notify`. Verified E2E against the **live** relay
   (`scripts/verify-push-m2.ts`: sealed-box round-trip; relay accepts
   instance/ticket/notify; `pushOutbound` delivers 1/1; worker fires on trigger).
   **DEPLOYED to prod 2026-06-14** (Mantle v0.25.0): migration 0092 applied
   (drizzle 93), `worker_push` listening, `/api/push/*` routes live + owner-gated.
   Relay still **mock** — flip to live needs the two §0 secret files on the box;
   then M3/M4 for a device to actually receive.
3. **M3 — Companion iOS** — ✅ **CODE-COMPLETE (2026-06-14)**. Dart: `data/push/*`
   (PushApi, sodium_libs X25519 keypair → secret key in a shared iOS Keychain
   group, ApnsBridge MethodChannel), `PushController` one-tap Connect, Settings →
   Notifications screen (analyze clean; connect happy-path + declined tests pass).
   Native: `AppDelegate.swift` (APNs registration + token bridge), the
   **Notification Service Extension** (`ios/NotificationService/*` — swift-sodium
   `crypto_box_seal_open` from the shared Keychain), entitlements + Podfile block.
   **Remaining = Xcode + TestFlight** (Apple-account-only: add capabilities, create
   the NSE target, sign, archive) — our APNs key is production-only so a real
   decrypted push verifies via TestFlight, not `flutter run`. Full runbook:
   `ios/PUSH_SETUP.md`.
4. **M4 — Companion Android** — ✅ **CODE-COMPLETE (2026-06-14)**. `firebase_messaging`
   FCM token (platform-aware `PushTokenService`; Connect now does iOS **or** Android),
   a Dart **background-isolate handler** that opens the sealed box (`sodium_libs`
   `crypto_box_seal_open`, key from secure storage) and posts a local notification
   via `flutter_local_notifications`. Gradle (`google-services` plugin) + manifest
   (`POST_NOTIFICATIONS`) wired; `google-services.json` staged. Firebase kept
   **Android-only** (guarded init + `FirebaseAppDelegateProxyEnabled=NO`) so the iOS
   raw-APNs path is untouched (note: pulls iOS deploy target to 15+). analyze + tests
   clean. **Remaining = run on a Play-services device/emulator** (runbook:
   `android/PUSH_SETUP.md`).
5. **M5 — Settings & polish** — ✅ **CODE-COMPLETE (2026-06-14)**. Backend (Mantle
   v0.26.0): migration 0093 `push_prefs` (toggles + quiet hours), GET/PUT
   `/api/push/preferences`; the send-worker enforces the assistant-messages toggle +
   tz-aware quiet hours, and a new **approvals trigger** (`worker_push` also LISTENs
   `pending_changed` → `pushApproval`, gated by the toggle). App: Settings →
   Notifications now has per-trigger switches, quiet hours (enable + From/To, device
   IANA tz auto-adopted), the device list with unpair, and Reset push (confirm →
   `/api/push/reset`). Quiet-hours helper unit-tested; analyze + tests clean both
   sides. Not deployed (batches with the device-verified push deploy).
6. **M6 — Direct connection (Android, no-Google)**: a foreground service that
   holds the SSE stream open and posts local notifications straight from the
   user's Mantle — no relay/FCM/ntfy/crypto (§9.3). The de-Googled path; FCM
   stays the default for Play-Services devices. (UnifiedPush+ntfy considered and
   set aside as a secondary option — built-in is more self-contained.)
7. **(later) Paid seam**: entitlement field + billing webhook, only if/when we
   monetize.

Each milestone is independently demoable; M1–M3 prove the whole spine.

---

## 15. Decisions

**Locked:**
- **Name**: the service is **Mantle Push**; repo **`mantle-push`**; we host it.
- **Connection**: Mantle **self-generates a per-install instance token**; the app
  has a single **Connect** button; no purchase, no pasting (§5).
- **Pricing**: **free at first**, with the paid seam in §11 reserved.
- **Relay**: **build** (not buy), self-hosted by us (§7.3).
- **Crypto**: **libsodium sealed boxes** (§6).
- **Hosting**: **`https://push.crossworks.network`** (the default `relay_url`;
  overridable for self-hosters). **Interim**: co-located on the prod server behind
  Caddy; moves to its own small VPS at the first real client — a transparent DNS
  repoint (§7).
- **Triggers + quiet hours**: ship the **§10 defaults** — proactive/heartbeat →
  approvals → @-mentions, foreground-suppressed, with quiet hours enforced
  Mantle-side; all toggleable in Settings.
- **TOFU hardening** (email / build attestation): **deferred** — launch with
  trust-on-first-use as in §5.2; revisit if abuse shows up.
- **No-Google Android** (decided 2026-06-14): the path is a **built-in direct
  connection** (a foreground service holding the SSE stream open, posting local
  notifications straight from the user's Mantle — no relay/FCM/ntfy/crypto), NOT
  UnifiedPush. Per-device hybrid: FCM stays the default for Play-Services devices;
  direct connection is the de-Googled fallback; iOS is always APNs. UnifiedPush+
  ntfy is set aside as a secondary option (§9.3).

_No open decisions remain — the spec is ready to build against (§14)._

---

_See also: [`handover.md`](handover.md) (companion state), the live SSE design in
[`mobile-companion-backend.md`](../../mantle/docs/mobile-companion-backend.md)
(§ Live chat) which this builds directly on._
