import DeviceActivity
import SwiftUI

/// Расширение отчётов Screen Time: система передаёт сюда данные
/// активности, а рендер происходит в изолированном процессе.
@main
struct RefocusReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityReport { summary in
            TotalActivityView(summary: summary)
        }
    }
}
