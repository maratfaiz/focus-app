import SwiftUI

/// Список правил блокировки с переключателями.
struct RulesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editorRule: BlockRule?
    @State private var challengeRule: BlockRule?

    private var persistentRules: [BlockRule] {
        model.rules.filter {
            if case .quick = $0.kind { return false }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if persistentRules.isEmpty {
                    ContentUnavailableCompatView()
                }

                ForEach(persistentRules) { rule in
                    RuleRow(rule: rule) { enabled in
                        if !enabled, requiresChallenge(rule) {
                            challengeRule = rule
                        } else {
                            model.toggle(rule, enabled: enabled)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editorRule = rule }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let rule = persistentRules[index]
                        if requiresChallenge(rule), rule.isEnabled {
                            challengeRule = rule
                        } else {
                            model.delete(rule)
                        }
                    }
                }
            }
            .navigationTitle("Правила")
            .toolbar {
                Menu {
                    Button {
                        editorRule = BlockRule(name: "", kind: .schedule(days: [2, 3, 4, 5, 6], start: .morning, end: .afternoon))
                    } label: {
                        Label("Расписание", systemImage: "calendar")
                    }
                    Button {
                        editorRule = BlockRule(name: "", kind: .dailyLimit(minutes: 30))
                    } label: {
                        Label("Дневной лимит", systemImage: "hourglass")
                    }
                    Button {
                        editorRule = BlockRule(name: "", kind: .location(latitude: 0, longitude: 0, radius: 100, placeName: ""))
                    } label: {
                        Label("Местоположение", systemImage: "mappin.and.ellipse")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(item: $editorRule) { rule in
                RuleEditorView(rule: rule, isNew: !model.rules.contains { $0.id == rule.id })
            }
            .sheet(item: $challengeRule) { rule in
                UnlockChallengeView(rule: rule) {
                    model.disableAfterChallenge(rule)
                }
            }
        }
    }

    private func requiresChallenge(_ rule: BlockRule) -> Bool {
        if case .none = rule.unlock { return false }
        return true
    }
}

private struct RuleRow: View {
    let rule: BlockRule
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: rule.iconName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name.isEmpty ? rule.kindTitle : rule.name)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(get: { rule.isEnabled }, set: onToggle))
                .labelsHidden()
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        var parts = [rule.kindTitle]
        switch rule.kind {
        case .schedule(let days, let start, let end):
            parts.append("\(start.formatted)–\(end.formatted), дней: \(days.count)")
        case .dailyLimit(let minutes):
            parts.append("\(minutes) мин/день")
        case .location(_, _, let radius, let place):
            parts.append(place.isEmpty ? "радиус \(Int(radius)) м" : place)
        case .quick:
            break
        }
        if case .none = rule.unlock {} else {
            parts.append("🔒 \(rule.unlock.title)")
        }
        if rule.isPaused { parts.append("на паузе") }
        return parts.joined(separator: " · ")
    }
}

/// Заглушка пустого списка (без ContentUnavailableView, чтобы поддержать iOS 16).
private struct ContentUnavailableCompatView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "shield.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Пока нет правил")
                .font(.headline)
            Text("Добавьте расписание, дневной лимит или блокировку по местоположению кнопкой «+».")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .listRowSeparator(.hidden)
    }
}
