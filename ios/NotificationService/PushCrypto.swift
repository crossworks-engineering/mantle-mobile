import Foundation
import Sodium

/// Reads the device keypair from the shared Keychain and opens a libsodium
/// sealed box (`crypto_box_seal_open`). All values MUST match
/// lib/data/push/push_keys.dart (access group, service, account names) and the
/// keychain-access-groups entitlement on both targets.
enum PushCrypto {
  // $(AppIdentifierPrefix)crossworks.engineering.mantle.pushkeys — prefix is the
  // team id P6NLP32L8H. If the team changes, update this AND the entitlements.
  private static let accessGroup = "P6NLP32L8H.crossworks.engineering.mantle.pushkeys"
  private static let service = "mantle_push" // flutter_secure_storage accountName
  private static let secretKeyAccount = "mantle_push_secret_key"
  private static let publicKeyAccount = "mantle_push_public_key"

  /// Open a base64 sealed box → plaintext bytes, or nil if anything is missing.
  static func openSealed(ciphertextBase64: String) -> Data? {
    guard
      let ct = Data(base64Encoded: ciphertextBase64),
      let skB64 = keychainString(account: secretKeyAccount),
      let pkB64 = keychainString(account: publicKeyAccount),
      let sk = Data(base64Encoded: skB64),
      let pk = Data(base64Encoded: pkB64)
    else { return nil }

    let sodium = Sodium()
    let opened = sodium.box.open(
      anonymousCipherText: [UInt8](ct),
      recipientPublicKey: [UInt8](pk),
      recipientSecretKey: [UInt8](sk)
    )
    return opened.map { Data($0) }
  }

  private static func keychainString(account: String) -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecAttrAccessGroup as String: accessGroup,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
          let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }
}
