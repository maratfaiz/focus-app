import SwiftUI

/// Экран прохождения challenge для снятия блокировки.
/// Вызывающая сторона передаёт onSuccess — что сделать после успеха
/// (завершить сессию, выключить правило или поставить на паузу).
struct UnlockChallengeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var nfc = NFCService()

    let rule: BlockRule
    let onSuccess: () -> Void

    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .padding()
                .navigationTitle("Разблокировка")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") { dismiss() }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch rule.unlock {
        case .none:
            SucceedImmediatelyView(succeed: succeed)
        case .wait(let seconds):
            WaitChallengeView(seconds: seconds, succeed: succeed)
        case .pin:
            PinChallengeView(succeed: succeed)
        case .nfc:
            NFCChallengeView(nfc: nfc, succeed: succeed)
        case .retype(let sentences):
            RetypeChallengeView(sentenceCount: sentences, succeed: succeed)
        case .pomodoro(let maxOpens, let sessionMinutes, let cooldownMinutes):
            PomodoroChallengeView(
                rule: rule,
                maxOpens: maxOpens,
                sessionMinutes: sessionMinutes,
                cooldownMinutes: cooldownMinutes
            ) {
                model.pause(rule, minutes: sessionMinutes)
                dismiss()
            }
        }
    }

    private func succeed() {
        onSuccess()
        dismiss()
    }
}

// MARK: - Без ограничений

private struct SucceedImmediatelyView: View {
    let succeed: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Text("Это правило можно выключить сразу.")
            Button("Выключить", action: succeed)
                .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Ожидание

private struct WaitChallengeView: View {
    let seconds: Int
    let succeed: () -> Void

    @State private var remaining: Int = 0
    @Environment(\.scenePhase) private var scenePhase
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "hourglass")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Подождите…")
                .font(.title2.bold())
            Text("Часто за это время желание открыть приложение пропадает. Не закрывайте экран — таймер начнётся заново.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("\(remaining)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
            Spacer()
            Button("Разблокировать") { succeed() }
                .buttonStyle(.borderedProminent)
                .disabled(remaining > 0)
            Spacer()
        }
        .onAppear { remaining = seconds }
        .onReceive(timer) { _ in
            if remaining > 0 { remaining -= 1 }
        }
        .onChange(of: scenePhase) { phase in
            // Ушёл с экрана — начинай сначала.
            if phase != .active { remaining = seconds }
        }
    }
}

// MARK: - PIN

private struct PinChallengeView: View {
    let succeed: () -> Void
    @State private var input = ""
    @State private var error = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "key.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Введите PIN-код")
                .font(.title2.bold())

            if RuleStore.pin == nil {
                Text("PIN не задан. Задайте его в Настройках, либо правило нельзя будет снять этим способом.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.orange)
            } else {
                SecureField("PIN", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 160)

                if error {
                    Text("Неверный PIN")
                        .foregroundStyle(.red)
                }

                Button("Разблокировать") {
                    if input == RuleStore.pin {
                        succeed()
                    } else {
                        error = true
                        input = ""
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(input.isEmpty)
            }
            Spacer()
        }
    }
}

// MARK: - NFC

private struct NFCChallengeView: View {
    @ObservedObject var nfc: NFCService
    let succeed: () -> Void
    @State private var error: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "wave.3.right.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Приложите телефон к вашей NFC-метке")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Если метка дома, а вы нет — блокировку снять не получится. В этом и смысл.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if let error {
                Text(error).foregroundStyle(.red)
            }

            Button {
                scan()
            } label: {
                Label("Сканировать метку", systemImage: "dot.radiowaves.left.and.right")
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    private func scan() {
        guard let registered = RuleStore.nfcTagPayload else {
            error = "Метка не зарегистрирована. Сделайте это в Настройках."
            return
        }
        nfc.scanTag(prompt: "Приложите телефон к метке Refocus") { result in
            switch result {
            case .success(let payload) where payload == registered:
                succeed()
            case .success:
                error = "Это не та метка."
            case .failure(let err):
                error = err.localizedDescription
            }
        }
    }
}

// MARK: - Перепечатка текста

private struct RetypeChallengeView: View {
    let sentenceCount: Int
    let succeed: () -> Void

    @State private var target = ""
    @State private var input = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Перепечатайте текст без ошибок")
                    .font(.title2.bold())
                Text("Автозамена и вставка не помогут — текст должен совпасть символ в символ.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(target)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .textSelection(.disabled)

                TextEditor(text: $input)
                    .frame(minHeight: 120)
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(matches ? Color.green : Color(.systemGray4))
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button("Разблокировать") { succeed() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(!matches)
            }
            .padding(.top)
        }
        .onAppear { target = RetypeTextGenerator.text(sentences: sentenceCount) }
    }

    private var matches: Bool {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
            == target.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Pomodoro

private struct PomodoroChallengeView: View {
    let rule: BlockRule
    let maxOpens: Int
    let sessionMinutes: Int
    let cooldownMinutes: Int
    let startSession: () -> Void

    @State private var state = PomodoroState()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "timer")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Pomodoro-разблокировка")
                .font(.title2.bold())

            Text("Использовано сегодня: \(state.opensUsed) из \(maxOpens)")
                .font(.headline)

            if let reason = blockReason {
                Text(reason)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.orange)
            } else {
                Text("Сессия длится \(sessionMinutes) мин, затем блокировка вернётся автоматически.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Button("Начать сессию \(sessionMinutes) мин") {
                var s = state
                s.rollOverIfNeeded()
                s.opensUsed += 1
                s.currentSessionEnd = Date().addingTimeInterval(TimeInterval(sessionMinutes * 60))
                s.lastSessionEnd = s.currentSessionEnd
                RuleStore.savePomodoroState(s, for: rule.id)
                startSession()
            }
            .buttonStyle(.borderedProminent)
            .disabled(blockReason != nil)
            Spacer()
        }
        .onAppear {
            var s = RuleStore.pomodoroState(for: rule.id)
            s.rollOverIfNeeded()
            state = s
        }
    }

    private var blockReason: String? {
        if state.opensUsed >= maxOpens {
            return "Лимит открытий на сегодня исчерпан. Попробуйте завтра."
        }
        if let last = state.lastSessionEnd {
            let readyAt = last.addingTimeInterval(TimeInterval(cooldownMinutes * 60))
            if readyAt > Date() {
                return "Перерыв: следующая сессия доступна в \(readyAt.formatted(date: .omitted, time: .shortened))."
            }
        }
        return nil
    }
}
