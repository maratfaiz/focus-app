import DeviceActivity
import ManagedSettings
import Foundation

/// Расширение DeviceActivityMonitor: система будит его в начале/конце
/// интервалов расписаний и при достижении лимитов — даже когда
/// основное приложение не запущено.
final class RefocusMonitorExtension: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard let ruleID = ActivityNames.ruleID(from: activity),
              let rule = RuleStore.rule(id: ruleID) else { return }

        if ActivityNames.isPause(activity) {
            // Началась пауза — щит уже снят приложением, ничего не делаем.
            return
        }

        switch rule.kind {
        case .schedule, .quick:
            // Начало окна расписания или быстрой блокировки — включаем щит.
            if rule.isEnabled {
                BlockingService.applyShield(for: rule)
            }
        case .dailyLimit:
            // Новый день — снимаем вчерашний щит, счётчик лимита пошёл заново.
            BlockingService.clearShield(for: ruleID)
        case .location:
            break
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard let ruleID = ActivityNames.ruleID(from: activity) else { return }

        if ActivityNames.isPause(activity) {
            // Пауза закончилась — возвращаем щит, если правило всё ещё активно.
            guard var rule = RuleStore.rule(id: ruleID), rule.isEnabled else { return }
            rule.pausedUntil = nil
            RuleStore.update(rule)
            BlockingService.applyShield(for: rule)
            return
        }

        // Конец окна расписания / быстрой блокировки — снимаем щит.
        BlockingService.clearShield(for: ruleID)
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name,
                                         activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard event == ActivityNames.limitEvent,
              let ruleID = ActivityNames.ruleID(from: activity),
              let rule = RuleStore.rule(id: ruleID),
              rule.isEnabled else { return }
        // Дневной лимит исчерпан — блокируем до конца дня.
        BlockingService.applyShield(for: rule)
    }
}
