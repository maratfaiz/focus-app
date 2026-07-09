import SwiftUI
import DeviceActivity

/// Экран статистики: отчёт рендерится расширением RefocusReport
/// через DeviceActivityReport (данные Screen Time не покидают систему).
struct StatsView: View {
    private enum Period: String, CaseIterable {
        case day = "День"
        case week = "Неделя"
        case month = "Месяц"

        var interval: DateInterval {
            let cal = Calendar.current
            let now = Date()
            switch self {
            case .day:
                return DateInterval(start: cal.startOfDay(for: now), end: now)
            case .week:
                let start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now)) ?? now
                return DateInterval(start: start, end: now)
            case .month:
                let start = cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: now)) ?? now
                return DateInterval(start: start, end: now)
            }
        }
    }

    @State private var period: Period = .day

    private var filter: DeviceActivityFilter {
        DeviceActivityFilter(
            segment: .daily(during: period.interval),
            users: .all,
            devices: .init([.iPhone])
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Период", selection: $period) {
                    ForEach(Period.allCases, id: \.self) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                DeviceActivityReport(.totalActivity, filter: filter)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Статистика")
        }
    }
}

extension DeviceActivityReport.Context {
    /// Должен совпадать с контекстом сцены в расширении RefocusReport.
    static let totalActivity = Self("Total Activity")
}
