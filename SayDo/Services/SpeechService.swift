//
//  SpeechService.swift
//  SayDo
//
//  SpeechService отвечает за распознавание речи:
//  - запрашивает разрешение
//  - запускает запись микрофона
//  - отдаёт текст распознавания как "поток" (stream) через AsyncThrowingStream
//

import Foundation
import Speech
import AVFoundation

// Ошибки сервиса — чтобы ViewModel могла отличать проблемы
enum SpeechServiceError: Error {
    case recognizerUnavailable          // SFSpeechRecognizer недоступен (например, офлайн/ограничения системы)
    case alreadyRunning                 // уже идёт запись
}

final class SpeechService: NSObject {

    // MARK: - Audio & Speech core

    /// Двигатель аудио: берёт звук с микрофона и отдаёт буферы
    private let audioEngine = AVAudioEngine()

    /// Распознаватель речи (русская локаль)
    private var speechRecognizer: SFSpeechRecognizer?
    private var localeId: String = "ru-RU"

    
    
    /// Активная задача распознавания (чтобы можно было отменять/останавливать)
    private var recognitionTask: SFSpeechRecognitionTask?

    /// Запрос, в который мы "скармливаем" аудио буферы (input для распознавания)
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    // MARK: - Authorization

    /// Запрашиваем разрешение на Speech Recognition.
    /// Возвращаем true, если разрешено.
    func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }
    
    override init() {
        super.init()
        setLocale("ru-RU")
    }

    
    func setLocale(_ id: String) {
        localeId = id
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: id))
    }
    // MARK: - Transcribing (Async stream)

    /// Запускает распознавание и возвращает поток текста.
    ///
    /// Почему stream, а не просто String?
    /// Потому что распознавание выдаёт "частичные результаты" по мере речи.
    ///
    /// Использование (потом в ViewModel):
    /// let stream = try speechService.startTranscribing()
    /// for try await text in stream { ... }
    func startTranscribing() throws -> AsyncThrowingStream<String, Error> {
        // 1) Проверяем доступность распознавания
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechServiceError.recognizerUnavailable
        }

        // 2) Не позволяем стартовать повторно, если уже пишем
        guard !audioEngine.isRunning else {
            throw SpeechServiceError.alreadyRunning
        }

        // 3) Чистим старое распознавание, если осталось
        recognitionTask?.cancel()
        recognitionTask = nil

        // 4) Создаём новый request, куда будут поступать аудиобуферы
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        // 5) Настраиваем аудиосессию (микрофон)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])

        // 6) Подключаемся к микрофону через inputNode и "слушаем" буферы
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0) // на случай, если tap уже стоял

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            // Каждый кусок аудио добавляем в request
            self?.recognitionRequest?.append(buffer)
        }

        // 7) Запускаем аудиодвигатель
        audioEngine.prepare()
        try audioEngine.start()

        // 8) Возвращаем поток текста
        return AsyncThrowingStream { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }

            self.recognitionTask = speechRecognizer.recognitionTask(with: request) { result, error in
                // Пришёл результат — отдаём текст наружу
                if let result {
                    continuation.yield(result.bestTranscription.formattedString)

                    // Если результат финальный — завершаем поток
                    if result.isFinal {
                        continuation.finish()
                    }
                }

                // Пришла ошибка — завершаем поток с ошибкой
                if let error {
                    continuation.finish(throwing: error)
                }
            }

            // Если внешний код прекратил слушать stream — стопаем всё корректно
            continuation.onTermination = { [weak self] _ in
                self?.stop()
            }
        }
    }

    /// Останавливает запись и распознавание, освобождает ресурсы
    func stop() {
        // Останавливаем аудио
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        // Завершаем request
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        // Отменяем задачу распознавания
        recognitionTask?.cancel()
        recognitionTask = nil

        // Деактивируем аудиосессию (не критично, поэтому try?)
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
