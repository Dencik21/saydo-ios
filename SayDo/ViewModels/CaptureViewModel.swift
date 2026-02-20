import Foundation
import Combine

@MainActor
final class CaptureViewModel: ObservableObject {

    // MARK: - UI State

    enum Phase: Equatable {
        case idle
        case listening
        case processing
        case review([TaskDraft])
        case error(String)
    }

    @Published private(set) var phase: Phase = .idle

    @Published private(set) var liveTranscript: String = ""
    @Published private(set) var finalTranscript: String = ""

    @Published private(set) var isRecording: Bool = false
    @Published var language: SpeechLanguage = .ru

    // MARK: - Dependencies

    private let speechService = SpeechService()
    private var streamTask: Task<Void, Never>? = nil

    private let beautifier = TextBeautifier()
    private let extractor = TaskExtractor() // extractor.extract(from:) -> [TaskModel]

    // MARK: - Permissions

    func requestPermission() async {
        let ok = await speechService.requestSpeechAuthorization()
        if !ok {
            phase = .error("Нет доступа к распознаванию речи. Проверь разрешения в настройках.")
        }
    }

    // MARK: - Recording

    func start() {
        guard !isRecording else { return }

        // чистим UI
        liveTranscript = ""
        finalTranscript = ""
        phase = .listening

        do {
            speechService.setLocale(language.rawValue)

            let stream = try speechService.startTranscribing()
            isRecording = true

            // ✅ отменяем предыдущий таск, если вдруг остался
            streamTask?.cancel()

            streamTask = Task { [weak self] in
                guard let self else { return }

                var lastText = ""

                do {
                    for try await text in stream {
                        lastText = text
                        self.liveTranscript = text
                    }
                } catch {
                    // если мы остановили запись вручную — это может прилететь как cancel/error,
                    // но мы всё равно попробуем обработать то, что успели получить
                    self.finalTranscript = lastText.isEmpty ? self.liveTranscript : lastText
                    self.isRecording = false
                    await self.processToDraftsAndOpenReview()
                    return
                }

                // Стрим завершился нормально
                self.finalTranscript = lastText
                self.isRecording = false

                await self.processToDraftsAndOpenReview()
            }

        } catch {
            isRecording = false
            phase = .error(error.localizedDescription)
        }
    }

    func stop() {
        guard isRecording else { return }

        // ✅ важно: НЕ cancel streamTask — пусть он сам завершится
        speechService.stop()

        isRecording = false
        // финальный текст доберём из lastText в streamTask, но на всякий случай:
        if finalTranscript.isEmpty {
            finalTranscript = liveTranscript
        }

        // ⚠️ НЕ запускаем processToDraftsAndOpenReview() отсюда,
        // иначе получишь двойной вызов (и двойной review)
    }

    func reset() {
        speechService.stop()
        streamTask?.cancel()
        streamTask = nil

        liveTranscript = ""
        finalTranscript = ""
        isRecording = false

        phase = .idle
    }

    // MARK: - Processing

    private func processToDraftsAndOpenReview() async {
        phase = .processing

        let raw = finalTranscript.isEmpty ? liveTranscript : finalTranscript
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            phase = .error("Пусто 😅 Скажи что-нибудь ещё раз.")
            return
        }

        // ✅ 1) Сначала делим диктовку на части (через beautifier)
        // splitTasks внутри вызывает beautify и потом режет по пунктуации
        let parts = beautifier.splitTasks(trimmed)

        // ✅ 2) Extract для каждой части отдельно — это ключ к нормальному разбиению
        let models: [TaskModel] = parts.flatMap { part in
            extractor.extract(from: part)
        }

        // ✅ 3) В drafts
        let drafts = models
            .map { TaskDraft(title: $0.title, dueDate: $0.dueDate) }
            .map { d in
                // чистим заголовок
                var copy = d
                copy.title = copy.title.trimmingCharacters(in: .whitespacesAndNewlines)
                return copy
            }
            .filter { !$0.title.isEmpty }

        if drafts.isEmpty {
            phase = .error("Не нашёл задач в сообщении 😅 Попробуй сказать чуть конкретнее.")
        } else {
            phase = .review(drafts)
        }
    }

    // MARK: - Review actions

    func cancelReview() {
        reset()
    }

    func deleteDraft(_ draft: TaskDraft) {
        guard case .review(var drafts) = phase else { return }
        drafts.removeAll { $0.id == draft.id }
        phase = drafts.isEmpty ? .idle : .review(drafts)
    }

    func updateDraft(_ draft: TaskDraft) {
        guard case .review(var drafts) = phase else { return }
        guard let idx = drafts.firstIndex(where: { $0.id == draft.id }) else { return }
        drafts[idx] = draft
        phase = .review(drafts)
    }

    /// ✅ Возвращаем SwiftData-модели, готовые к insert
    func confirmedTasks() -> [TaskModel] {
        guard case .review(let drafts) = phase else { return [] }
        return drafts.map { d in
            let m = TaskModel(title: d.title, dueDate: d.dueDate, isDone: false, createdAt: .now)
            m.reminderEnabled = d.reminderEnabled
            m.reminderMinutesBefore = d.reminderMinutesBefore
            m.notificationID = d.reminderEnabled ? (UUID().uuidString) : nil
            return m
        }
    }
}
