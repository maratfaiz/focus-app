import Foundation
import DeviceActivity

/// Регистрация расписаний и лимитов в DeviceActivityCenter.
/// Сами блокировки включает/выключает расширение RefocusMonitor.
final class ScheduleService {
    private let center = DeviceActivityCenter()

    /// Пересоздаёт мониторинг для всех включённых правил.
    func refresh(rules: [BlockRule]) {
        // Останавливаем всё, кроме активных пауз, и регистрируем заново.
        let pauseNames = center.activities.filter { $0.rawValue.hasPrefix(ActivityNames.pausePrefix) }
        let toStop = center.activities.filter { !pauseNames.contains($0) }
        if !toStop.isEmpty {
            center.stopMonitoring(toStop)
        }

        for rule in rules where rule.isEnabled {
            startMonitoring(rule)
        }
    }

    func startMonitoring(_ rule: BlockRule) {
        switch rule.kind {
        case .quick(let endDate):
            startQuickMonitoring(rule, endDate: endDate)
        case .schedule(let days, let start, let end):
            startScheduleMonitoring(rule, days: days, start: start, end: end)
        case .dailyLimit(let minutes):
            startLimitMonitoring(rule, minutes: minutes)
        case .location:
            break // Обрабатывается LocationService.
        }
    }

    func stopMonitoring(_ rule: BlockRule) {
        var names = [ActivityNames.activity(for: rule.id)]
        for day in 1...7 {
            names.append(ActivityNames.activity(for: rule.id, weekday: day))
        }
        center.stopMonitoring(names)
    }

    /// Одноразовая активность: по окончании паузы монитор вернёт щит.
    func schedulePauseEnd(for rule: BlockRule, minutes: Int) {
        let cal = Calendar.current
        let start = Date().addingTimeInterval(30)
        let end = Date().addingTimeInterval(TimeInterval(minutes * 60))
        guard end > start else { return }
        let schedule = DeviceActivitySchedule(
            intervalStart: cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: start),
            intervalEnd: cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: end),
            repeats: false
        )
        try? center.startMonitoring(ActivityNames.pauseActivity(for: rule.id), during: schedule)
    }

    // MARK: - Private

    private func startQuickMonitoring(_ rule: BlockRule, endDate: Date) {
        guard endDate > Date().addingTimeInterval(60) else { return }
        let cal = Calendar.current
        let schedule = DeviceActivitySchedule(
            intervalStart: cal.dateComponents([.year, .month, .day, .hour, .minute], from: Date()),
            intervalEnd: cal.dateComponents([.year, .month, .day, .hour, .minute], from: endDate),
            repeats: false
        )
        try? center.startMonitoring(ActivityNames.activity(for: rule.id), during: schedule)
    }

    private func startScheduleMonitoring(_ rule: BlockRule, days: Set<Int>, start: TimeOfDay, end: TimeOfDay) {
        for day in days {
            var startComponents = start.dateComponents
            startComponents.weekday = day
            var endComponents = end.dateComponents
            // Интервал через полночь: конец попадает на следующий день недели.
            let crossesMidnight = (end.hour * 60 + end.minute) <= (start.hour * 60 + start.minute)
            endComponents.weekday = crossesMidnight ? (day % 7) + 1 : day

            let schedule = DeviceActivitySchedule(
                intervalStart: startComponents,
                intervalEnd: endComponents,
                repeats: true
            )
            try? center.startMonitoring(
                ActivityNames.activity(for: rule.id, weekday: day),
                during: schedule
            )
        }
    }

    private func startLimitMonitoring(_ rule: BlockRule, minutes: Int) {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        let event = DeviceActivityEvent(
            applications: rule.selection.applicationTokens,
            categories: rule.selection.categoryTokens,
            webDomains: rule.selection.webDomainTokens,
            threshold: DateComponents(minute: minutes)
        )
        try? center.startMonitoring(
            ActivityNames.activity(for: rule.id),
            during: schedule,
            events: [ActivityNames.limitEvent: event]
        )
    }
}
