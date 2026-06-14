import UserNotifications

/// Notification Service Extension — intercepts every `mutable-content` push,
/// decrypts the libsodium sealed box carried in `ct`, and rewrites the visible
/// title/body. The plaintext never touches APNs or the relay; only this
/// extension (holding the device secret key from the shared Keychain) can open
/// it. See ios/PUSH_SETUP.md.
class NotificationService: UNNotificationServiceExtension {
  private var contentHandler: ((UNNotificationContent) -> Void)?
  private var bestAttempt: UNMutableNotificationContent?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    let mutable = request.content.mutableCopy() as? UNMutableNotificationContent
    bestAttempt = mutable

    guard let content = mutable else {
      contentHandler(request.content)
      return
    }

    if let ct = request.content.userInfo["ct"] as? String,
       let plaintext = PushCrypto.openSealed(ciphertextBase64: ct),
       let json = try? JSONSerialization.jsonObject(with: plaintext) as? [String: Any] {
      if let title = json["t"] as? String { content.title = title }
      if let body = json["b"] as? String { content.body = body }
      // Carry the deep link through for tap handling in the app.
      if let deepLink = json["deepLink"] as? String {
        var info = content.userInfo
        info["deepLink"] = deepLink
        content.userInfo = info
      }
    } else {
      // Couldn't decrypt — show a generic, non-leaky fallback.
      content.title = "Mantle"
      content.body = "You have a new message."
    }

    contentHandler(content)
  }

  override func serviceExtensionTimeWillExpire() {
    // Called just before the extension is killed — deliver our best attempt.
    if let handler = contentHandler, let content = bestAttempt {
      handler(content)
    }
  }
}
