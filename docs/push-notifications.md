# Design — Push notifications for Mantle Companion ("Mantle Push")

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

### 9.3 Android, the free/self-host path — **UnifiedPush**
- UnifiedPush lets the **user pick their push distributor** (e.g. self-hosted
  **ntfy**) instead of FCM — no Google, fully self-hostable, free. Great for the
  de-Googled audience. The same E2E ciphertext flows through it.
- **iOS has no equivalent** (Apple permits no third-party distributor), so Mantle
  Push stays mandatory there.
- → Android can be **free + fully self-hosted**; Mantle Push is the convenience
  default (iOS always, Android-via-FCM optionally).

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
   Committed on `main`, **not deployed** (no app/creds yet).
3. **M3 — Companion iOS**: keypair + Keychain group, APNs, NSE decrypt, one-tap
   Connect. End-to-end on one platform.
4. **M4 — Companion Android**: FCM data + decrypt handler.
5. **M5 — Settings & polish**: per-trigger toggles, quiet hours, device list,
   instance reset.
6. **M6 — UnifiedPush (Android)**: the free/self-host distributor path.
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

_No open decisions remain — the spec is ready to build against (§14)._

---

_See also: [`handover.md`](handover.md) (companion state), the live SSE design in
[`mobile-companion-backend.md`](../../mantle/docs/mobile-companion-backend.md)
(§ Live chat) which this builds directly on._
