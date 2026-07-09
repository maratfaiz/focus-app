import Foundation
import Combine
import FamilyControls

/// Главная модель приложения: правила, авторизация, запуск/остановка блокировок.
@MainActor
final class AppModel: ObservableObject {
    @Published var rules: [BlockRule] = []
    @Published var isAuthorized = false
    @Published var authorizationError: String?

    private let scheduleService = ScheduleService()
    let locationService = LocationService()

    init() {
        rules = RuleStore.loadRules()
        locationService.rulesProvider = { RuleStore.loadRules() }
    }

    // MARK: - Авторизация Screen Time

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = true
        } catch {
            isAuthorized = false
            authorizationError = error.localizedDescription
        }
    }

    // MARK: - CRUD правил

    func add(_ rule: BlockRule) {
        rules.append(rule)
        persistAndRefresh()
    }

    func update(_ rule: BlockRule) {
        guard let i = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[i] = rule
        persistAndRefresh()
    }

    func delete(_ rule: BlockRule) {
        BlockingService.clearShield(for: rule.id)
        scheduleService.stopMonitoring(rule)
        rules.removeAll { $0.id == rule.id }
        persistAndRefresh()
    }

    func toggle(_ rule: BlockRule, enabled: Bool) {
        guard var updated = rules.first(where: { $0.id == rule.id }) else { return }
        updated.isEnabled = enabled
        updated.pausedUntil = nil
        if !enabled {
            BlockingService.clearShield(for: rule.id)
            scheduleService.stopMonitoring(rule)
        }
        update(updated)
    }

    // MARK: - Быстрая блокировка

    /// Активная сессия быстрой блокировки (если есть).
    var activeQuickRule: BlockRule? {
        rules.first {
            if case .quick(let end) = $0.kind {
                return $0.isEnabled && end > Date()
            }
            return false
        }
    }

    func startQuickBlock(name: String,
                         selection: FamilyActivitySelection,
                         domains: [String],
                         duration: TimeInterval,
                         unlock: UnlockMethod) {
        let rule = BlockRule(
            name: name.isEmpty ? "Фокус" : name,
            kind: .quick(endDate: Date().addingTimeInterval(duration)),
            selection: selection,
            blockedDomains: domains,
            unlock: unlock
        )
        rules.append(rule)
        persistAndRefresh()
        BlockingService.applyShield(for: rule)
    }

    /// Завершает быструю блокировку (после прохождения challenge).
    func endQuickBlock(_ rule: BlockRule) {
        BlockingService.clearShield(for: rule.id)
        scheduleService.stopMonitoring(rule)
        rules.removeAll { $0.id == rule.id }
        persistAndRefresh()
    }

    /// Убирает истёкшие быстрые блокировки из списка.
    func cleanupExpiredQuickRules() {
        let expired = rules.filter {
            if case .quick(let end) = $0.kind { return end <= Date() }
            return false
        }
        guard !expired.isEmpty else { return }
        for rule in expired {
            BlockingService.clearShield(for: rule.id)
            scheduleService.stopMonitoring(rule)
        }
        rules.removeAll { rule in expired.contains { $0.id == rule.id } }
        persistAndRefresh()
    }

    // MARK: - Пауза (успешная разблокировка в Strict Mode)

    /// Приостанавливает правило на `minutes` минут: снимает щит и ставит
    /// одноразовую активность, чтобы монитор вернул щит после паузы,
    /// даже если приложение будет закрыто.
    func pause(_ rule: BlockRule, minutes: Int) {
        guard var updated = rules.first(where: { $0.id == rule.id }) else { return }
        updated.pausedUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        rules[rules.firstIndex(where: { $0.id == rule.id })!] = updated
        RuleStore.saveRules(rules)
        BlockingService.clearShield(for: rule.id)
        scheduleService.schedulePauseEnd(for: updated, minutes: minutes)
    }

    /// Полностью отключает правило после прохождения challenge.
    func disableAfterChallenge(_ rule: BlockRule) {
        toggle(rule, enabled: false)
    }

    // MARK: - Общее обновление

    func refreshAll() {
        cleanupExpiredQuickRules()
        scheduleService.refresh(rules: rules)
        locationService.refresh(rules: rules)
        // Правила-расписания, активные прямо сейчас, применяем сразу —
        // intervalDidStart для уже идущего интервала не вызовется.
        for rule in rules where rule.isEnabled && !rule.isPaused {
            if isScheduleActiveNow(rule) || isQuickActiveNow(rule) {
                BlockingService.applyShield(for: rule)
            }
        }
    }

    private func persistAndRefresh() {
        RuleStore.saveRules(rules)
        refreshAll()
    }

    private func isQuickActiveNow(_ rule: BlockRule) -> Bool {
        if case .quick(let end) = rule.kind { return end > Date() }
        return false
    }

    private func isScheduleActiveNow(_ rule: BlockRule, now: Date = Date()) -> Bool {
        guard case .schedule(let days, let start, let end) = rule.kind else { return false }
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: now)
        guard days.contains(weekday) else { return false }
        let minutesNow = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let startM = start.hour * 60 + start.minute
        let endM = end.hour * 60 + end.minute
        if startM <= endM {
            return minutesNow >= startM && minutesNow < endM
        } else {
            // Интервал через полночь.
            return minutesNow >= startM || minutesNow < endM
        }
    }
}
