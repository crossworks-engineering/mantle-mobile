import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // Held only while a registerForRemoteNotifications() round-trip is in flight,
  // so the MethodChannel call can resolve with the APNs token (or nil on
  // failure/denial). See lib/data/push/apns_bridge.dart.
  private var pendingTokenResult: FlutterResult?
  private var pushChannel: FlutterMethodChannel?
  // A notification tapped before Dart attached its handler (cold launch). Held
  // until Dart pulls it via the `getInitialDeepLink` MethodChannel call.
  private var pendingLaunchDeepLink: [String: String]?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let messenger = engineBridge.pluginRegistry
      .registrar(forPlugin: "MantlePush")?.messenger() {
      let channel = FlutterMethodChannel(name: "mantle/push", binaryMessenger: messenger)
      channel.setMethodCallHandler { [weak self] call, result in
        self?.handle(call, result)
      }
      pushChannel = channel
    }
  }

  // MARK: - Push MethodChannel

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    switch call.method {
    case "requestAuthorizationAndRegister":
      requestAuthorizationAndRegister(result)
    case "isAuthorized":
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        DispatchQueue.main.async {
          let ok = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
          result(ok)
        }
      }
    case "getInitialDeepLink":
      // Cold-launch tap: hand over (and clear) the stored deep link, if any.
      let link = pendingLaunchDeepLink
      pendingLaunchDeepLink = nil
      result(link)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestAuthorizationAndRegister(_ result: @escaping FlutterResult) {
    UNUserNotificationCenter.current()
      .requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
        guard granted, error == nil else {
          DispatchQueue.main.async { result(nil) } // declined → null token
          return
        }
        DispatchQueue.main.async {
          // Resolve once the device token arrives (didRegister… below).
          self?.pendingTokenResult = result
          UIApplication.shared.registerForRemoteNotifications()
        }
      }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    pendingTokenResult?(token)
    pendingTokenResult = nil
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    pendingTokenResult?(nil)
    pendingTokenResult = nil
  }
}

// Show the (NSE-decrypted) banner even when the app is foregrounded. Suppressing
// it while the live SSE stream is showing the same message is a later
// refinement (push-notifications.md §10).
extension AppDelegate {
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound, .badge])
  }

  // A tapped push: route to its deep link (set by the NSE in userInfo), with
  // the item and the login it names. We both invoke the channel (app already
  // running) and stash it for `getInitialDeepLink` (cold launch, before
  // Dart's handler is attached); the stash is consumed at most once, so
  // there's no double navigation.
  //
  // Anything else (an event alarm this app scheduled) belongs to
  // flutter_local_notifications: super hands it to the plugin, which routes
  // its payload and calls the completion handler itself.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let info = response.notification.request.content.userInfo
    guard info["deepLink"] is String else {
      super.userNotificationCenter(
        center, didReceive: response, withCompletionHandler: completionHandler)
      return
    }
    var tap: [String: String] = [:]
    for key in ["deepLink", "itemLink", "brainId", "loginId"] {
      if let value = info[key] as? String { tap[key] = value }
    }
    pendingLaunchDeepLink = tap
    pushChannel?.invokeMethod("deepLink", arguments: tap)
    completionHandler()
  }
}
