import Foundation
import Speech
import AVFoundation

// Ошибки сервиса — чтобы ViewModel могла отличать проблемы
enum SpeechServiceError: Error {
    case recognizerUnavailable
    case alreadyRunning
    case notAuthorized
}

/// Поддерживаемые языки
enum SpeechLanguage: String, CaseIterable, Identifiable {
    case ru = "ru-RU"
    case en = "en-US"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ru: return "RU"
        case .en: return "EN"
        }
    }
}

@MainActor
final class SpeechService: NSObject {

    // MARK: - Core
    private let audioEngine = AVAudioEngine()
    private let audioSession = AVAudioSession.sharedInstance()

    private var speechRecognizer: SFSpeechRecognizer?
    private var localeId: String = SpeechLanguage.ru.rawValue

    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    private var isRunning = false
    private var currentContinuation: AsyncThrowingStream<String, Error>.Continuation?

    override init() {
        super.init()
        setLocale(SpeechLanguage.ru.rawValue)
        setupAudioSessionNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        Task { @MainActor [weak self] in
            self?.stop()
        }
    }

    // MARK: - Public

    func setLocale(_ id: String) {
        localeId = id
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: id))
    }

    func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    cont.resume(returning: status == .authorized)
                }
            }
        }
    }

    /// Запускает распознавание и возвращает поток текста.
    func startTranscribing() throws -> AsyncThrowingStream<String, Error> {
        guard !isRunning else { throw SpeechServiceError.alreadyRunning }
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw SpeechServiceError.recognizerUnavailable
        }

        // Важно: если до этого что-то осталось — чистим
        stop()

        // Создаём request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(iOS 16.0, *) { request.addsPunctuation = true }

        recognitionRequest = request

        // Настраиваем аудио-сессию
        try configureAudioSession()

        // Подключаем tap
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isRunning = true

        // Stream
        return AsyncThrowingStream { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }

            self.currentContinuation = continuation

            self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }

                if let result {
                    continuation.yield(result.bestTranscription.formattedString)

                    // если финал — аккуратно завершаем всё
                    if result.isFinal {
                        self.finishStream()
                    }
                }

                if let error {
                    self.finishStream(throwing: error)
                }
            }

            continuation.onTermination = { [weak self] _ in
                // пользователь перестал слушать — стопаем
                Task { @MainActor in
                    self?.stop()
                }
            }
        }
    }

    /// Остановка: безопасно вызывать сколько угодно раз.
    func stop() {
        // если stream слушают — завершаем без ошибки
        finishStream()

        // tap + engine
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }

        // request/task
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        // audio session
        try? audioSession.setActive(false, options: [.notifyOthersOnDeactivation])

        isRunning = false
    }

    // MARK: - Private helpers

    private func configureAudioSession() throws {
        // .record + .measurement — классика для распознавания
        // .duckOthers — чтобы приглушать музыку/аудио
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
    }

    private func finishStream(throwing error: Error? = nil) {
        guard let cont = currentContinuation else { return }
        currentContinuation = nil

        if let error {
            cont.finish(throwing: error)
        } else {
            cont.finish()
        }
    }

    // MARK: - Interruptions / Route changes

    private func setupAudioSessionNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: audioSession
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: audioSession
        )

        // опционально: если медиа-сервисы “перезапустились” (редко, но бывает)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMediaServicesReset),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: audioSession
        )
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard
            let info = note.userInfo,
            let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: rawType)
        else { return }

        switch type {
        case .began:
            // звонок / Siri — прекращаем запись, иначе подвисает engine
            stop()

        case .ended:
            // Можно попытаться авто-возобновить, но это лучше делать из ViewModel по кнопке.
            // Тут ничего не делаем намеренно.
            break

        @unknown default:
            stop()
        }
    }

    @objc private func handleRouteChange(_ note: Notification) {
        // наушники выдернули/вставили, сменился input — безопаснее остановить
        stop()
    }

    @objc private func handleMediaServicesReset(_ note: Notification) {
        // после reset лучше пересоздать recognizer (иногда он становится nil/недоступен)
        let id = localeId
        setLocale(id)
        stop()
    }
}
