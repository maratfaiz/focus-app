import ManagedSettings
import Foundation

/// Обработчик кнопок на экране-«щите».
/// Открыть другое приложение из щита нельзя — поэтому вторая кнопка
/// лишь помечает запрос на разблокировку: пользователь сам открывает
/// Refocus и проходит challenge (ожидание, PIN, NFC, перепечатка…).
final class ShieldActionExtension: ShieldActionDelegate {

    override func handle(action: ShieldAction,
                         for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handleCommon(action: action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction,
                         for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handleCommon(action: action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction,
                         for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handleCommon(action: action, completionHandler: completionHandler)
    }

    private func handleCommon(action: ShieldAction,
                              completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            completionHandler(.close)
        case .secondaryButtonPressed:
            SharedConstants.defaults.set(Date().timeIntervalSince1970,
                                         forKey: SharedConstants.unlockRequestKey)
            completionHandler(.close)
        @unknown default:
            completionHandler(.none)
        }
    }
}
