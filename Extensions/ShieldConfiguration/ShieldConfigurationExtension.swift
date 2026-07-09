import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Внешний вид экрана-«щита», который система показывает поверх
/// заблокированного приложения или сайта.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private func makeConfiguration(title: String) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor.black.withAlphaComponent(0.6),
            icon: UIImage(systemName: "lock.shield.fill"),
            title: .init(text: title, color: .white),
            subtitle: .init(
                text: "Сейчас время фокуса. Вернитесь к делу — это окно закроется, а привычка останется.",
                color: UIColor.white.withAlphaComponent(0.8)
            ),
            primaryButtonLabel: .init(text: "Понятно", color: .black),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: .init(text: "Разблокировать в Refocus", color: UIColor.white.withAlphaComponent(0.8))
        )
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let name = application.localizedDisplayName ?? "Это приложение"
        return makeConfiguration(title: "\(name) заблокировано")
    }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        configuration(shielding: application)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        let name = webDomain.domain ?? "Этот сайт"
        return makeConfiguration(title: "\(name) заблокирован")
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        configuration(shielding: webDomain)
    }
}
