import Foundation
import Security

// Koncluí: what a key save says (docs/konclui/UX.md 1.3 habit 6 and 3, "no silent error"). `Keychain.save` and `KeychainStore.set`
// answer the Keychain's status; a screen that saves a key shows this instead of "Key saved" when the Keychain refused (a locked
// Keychain, an access list that no longer matches after a re-sign). The key still works until Koncluí quits (the store keeps it
// in memory), and the sentence says so.
enum KoncluiKeychainSave {
    static func isStored(_ status: OSStatus) -> Bool { status == errSecSuccess }

    /// The line under a Save button: `saved` when the Keychain stored the key, else what happened, what it means and what to
    /// do. Starts with the red cross the Settings status line looks for.
    static func message(_ status: OSStatus, saved: String) -> String {
        isStored(status) ? saved : "❌ " + String(localized: "konclui.keychain.save-failed")
    }
}
