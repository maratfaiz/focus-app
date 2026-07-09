import Foundation
import ManagedSettings

/// Применение и снятие «щитов» ManagedSettings.
/// Используется и приложением, и расширением DeviceActivityMonitor,
/// поэтому у каждого правила — собственный именованный store.
enum BlockingService {
    static func store(for ruleID: UUID) -> ManagedSettingsStore {
        ManagedSettingsStore(named: ManagedSettingsStore.Name(ruleID.uuidString))
    }

    /// Включает блокировку по правилу (если оно не на паузе).
    static func applyShield(for rule: BlockRule) {
        guard !rule.isPaused else { return }
        let store = store(for: rule.id)

        let apps = rule.selection.applicationTokens
        let categories = rule.selection.categoryTokens
        let webTokens = rule.selection.webDomainTokens

        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        store.shield.webDomains = webTokens.isEmpty ? nil : webTokens

        let manualDomains = Set(
            rule.blockedDomains
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
                .map { WebDomain(domain: $0) }
        )
        store.webContent.blockedByFilter = manualDomains.isEmpty ? nil : .specific(manualDomains)
    }

    /// Полностью снимает блокировку по правилу.
    static func clearShield(for ruleID: UUID) {
        store(for: ruleID).clearAllSettings()
    }

    /// Снимает блокировки всех правил (например, при выключении).
    static func clearAll(rules: [BlockRule]) {
        rules.forEach { clearShield(for: $0.id) }
    }
}
