import Foundation
import DeviceActivity

/// Схема имён активностей DeviceActivity, чтобы расширение-монитор
/// могло по имени понять, к какому правилу относится событие.
enum ActivityNames {
    static let rulePrefix = "rule_"
    static let pausePrefix = "pause_"
    static let dayInfix = "_day_"

    /// Имя активности для правила (лимит, быстрая блокировка).
    static func activity(for ruleID: UUID) -> DeviceActivityName {
        DeviceActivityName("\(rulePrefix)\(ruleID.uuidString)")
    }

    /// Имя активности для расписания в конкретный день недели.
    static func activity(for ruleID: UUID, weekday: Int) -> DeviceActivityName {
        DeviceActivityName("\(rulePrefix)\(ruleID.uuidString)\(dayInfix)\(weekday)")
    }

    /// Имя одноразовой активности «пауза правила».
    static func pauseActivity(for ruleID: UUID) -> DeviceActivityName {
        DeviceActivityName("\(pausePrefix)\(ruleID.uuidString)")
    }

    /// Событие достижения дневного лимита.
    static let limitEvent = DeviceActivityEvent.Name("limitReached")

    /// Извлекает UUID правила из имени активности.
    static func ruleID(from name: DeviceActivityName) -> UUID? {
        var raw = name.rawValue
        if raw.hasPrefix(rulePrefix) {
            raw.removeFirst(rulePrefix.count)
        } else if raw.hasPrefix(pausePrefix) {
            raw.removeFirst(pausePrefix.count)
        } else {
            return nil
        }
        if let range = raw.range(of: dayInfix) {
            raw = String(raw[..<range.lowerBound])
        }
        return UUID(uuidString: raw)
    }

    static func isPause(_ name: DeviceActivityName) -> Bool {
        name.rawValue.hasPrefix(pausePrefix)
    }
}
