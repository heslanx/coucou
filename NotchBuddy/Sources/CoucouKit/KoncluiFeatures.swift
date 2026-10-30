import Foundation

// Koncluí: local feature flags. Every feature (a pill, a page of the window, a Settings block) has an id; its
// value is the user's override ("konclui.feature.<id>" in UserDefaults) or, without one, the default that ships
// inside the app. No network. A flag that is off hides the feature's entry points (PillCatalog.available, the
// window's pages, Settings blocks); its code stays until the feature is deleted for good (KONCLUI.md, "Feature flags").
//
// Lives in CoucouKit, not App: PillCatalog (shared with the iPhone targets) reads it. Foundation only.
enum KoncluiFeatures {
    /// The features that ship off, by id; everything not listed ships on.
    ///
    /// A Swift table rather than a bundled JSON: CoucouKit also builds into the iPhone targets, which carry no
    /// resource bundle for it; the table is compiled in, so it cannot be missing or malformed at run time, and the
    /// swiftc tests read it with no bundle.
    static let shippedOff: Set<String> = [
        "integration_crypto", "integration_calcom", "integration_stripe", "integration_github",
        "integration_vercel", "integration_n8n", "integration_resend", "integration_notion", "integration_portfolio",
        // The updater checks Coucou's releases and verifies Louis's signing team: it cannot install Koncluí (KONCLUI.md).
        "block_updates",
    ]

    /// Features that cannot be turned off: the app needs them (the main workspace pill is VS Code until the user
    /// picks another one).
    static let required: Set<String> = ["integration_claude"]

    static let keyPrefix = "konclui.feature."
    /// Whether the hidden Features screen is shown (⌥-click the wordmark, or `defaults write com.konclui.mac
    /// konclui.features.unlocked -bool YES`).
    static let unlockedKey = "konclui.features.unlocked"
    /// Posted after a flag changes (set, reset).
    static let didChange = Notification.Name("konclui.features.didChange")

    /// Where the overrides live: the app's own preferences. Tests point it at a throwaway suite.
    nonisolated(unsafe) static var store: UserDefaults = .standard

    static func key(_ id: String) -> String { keyPrefix + id }

    /// What ships for this feature: off for `shippedOff`, on for the rest (and for ids nobody knows).
    static func shippedDefault(_ id: String) -> Bool { !shippedOff.contains(id) }

    /// The user's choice for this feature, nil when they never made one.
    static func override(_ id: String) -> Bool? {
        store.object(forKey: key(id)) as? Bool
    }

    static func isOn(_ id: String) -> Bool {
        if required.contains(id) { return true }
        return override(id) ?? shippedDefault(id)
    }

    /// Stores the user's choice (explicit even when it equals the default, so a later change of the shipped
    /// defaults does not move a choice the user made).
    static func set(_ id: String, _ on: Bool) {
        guard !required.contains(id) else { return }
        store.set(on, forKey: key(id))
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    /// Back to what ships, for one feature.
    static func reset(_ id: String) {
        store.removeObject(forKey: key(id))
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    /// Back to what ships, for every feature.
    static func resetAll() {
        for name in store.dictionaryRepresentation().keys where name.hasPrefix(keyPrefix) {
            store.removeObject(forKey: name)
        }
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    static var isUnlocked: Bool {
        get { store.bool(forKey: unlockedKey) }
        set { store.set(newValue, forKey: unlockedKey) }
    }
}
