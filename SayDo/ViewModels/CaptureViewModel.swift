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
    private let extractor = TaskExtractor() // теперь extractor выдаёт [TaskModel]

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

        liveTranscript = ""
        finalTranscript = ""
        phase = .listening

        do {
            speechService.setLocale(language.rawValue)

            let stream = try speechService.startTranscribing()
            isRecording = true

            streamTask = Task { [weak self] in
                guard let self else { return }

                var lastText = ""

                do {
                    for try await text in stream {
                        lastText = text
                        self.liveTranscript = text
                    }
                } catch {
                    self.isRecording = false
                    self.phase = .error(error.localizedDescription)
                    return
                }

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

        speechService.stop()
        streamTask?.cancel()
        streamTask = nil

        isRecording = false
        finalTranscript = finalTranscript.isEmpty ? liveTranscript : finalTranscript

        Task { await processToDraftsAndOpenReview() }
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
        let pretty = beautifier.beautify(raw)

        // ✅ extractor теперь возвращает [TaskModel]
        let models = extractor.extract(from: pretty)

        // ✅ конвертим в черновики (удобно редактировать)
        let drafts = models
            .map { TaskDraft(title: $0.title, dueDate: $0.dueDate) }
            .filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

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
            TaskModel(title: d.title, dueDate: d.dueDate, isDone: false, createdAt: .now)
        }
    }
}
