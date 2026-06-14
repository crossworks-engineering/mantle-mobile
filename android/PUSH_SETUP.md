# Android push — FCM setup & verification (M4)

Android push is **FCM data messages**, decrypted in a Dart background isolate and
shown via a local notification. Unlike iOS, there's no native extension or signing
ceremony — most of it is already wired in the repo.

**Facts:**

| Thing | Value |
|---|---|
| Android package | `me.schoeman.mantle_companion` |
| Firebase project | `pusher` (`pusher-5bacc`) |
| `google-services.json` | already at `android/app/` (gitignored) |
| Notification channel | `mantle_messages` ("Messages") |

What the code already does (`lib/data/push/*` + `lib/main.dart`):
- `main()` on Android calls `setupAndroidPush()` → `Firebase.initializeApp()`,
  registers the background handler, and listens for foreground data messages.
- Connect (Settings → Notifications) requests permission, gets the **FCM token**,
  generates the libsodium keypair, and runs `/api/push/connect → relay /enroll →
  /api/push/subscriptions` with `platform: 'android'`.
- Incoming data message → `PushNotifier.showFromData` decrypts the sealed `ct`
  (`crypto_box_seal_open` via `sodium_libs`, key from secure storage) and posts a
  local notification.

## Already wired in the repo
- `android/settings.gradle.kts` + `android/app/build.gradle.kts`: the
  `com.google.gms.google-services` plugin.
- `AndroidManifest.xml`: `POST_NOTIFICATIONS` permission.
- `firebase_messaging` auto-registers its `FirebaseMessagingService` (manifest
  merge) — no manual service declaration needed.

## Build & run

```bash
fvm flutter pub get
fvm flutter run                 # a real device or an emulator WITH Google Play services
```

> The emulator image must include **Google Play** (FCM needs Play services). Use a
> "…(Google Play)" system image, not a plain AOSP one.

## Verify end-to-end

1. **Settings → Notifications → Connect.** Grant the notification prompt. It should
   flip to "This device is connected".
2. Confirm Mantle + relay rows (one `android`):
   ```bash
   ssh mantle-prod 'docker exec mantle_pg psql -U postgres -d postgres -tA \
     -c "select platform, label from push_subscriptions;"'
   ```
3. **Background the app.** Trigger an outbound assistant turn (message the
   assistant from the web app so it replies, or fire a heartbeat).
4. A notification with the agent name + message preview should appear (decrypted
   on-device). Watch the worker if not:
   ```bash
   ssh mantle-prod 'docker logs -f mantle_worker_push'   # "[push-notify] <agent>: delivered 1/1"
   ```

## Troubleshooting

- **No token / Connect fails** → emulator/device lacks Google Play services, or
  permission denied. Use a Play-enabled image; re-enable notifications in Settings.
- **Notification arrives but says "You have a new message." (generic)** → decrypt
  failed (no local keypair, or a stale one). Disconnect + Connect again to
  regenerate keys and re-subscribe.
- **`google-services.json` missing at build** → it's gitignored; re-download from
  Firebase → pusher → Project settings → Your apps → `me.schoeman.mantle_companion`.
- **FCM `INVALID_ARGUMENT` in the worker log** → the stored routing token's device
  was pruned (token rotated). Reconnect.

Note: the relay already authenticates to FCM (verified 2026-06-14). Once a
decrypted notification lands on an Android device, M4 is done.
