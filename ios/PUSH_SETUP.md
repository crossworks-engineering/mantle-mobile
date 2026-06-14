# iOS Push — Xcode setup & TestFlight verification (M3)

All the **code** for iOS push is in the repo and compiles. What remains needs
**your Apple Developer account in Xcode** (capabilities, the extension target,
signing) and a **real device via TestFlight** — our APNs key is _production-only_
(topic-specific), so push does **not** work on `flutter run` / simulator builds.

**Facts wired into the code** (must match in Xcode):

| Thing | Value |
|---|---|
| App bundle id (APNs topic) | `crossworks.engineering.mantle` |
| Team id (`AppIdentifierPrefix`) | `P6NLP32L8H` |
| Shared Keychain group | `$(AppIdentifierPrefix)crossworks.engineering.mantle.pushkeys` |
| NSE target name | **`NotificationService`** (use exactly this) |
| Relay | `https://push.crossworks.network` (live, APNs prod) |

What the code already does: `AppDelegate.swift` registers with APNs + bridges the
token to Dart (`mantle/push` MethodChannel); the Dart Connect flow generates a
libsodium keypair, stores the secret key in the shared Keychain group, and runs
`/api/push/connect → relay /enroll → /api/push/subscriptions`; the NSE
(`ios/NotificationService/*.swift`) reads that key and opens the sealed box.

---

## 1. Runner capabilities

In Xcode → **Runner** target → **Signing & Capabilities**:

1. **+ Capability → Push Notifications.**
2. **+ Capability → Keychain Sharing** → add group **`crossworks.engineering.mantle.pushkeys`**.
3. Confirm **Automatically manage signing** is on with the team (`P6NLP32L8H`).

This should make Xcode use `ios/Runner/Runner.entitlements` (already in the repo
with `aps-environment` + both keychain groups). If Xcode created its own, merge
mine in (keep BOTH keychain groups — the first preserves the existing login
token, the second is shared with the NSE).

## 2. Create the Notification Service Extension

1. **File → New → Target… → Notification Service Extension.**
2. Name it exactly **`NotificationService`**. Bundle id will be
   `crossworks.engineering.mantle.NotificationService`. Activate the scheme if asked.
3. Set its **iOS Deployment Target** to match Runner.
4. **Delete the two stub files Xcode generated** (`NotificationService.swift` +
   its `Info.plist`) and instead **add the repo's files** to the target:
   `ios/NotificationService/NotificationService.swift`,
   `ios/NotificationService/PushCrypto.swift`,
   and set its Info.plist to `ios/NotificationService/Info.plist`.
   (Or paste the repo file contents over the generated stubs.)
5. **NotificationService target → Signing & Capabilities → + Keychain Sharing** →
   add the **same** group `crossworks.engineering.mantle.pushkeys`. Point its
   entitlements at `ios/NotificationService/NotificationService.entitlements`.

## 3. CocoaPods (libsodium for the NSE)

1. In `ios/Podfile`, **uncomment** the `target 'NotificationService'` block (it's
   at the bottom).
2. `cd ios && pod install` (or `fvm flutter pub get` then `pod install`).

This links `swift-sodium` into the extension for `crypto_box_seal_open`.

> **Firebase pods on iOS (from M4).** `firebase_messaging` is a cross-platform
> plugin, so its iOS pods ship even though **iOS uses raw APNs, not Firebase**.
> We never initialize Firebase on iOS (`main.dart` guards on `Platform.isAndroid`)
> and disable its app-delegate swizzling (`FirebaseAppDelegateProxyEnabled = NO`
> in `Info.plist`), so it stays inert. The only consequence: the iOS **deployment
> target must be ≥ 15.0** (set in the Podfile; also set Runner +
> NotificationService to 15.0 in Xcode → Build Settings).

## 4. Build to a device & TestFlight

Because the APNs key is **production-only**:

```bash
fvm flutter build ipa
# then upload via Xcode Organizer / Transporter, or:
# xcrun altool / fastlane
```

Install through **TestFlight** on a real iPhone. (A normal `flutter run` debug
build registers against the APNs **sandbox**, which our key can't authenticate —
Connect will fail at the relay with `BadDeviceToken`. That's expected; use
TestFlight.)

---

## 5. Verify end-to-end

1. In the app: **Settings → Notifications → Connect**. Grant permission. It should
   flip to **"This device is connected"** with no error.
2. Confirm Mantle stored the subscription:
   ```bash
   ssh mantle-prod 'docker exec mantle_pg psql -U postgres -d postgres -tA \
     -c "select platform, label, created_at from push_subscriptions;"'
   ```
   (one `ios` row), and the relay has a device:
   ```bash
   ssh mantle-prod 'docker exec mantle_push_db psql -U push -d mantle_push -tA \
     -c "select platform, last_push_at from devices;"'
   ```
3. **Background the app.** Trigger an outbound assistant turn — e.g. from the
   **web** app (`https://jason.crossworks.network`) message the assistant so it
   replies, or fire a heartbeat. The reply is an `outbound` turn →
   `worker_push` seals the teaser → relay → APNs → your phone.
4. You should get a banner with the **agent name + message preview** (decrypted by
   the NSE). Tapping it deep-links to `/chat/<agent>` (deep-link routing is M5).

Watch the worker if it doesn't arrive:
```bash
ssh mantle-prod 'docker logs -f mantle_worker_push'   # "[push-notify] <agent>: delivered 1/1"
```

---

## 6. Troubleshooting

- **Banner shows "You have a new message." (generic), not decrypted** → the NSE
  couldn't read the key or open the box. #1 cause: the **Keychain access group**
  mismatch. Verify both targets share `…mantle.pushkeys` and that the team-id
  prefix in `PushCrypto.swift` (`P6NLP32L8H`) + `push_keys.dart` matches your
  signing team. Also confirm `pod install` linked `Sodium` into the NSE.
- **Connect fails immediately** → permission denied, or no network. Re-enable
  notifications in iOS Settings.
- **Connect reaches the relay but errors** → check the relay:
  `curl https://push.crossworks.network/healthz` (should say `provider: live`).
  `BadDeviceToken` means a sandbox token hit our production key → use TestFlight.
- **Nothing arrives, worker silent** → no `push_subscriptions` row (Connect didn't
  persist) or the agent turn wasn't `outbound`.
- **The existing login breaks after adding Keychain Sharing** → the first
  keychain-access-group entry must be the app's own
  (`$(AppIdentifierPrefix)crossworks.engineering.mantle`) so items written without
  an explicit group stay readable. It's already first in `Runner.entitlements`.

Once a real decrypted push lands, M3 is done — then **M4** wires the Android FCM
side (the relay + `worker_push` already handle both platforms).
