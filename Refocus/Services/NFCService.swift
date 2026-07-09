import Foundation
import CoreNFC

/// Чтение NFC-меток (NDEF). Используется для регистрации метки
/// и для проверки при разблокировке.
final class NFCService: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    private var session: NFCNDEFReaderSession?
    private var completion: ((Result<String, Error>) -> Void)?

    enum NFCError: LocalizedError {
        case unavailable
        case emptyTag

        var errorDescription: String? {
            switch self {
            case .unavailable: return "NFC недоступен на этом устройстве."
            case .emptyTag: return "Метка пустая — запишите на неё любой текст."
            }
        }
    }

    /// Сканирует метку и возвращает её полезную нагрузку (payload) как строку.
    func scanTag(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard NFCNDEFReaderSession.readingAvailable else {
            completion(.failure(NFCError.unavailable))
            return
        }
        self.completion = completion
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        session?.alertMessage = prompt
        session?.begin()
    }

    // MARK: - NFCNDEFReaderSessionDelegate

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        let payloads = messages
            .flatMap(\.records)
            .compactMap { record -> String? in
                if let text = record.wellKnownTypeTextPayload().0 { return text }
                if let url = record.wellKnownTypeURIPayload() { return url.absoluteString }
                return String(data: record.payload, encoding: .utf8)
            }
        DispatchQueue.main.async {
            if let first = payloads.first, !first.isEmpty {
                self.completion?(.success(first))
            } else {
                self.completion?(.failure(NFCError.emptyTag))
            }
            self.completion = nil
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            if let completion = self.completion {
                completion(.failure(error))
                self.completion = nil
            }
        }
    }

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {}
}
