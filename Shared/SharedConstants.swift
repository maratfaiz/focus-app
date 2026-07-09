import Foundation

/// Константы, общие для основного приложения и всех расширений.
enum SharedConstants {
    /// App Group для обмена данными между приложением и расширениями.
    /// Должен совпадать со значением в entitlements всех таргетов.
    static let appGroupID = "group.com.example.refocus"

    static let rulesKey = "refocus.rules.v1"
    static let pinKey = "refocus.strict.pin"
    static let nfcTagKey = "refocus.strict.nfcTag"
    static let pomodoroStateKey = "refocus.pomodoro.state.v1"
    static let unlockRequestKey = "refocus.shield.unlockRequest"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
}
