import SwiftUI

/// Отображение сводки экранного времени: итог, динамика по дням,
/// топ приложений.
struct TotalActivityView: View {
    let summary: ActivitySummary

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Text("Экранное время")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(format(summary.totalDuration))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            if summary.dailyTotals.count > 1 {
                Section("По дням") {
                    dailyChart
                        .frame(height: 120)
                        .padding(.vertical, 8)
                }
            }

            Section("Топ приложений") {
                if summary.topApps.isEmpty {
                    Text("Нет данных за выбранный период")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(summary.topApps) { app in
                        HStack {
                            Text(app.name)
                            Spacer()
                            Text(format(app.duration))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    /// Простая столбчатая диаграмма без сторонних зависимостей.
    private var dailyChart: some View {
        let maxDuration = max(summary.dailyTotals.map(\.duration).max() ?? 1, 1)
        return HStack(alignment: .bottom, spacing: 4) {
            ForEach(summary.dailyTotals, id: \.day) { item in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentColor.gradient)
                        .frame(height: max(4, 90 * item.duration / maxDuration))
                    Text(item.day, format: .dateTime.day())
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func format(_ duration: TimeInterval) -> String {
        let total = Int(duration)
        let h = total / 3600, m = (total % 3600) / 60
        return h > 0 ? "\(h) ч \(m) мин" : "\(m) мин"
    }
}
