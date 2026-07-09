import SwiftUI
import FamilyControls

/// Главный экран: быстрая блокировка одним нажатием.
struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    @State private var selection = FamilyActivitySelection()
    @State private var showPicker = false
    @State private var durationMinutes = 120
    @State private var unlock: UnlockMethod = .wait(seconds: 60)
    @State private var showChallenge = false
    @State private var now = Date()
    @Environment(\.scenePhase) private var scenePhase

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            Group {
                if let active = model.activeQuickRule {
                    activeSessionView(active)
                } else {
                    setupView
                }
            }
            .navigationTitle("Refocus")
            .onReceive(timer) { date in
                now = date
                model.cleanupExpiredQuickRules()
            }
            .onAppear { consumeUnlockRequest() }
            .onChange(of: scenePhase) { phase in
                if phase == .active { consumeUnlockRequest() }
            }
        }
    }

    // MARK: - Активная сессия

    @ViewBuilder
    private func activeSessionView(_ rule: BlockRule) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)

            Text(rule.name)
                .font(.title.bold())

            if case .quick(let endDate) = rule.kind {
                Text(remainingString(until: endDate))
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("до \(endDate.formatted(date: .omitted, time: .shortened))")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                showChallenge = true
            } label: {
                Label(unlockButtonTitle(rule), systemImage: "lock.open")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showChallenge) {
            UnlockChallengeView(rule: rule) {
                model.endQuickBlock(rule)
            }
        }
    }

    /// Пользователь нажал «Разблокировать в Refocus» на экране-щите:
    /// расширение поставило флаг в App Group — открываем challenge.
    private func consumeUnlockRequest() {
        let key = SharedConstants.unlockRequestKey
        let timestamp = SharedConstants.defaults.double(forKey: key)
        guard timestamp > 0 else { return }
        SharedConstants.defaults.removeObject(forKey: key)
        // Запрос актуален пять минут; challenge показываем для активной сессии.
        if Date().timeIntervalSince1970 - timestamp < 300, model.activeQuickRule != nil {
            showChallenge = true
        }
    }

    private func unlockButtonTitle(_ rule: BlockRule) -> String {
        if case .none = rule.unlock { return "Завершить" }
        return "Разблокировать (\(rule.unlock.title))"
    }

    private func remainingString(until end: Date) -> String {
        let remaining = max(0, Int(end.timeIntervalSince(now)))
        let h = remaining / 3600, m = (remaining % 3600) / 60, s = remaining % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    // MARK: - Настройка новой сессии

    private var setupView: some View {
        Form {
            Section("Что блокировать") {
                Button {
                    showPicker = true
                } label: {
                    HStack {
                        Label("Приложения и сайты", systemImage: "square.grid.2x2")
                        Spacer()
                        Text(selectionSummary)
                            .foregroundStyle(.secondary)
                    }
                }
                .familyActivityPicker(isPresented: $showPicker, selection: $selection)
            }

            Section("Длительность") {
                Picker("Длительность", selection: $durationMinutes) {
                    Text("25 минут").tag(25)
                    Text("1 час").tag(60)
                    Text("2 часа").tag(120)
                    Text("4 часа").tag(240)
                    Text("8 часов").tag(480)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section("Strict Mode — как разблокировать досрочно") {
                UnlockMethodPicker(unlock: $unlock)
            }

            Section {
                Button {
                    model.startQuickBlock(
                        name: "Фокус",
                        selection: selection,
                        domains: [],
                        duration: TimeInterval(durationMinutes * 60),
                        unlock: unlock
                    )
                } label: {
                    Label("Начать фокус", systemImage: "bolt.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .disabled(selectionIsEmpty)
            } footer: {
                if selectionIsEmpty {
                    Text("Сначала выберите хотя бы одно приложение или категорию.")
                }
            }
        }
    }

    private var selectionIsEmpty: Bool {
        selection.applicationTokens.isEmpty
            && selection.categoryTokens.isEmpty
            && selection.webDomainTokens.isEmpty
    }

    private var selectionSummary: String {
        if selectionIsEmpty { return "Выбрать" }
        var parts: [String] = []
        if !selection.applicationTokens.isEmpty { parts.append("прил.: \(selection.applicationTokens.count)") }
        if !selection.categoryTokens.isEmpty { parts.append("катег.: \(selection.categoryTokens.count)") }
        if !selection.webDomainTokens.isEmpty { parts.append("сайты: \(selection.webDomainTokens.count)") }
        return parts.joined(separator: ", ")
    }
}
