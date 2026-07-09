import DeviceActivity
import SwiftUI

/// Сводка активности за период.
struct ActivitySummary {
    struct AppUsage: Identifiable {
        let id = UUID()
        let name: String
        let duration: TimeInterval
    }

    var totalDuration: TimeInterval = 0
    /// Суммарное время по дням (для динамики).
    var dailyTotals: [(day: Date, duration: TimeInterval)] = []
    /// Самые используемые приложения.
    var topApps: [AppUsage] = []
}

struct TotalActivityReport: DeviceActivityReportScene {
    // Контекст должен совпадать с DeviceActivityReport.Context в приложении.
    let context: DeviceActivityReport.Context = .init("Total Activity")
    let content: (ActivitySummary) -> TotalActivityView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> ActivitySummary {
        var summary = ActivitySummary()
        var appDurations: [String: TimeInterval] = [:]
        var dayDurations: [Date: TimeInterval] = [:]

        for await segment in data.flatMap({ $0.activitySegments }) {
            summary.totalDuration += segment.totalActivityDuration
            let day = Calendar.current.startOfDay(for: segment.dateInterval.start)
            dayDurations[day, default: 0] += segment.totalActivityDuration

            for await category in segment.categories {
                for await app in category.applications {
                    let name = app.application.localizedDisplayName
                        ?? app.application.bundleIdentifier
                        ?? "Другое"
                    appDurations[name, default: 0] += app.totalActivityDuration
                }
            }
        }

        summary.dailyTotals = dayDurations
            .map { (day: $0.key, duration: $0.value) }
            .sorted { $0.day < $1.day }

        summary.topApps = appDurations
            .map { ActivitySummary.AppUsage(name: $0.key, duration: $0.value) }
            .sorted { $0.duration > $1.duration }
            .prefix(10)
            .map { $0 }

        return summary
    }
}
