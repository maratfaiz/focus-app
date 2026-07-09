import SwiftUI
import FamilyControls

/// Настройки: авторизация Screen Time, PIN, NFC-метка, геолокация.
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var nfc = NFCService()

    @State private var pinInput = ""
    @State private var pinConfirm = ""
    @State private var pinMessage: String?
    @State private var nfcMessage: String?
    @State private var hasPin = RuleStore.pin != nil
    @State private var hasTag = RuleStore.nfcTagPayload != nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Разрешения") {
                    HStack {
                        Label("Screen Time", systemImage: "hourglass")
                        Spacer()
                        if model.isAuthorized {
                            Text("Разрешено").foregroundStyle(.green)
                        } else {
                            Button("Запросить") {
                                Task { await model.requestAuthorization() }
                            }
                        }
                    }
                    Button {
                        model.locationService.requestAuthorization()
                    } label: {
                        Label("Геолокация «Всегда» (для правил по месту)", systemImage: "location")
                    }
                    if let error = model.authorizationError {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                }

                Section {
                    if hasPin {
                        Label("PIN задан", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Button("Сбросить PIN", role: .destructive) {
                            RuleStore.pin = nil
                            hasPin = false
                        }
                    } else {
                        SecureField("Новый PIN (4–8 цифр)", text: $pinInput)
                            .keyboardType(.numberPad)
                        SecureField("Повторите PIN", text: $pinConfirm)
                            .keyboardType(.numberPad)
                        Button("Сохранить PIN") { savePin() }
                            .disabled(pinInput.isEmpty)
                        if let pinMessage {
                            Text(pinMessage).font(.caption).foregroundStyle(.red)
                        }
                    }
                } header: {
                    Text("PIN-код Strict Mode")
                } footer: {
                    Text("Используется правилами со способом разблокировки «PIN-код». Никому его не сообщайте — а лучше попросите записать его того, кому доверяете.")
                }

                Section {
                    if hasTag {
                        Label("Метка зарегистрирована", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Button("Удалить метку", role: .destructive) {
                            RuleStore.nfcTagPayload = nil
                            hasTag = false
                        }
                    } else {
                        Button {
                            registerTag()
                        } label: {
                            Label("Зарегистрировать NFC-метку", systemImage: "wave.3.right")
                        }
                    }
                    if let nfcMessage {
                        Text(nfcMessage).font(.caption).foregroundStyle(.red)
                    }
                } header: {
                    Text("NFC-метка Strict Mode")
                } footer: {
                    Text("Подойдёт любая NFC-наклейка с записанным NDEF-текстом. Оставьте её дома — и вне дома снять блокировку будет невозможно.")
                }

                Section("О приложении") {
                    LabeledContent("Версия", value: "1.0.0")
                    Text("Refocus — блокировщик отвлекающих приложений и сайтов на базе Apple Screen Time API.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Настройки")
        }
    }

    private func savePin() {
        guard pinInput.count >= 4, pinInput.count <= 8, pinInput.allSatisfy(\.isNumber) else {
            pinMessage = "PIN должен состоять из 4–8 цифр."
            return
        }
        guard pinInput == pinConfirm else {
            pinMessage = "PIN-коды не совпадают."
            return
        }
        RuleStore.pin = pinInput
        pinInput = ""
        pinConfirm = ""
        pinMessage = nil
        hasPin = true
    }

    private func registerTag() {
        nfc.scanTag(prompt: "Приложите телефон к метке, которую хотите использовать") { result in
            switch result {
            case .success(let payload):
                RuleStore.nfcTagPayload = payload
                hasTag = true
                nfcMessage = nil
            case .failure(let error):
                nfcMessage = error.localizedDescription
            }
        }
    }
}
