import Foundation
import Observation
import Security

/// Where a secret (the Giphy API key) is stored. Injectable so the demo harness
/// and tests exercise the migration and read/write logic against an in-memory
/// store instead of the real Keychain.
protocol SecretStore {
    func string(for account: String) -> String?
    /// Stores `value`, or removes the item when `value` is nil.
    func set(_ value: String?, for account: String)
}

/// Reads and writes secrets in the login Keychain as generic-password items. Quip
/// ships outside the App Sandbox (direct distribution), so its own items need no
/// keychain-access-group entitlement.
struct KeychainStore: SecretStore {
    static let shared = KeychainStore()
    private let service = "com.nicojan.Quip"

    func string(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func set(_ value: String?, for account: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        // Delete-then-add keeps the write idempotent whether or not an item exists.
        SecItemDelete(base as CFDictionary)
        guard let value, let data = value.data(using: .utf8) else { return }
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }
}

/// A `SecretStore` held in memory — never touches the Keychain. Used by the demo
/// harness and the tests.
final class InMemorySecretStore: SecretStore {
    private var storage: [String: String]

    init(_ storage: [String: String] = [:]) { self.storage = storage }

    func string(for account: String) -> String? { storage[account] }
    func set(_ value: String?, for account: String) { storage[account] = value }
}

/// App-wide holder for the Giphy API key, shared like `GifLibrary` so the popover
/// and Settings (separate view trees) observe the same value. The key lives in the
/// Keychain, not plaintext `UserDefaults`; a one-time migration moves an existing
/// key over on first launch and drops the plaintext copy.
@MainActor
@Observable
final class Credentials {
    static let shared = Credentials()

    /// The Giphy API key. Read-only to callers; write through `setKey` so every
    /// change persists.
    private(set) var apiKey: String

    @ObservationIgnored private let store: SecretStore
    /// Matches the old `@AppStorage("giphyApiKey")` key, for the migration read.
    static let account = "giphyApiKey"

    init(store: SecretStore = KeychainStore.shared, legacyDefaults: UserDefaults = .standard) {
        self.store = store
        var key = store.string(for: Self.account) ?? ""
        // One-time migration from the pre-Keychain plaintext default: move it into
        // the store, then drop the plaintext copy.
        if key.isEmpty, let legacy = legacyDefaults.string(forKey: Self.account), !legacy.isEmpty {
            key = legacy
            store.set(legacy, for: Self.account)
            legacyDefaults.removeObject(forKey: Self.account)
        }
        apiKey = key
    }

    /// Updates the key and persists it. An empty value clears the stored secret.
    func setKey(_ newValue: String) {
        guard newValue != apiKey else { return }
        apiKey = newValue
        store.set(newValue.isEmpty ? nil : newValue, for: Self.account)
    }
}
