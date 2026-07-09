import Foundation

/// Чтение и запись правил в App Group — доступно и приложению, и расширениям.
enum RuleStore {
    static func loadRules() -> [BlockRule] {
        guard let data = SharedConstants.defaults.data(forKey: SharedConstants.rulesKey) else {
            return []
        }
        return (try? JSONDecoder().decode([BlockRule].self, from: data)) ?? []
    }

    static func saveRules(_ rules: [BlockRule]) {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        SharedConstants.defaults.set(data, forKey: SharedConstants.rulesKey)
    }

    static func rule(id: UUID) -> BlockRule? {
        loadRules().first { $0.id == id }
    }

    static func update(_ rule: BlockRule) {
        var rules = loadRules()
        if let i = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[i] = rule
        } else {
            rules.append(rule)
        }
        saveRules(rules)
    }

    // MARK: - Pomodoro

    static func pomodoroState(for ruleID: UUID) -> PomodoroState {
        let key = "\(SharedConstants.pomodoroStateKey).\(ruleID.uuidString)"
        guard let data = SharedConstants.defaults.data(forKey: key),
              let state = try? JSONDecoder().decode(PomodoroState.self, from: data) else {
            return PomodoroState()
        }
        return state
    }

    static func savePomodoroState(_ state: PomodoroState, for ruleID: UUID) {
        let key = "\(SharedConstants.pomodoroStateKey).\(ruleID.uuidString)"
        if let data = try? JSONEncoder().encode(state) {
            SharedConstants.defaults.set(data, forKey: key)
        }
    }

    // MARK: - Strict Mode secrets

    static var pin: String? {
        get { SharedConstants.defaults.string(forKey: SharedConstants.pinKey) }
        set { SharedConstants.defaults.set(newValue, forKey: SharedConstants.pinKey) }
    }

    static var nfcTagPayload: String? {
        get { SharedConstants.defaults.string(forKey: SharedConstants.nfcTagKey) }
        set { SharedConstants.defaults.set(newValue, forKey: SharedConstants.nfcTagKey) }
    }
}
