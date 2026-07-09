import Foundation
import FamilyControls

/// Время суток без даты (для расписаний).
struct TimeOfDay: Codable, Hashable {
    var hour: Int
    var minute: Int

    var dateComponents: DateComponents {
        DateComponents(hour: hour, minute: minute)
    }

    var formatted: String {
        String(format: "%02d:%02d", hour, minute)
    }

    static let morning = TimeOfDay(hour: 8, minute: 0)
    static let afternoon = TimeOfDay(hour: 13, minute: 0)
}

/// Способ снятия блокировки (Strict Mode).
enum UnlockMethod: Codable, Hashable {
    /// Обычный режим — выключается одним нажатием.
    case none
    /// Нужно подождать N секунд, глядя на экран ожидания.
    case wait(seconds: Int)
    /// Нужно ввести отдельный PIN-код.
    case pin
    /// Нужно приложить телефон к зарегистрированной NFC-метке.
    case nfc
    /// Нужно без ошибок перепечатать длинный текст (N предложений).
    case retype(sentences: Int)
    /// Pomodoro: не более maxOpens сессий в день по sessionMinutes минут,
    /// с перерывом cooldownMinutes между сессиями.
    case pomodoro(maxOpens: Int, sessionMinutes: Int, cooldownMinutes: Int)

    var title: String {
        switch self {
        case .none: return "Без ограничений"
        case .wait(let s): return "Ожидание \(s) сек"
        case .pin: return "PIN-код"
        case .nfc: return "NFC-метка"
        case .retype(let n): return "Перепечатать текст (\(n) предл.)"
        case .pomodoro(let opens, let session, _):
            return "Pomodoro: \(opens) × \(session) мин"
        }
    }
}

/// Правило блокировки.
struct BlockRule: Codable, Identifiable, Hashable {
    enum Kind: Codable, Hashable {
        /// Быстрая блокировка «сейчас и до endDate».
        case quick(endDate: Date)
        /// Расписание: дни недели (1 = воскресенье … 7 = суббота) и интервал времени.
        case schedule(days: Set<Int>, start: TimeOfDay, end: TimeOfDay)
        /// Дневной лимит использования в минутах.
        case dailyLimit(minutes: Int)
        /// Блокировка по местоположению: внутри круга радиусом radius метров.
        case location(latitude: Double, longitude: Double, radius: Double, placeName: String)
    }

    var id = UUID()
    var name: String
    var isEnabled = true
    var kind: Kind
    /// Выбранные приложения/категории/сайты из FamilyActivityPicker.
    var selection = FamilyActivitySelection()
    /// Домены, введённые вручную (блокируются веб-фильтром).
    var blockedDomains: [String] = []
    /// Способ снятия блокировки.
    var unlock: UnlockMethod = .none
    /// Если правило временно приостановлено (после прохождения challenge).
    var pausedUntil: Date?

    var isPaused: Bool {
        if let until = pausedUntil { return until > Date() }
        return false
    }

    var kindTitle: String {
        switch kind {
        case .quick: return "Быстрая блокировка"
        case .schedule: return "Расписание"
        case .dailyLimit: return "Дневной лимит"
        case .location: return "Местоположение"
        }
    }

    var iconName: String {
        switch kind {
        case .quick: return "bolt.fill"
        case .schedule: return "calendar"
        case .dailyLimit: return "hourglass"
        case .location: return "mappin.and.ellipse"
        }
    }
}

/// Состояние Pomodoro-разблокировок для одного правила (хранится в App Group).
struct PomodoroState: Codable {
    var dayStamp: String = ""
    var opensUsed: Int = 0
    var currentSessionEnd: Date?
    var lastSessionEnd: Date?

    static func todayStamp(_ date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    /// Сбрасывает счётчики, если наступил новый день.
    mutating func rollOverIfNeeded(now: Date = Date()) {
        let stamp = Self.todayStamp(now)
        if dayStamp != stamp {
            dayStamp = stamp
            opensUsed = 0
            currentSessionEnd = nil
            lastSessionEnd = nil
        }
    }
}
