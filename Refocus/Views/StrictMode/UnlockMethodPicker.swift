import SwiftUI

/// Выбор способа снятия блокировки (Strict Mode) с настройкой параметров.
struct UnlockMethodPicker: View {
    @Binding var unlock: UnlockMethod

    private enum MethodTag: String, CaseIterable {
        case none, wait, pin, nfc, retype, pomodoro

        var title: String {
            switch self {
            case .none: return "Обычный"
            case .wait: return "Ожидание"
            case .pin: return "PIN-код"
            case .nfc: return "NFC-метка"
            case .retype: return "Перепечатка текста"
            case .pomodoro: return "Pomodoro"
            }
        }
    }

    private var currentTag: MethodTag {
        switch unlock {
        case .none: return .none
        case .wait: return .wait
        case .pin: return .pin
        case .nfc: return .nfc
        case .retype: return .retype
        case .pomodoro: return .pomodoro
        }
    }

    var body: some View {
        Picker("Способ", selection: Binding(
            get: { currentTag },
            set: { setDefault(for: $0) }
        )) {
            ForEach(MethodTag.allCases, id: \.self) { tag in
                Text(tag.title).tag(tag)
            }
        }

        switch unlock {
        case .wait(let seconds):
            Stepper(value: Binding(
                get: { seconds },
                set: { unlock = .wait(seconds: $0) }
            ), in: 10...600, step: 10) {
                Text("Ждать \(seconds) сек")
            }
        case .retype(let sentences):
            Stepper(value: Binding(
                get: { sentences },
                set: { unlock = .retype(sentences: $0) }
            ), in: 1...10) {
                Text("Предложений: \(sentences)")
            }
        case .pomodoro(let opens, let session, let cooldown):
            Stepper(value: Binding(
                get: { opens },
                set: { unlock = .pomodoro(maxOpens: $0, sessionMinutes: session, cooldownMinutes: cooldown) }
            ), in: 1...20) {
                Text("Открытий в день: \(opens)")
            }
            Stepper(value: Binding(
                get: { session },
                set: { unlock = .pomodoro(maxOpens: opens, sessionMinutes: $0, cooldownMinutes: cooldown) }
            ), in: 5...60, step: 5) {
                Text("Сессия: \(session) мин")
            }
            Stepper(value: Binding(
                get: { cooldown },
                set: { unlock = .pomodoro(maxOpens: opens, sessionMinutes: session, cooldownMinutes: $0) }
            ), in: 1...60) {
                Text("Перерыв: \(cooldown) мин")
            }
        case .pin:
            if RuleStore.pin == nil {
                Label("Сначала задайте PIN в Настройках", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        case .nfc:
            if RuleStore.nfcTagPayload == nil {
                Label("Сначала зарегистрируйте метку в Настройках", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        case .none:
            EmptyView()
        }
    }

    private func setDefault(for tag: MethodTag) {
        switch tag {
        case .none: unlock = .none
        case .wait: unlock = .wait(seconds: 60)
        case .pin: unlock = .pin
        case .nfc: unlock = .nfc
        case .retype: unlock = .retype(sentences: 3)
        case .pomodoro: unlock = .pomodoro(maxOpens: 5, sessionMinutes: 25, cooldownMinutes: 5)
        }
    }
}
