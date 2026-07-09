import SwiftUI
import FamilyControls
import CoreLocation

/// Создание и редактирование правила блокировки.
struct RuleEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State var rule: BlockRule
    let isNew: Bool

    @State private var showPicker = false
    @State private var newDomain = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Название") {
                    TextField("Например: Учёба, Работа, Ночь", text: $rule.name)
                }

                Section("Что блокировать") {
                    Button {
                        showPicker = true
                    } label: {
                        HStack {
                            Label("Приложения и категории", systemImage: "square.grid.2x2")
                            Spacer()
                            Text(selectionSummary).foregroundStyle(.secondary)
                        }
                    }
                    .familyActivityPicker(isPresented: $showPicker, selection: $rule.selection)

                    ForEach(rule.blockedDomains, id: \.self) { domain in
                        Label(domain, systemImage: "globe")
                    }
                    .onDelete { rule.blockedDomains.remove(atOffsets: $0) }

                    HStack {
                        TextField("Добавить сайт (youtube.com)", text: $newDomain)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                        Button {
                            addDomain()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newDomain.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                kindSection

                Section("Strict Mode — как снять блокировку") {
                    UnlockMethodPicker(unlock: $rule.unlock)
                }
            }
            .navigationTitle(isNew ? "Новое правило" : "Правило")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        addDomain()
                        if isNew { model.add(rule) } else { model.update(rule) }
                        dismiss()
                    }
                }
            }
        }
    }

    private func addDomain() {
        let domain = newDomain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !domain.isEmpty, !rule.blockedDomains.contains(domain) else { return }
        rule.blockedDomains.append(domain)
        newDomain = ""
    }

    private var selectionSummary: String {
        let count = rule.selection.applicationTokens.count
            + rule.selection.categoryTokens.count
            + rule.selection.webDomainTokens.count
        return count == 0 ? "Выбрать" : "выбрано: \(count)"
    }

    // MARK: - Секция параметров типа правила

    @ViewBuilder
    private var kindSection: some View {
        switch rule.kind {
        case .schedule(let days, let start, let end):
            ScheduleKindEditor(days: days, start: start, end: end) { d, s, e in
                rule.kind = .schedule(days: d, start: s, end: e)
            }
        case .dailyLimit(let minutes):
            Section("Лимит в день") {
                Stepper(value: Binding(
                    get: { minutes },
                    set: { rule.kind = .dailyLimit(minutes: $0) }
                ), in: 5...480, step: 5) {
                    Text("\(minutes) минут")
                }
            }
        case .location(let lat, let lon, let radius, let place):
            LocationKindEditor(latitude: lat, longitude: lon, radius: radius, placeName: place) { la, lo, r, p in
                rule.kind = .location(latitude: la, longitude: lo, radius: r, placeName: p)
            }
        case .quick:
            EmptyView()
        }
    }
}

// MARK: - Расписание

private struct ScheduleKindEditor: View {
    @State var days: Set<Int>
    @State var start: TimeOfDay
    @State var end: TimeOfDay
    let onChange: (Set<Int>, TimeOfDay, TimeOfDay) -> Void

    // Календарные weekday: 1 = воскресенье … 7 = суббота.
    private let weekdays: [(Int, String)] = [
        (2, "Пн"), (3, "Вт"), (4, "Ср"), (5, "Чт"), (6, "Пт"), (7, "Сб"), (1, "Вс"),
    ]

    var body: some View {
        Section("Расписание") {
            HStack(spacing: 6) {
                ForEach(weekdays, id: \.0) { day, label in
                    Button {
                        if days.contains(day) { days.remove(day) } else { days.insert(day) }
                        notify()
                    } label: {
                        Text(label)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(days.contains(day) ? Color.accentColor : Color(.systemGray5))
                            .foregroundStyle(days.contains(day) ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            DatePicker("Начало", selection: timeBinding(get: { start }, set: { start = $0; notify() }), displayedComponents: .hourAndMinute)
            DatePicker("Конец", selection: timeBinding(get: { end }, set: { end = $0; notify() }), displayedComponents: .hourAndMinute)
        }
    }

    private func notify() { onChange(days, start, end) }

    private func timeBinding(get: @escaping () -> TimeOfDay, set: @escaping (TimeOfDay) -> Void) -> Binding<Date> {
        Binding<Date>(
            get: {
                let t = get()
                return Calendar.current.date(from: DateComponents(hour: t.hour, minute: t.minute)) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                set(TimeOfDay(hour: c.hour ?? 0, minute: c.minute ?? 0))
            }
        )
    }
}

// MARK: - Местоположение

private struct LocationKindEditor: View {
    @EnvironmentObject private var model: AppModel
    @State var latitude: Double
    @State var longitude: Double
    @State var radius: Double
    @State var placeName: String
    let onChange: (Double, Double, Double, String) -> Void

    var body: some View {
        Section("Местоположение") {
            TextField("Название места (Дом, Офис, Библиотека)", text: $placeName)
                .onChange(of: placeName) { _ in notify() }

            Button {
                model.locationService.requestCurrentLocation()
            } label: {
                Label("Использовать текущее местоположение", systemImage: "location.fill")
            }
            .onReceive(model.locationService.$lastKnownLocation.compactMap { $0 }) { location in
                latitude = location.coordinate.latitude
                longitude = location.coordinate.longitude
                notify()
            }

            if latitude != 0 || longitude != 0 {
                Text(String(format: "Координаты: %.5f, %.5f", latitude, longitude))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Координаты не заданы")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading) {
                Text("Радиус: \(Int(radius)) м")
                Slider(value: $radius, in: 50...1000, step: 50) { _ in notify() }
            }
        } footer: {
            Text("Правило включится, когда вы окажетесь в этой зоне, и выключится, когда покинете её. Нужно разрешение геолокации «Всегда».")
        }
    }

    private func notify() { onChange(latitude, longitude, radius, placeName) }
}
