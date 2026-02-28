import Foundation
import Combine
import CoreLocation

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

    // MARK: - Published

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var liveTranscript: String = ""
    @Published private(set) var finalTranscript: String = ""
    @Published private(set) var isRecording: Bool = false
    @Published var language: SpeechLanguage = .ru

    // MARK: - Dependencies

    private let speechService = SpeechService()
    private let beautifier = TextBeautifier()
    private let extractor = TaskExtractor()
    private let locationService = LocationService.shared

    private var streamTask: Task<Void, Never>?

    // MARK: - Permissions

    func requestPermission() async {
        let ok = await speechService.requestSpeechAuthorization()
        guard ok else {
            phase = .error("Нет доступа к распознаванию речи. Проверь разрешения в настройках.")
            return
        }
    }

    // MARK: - Recording

    func start() {
        guard !isRecording else { return }

        resetTranscripts()
        phase = .listening

        do {
            speechService.setLocale(language.rawValue)
            let stream = try speechService.startTranscribing()

            isRecording = true
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
                    // stop/cancel тоже может прийти сюда — всё равно обрабатываем то, что есть
                    self.finalTranscript = self.pickFinalText(lastText: lastText)
                    self.isRecording = false
                    await self.processTranscriptToReview()
                    return
                }

                self.finalTranscript = lastText
                self.isRecording = false
                await self.processTranscriptToReview()
            }

        } catch {
            isRecording = false
            phase = .error(error.localizedDescription)
        }
    }

    func stop() {
        guard isRecording else { return }
        speechService.stop()
        isRecording = false

        // На всякий случай: если финал пустой — оставим live
        if finalTranscript.isEmpty {
            finalTranscript = liveTranscript
        }
    }

    func reset() {
        speechService.stop()
        streamTask?.cancel()
        streamTask = nil

        resetTranscripts()
        isRecording = false
        phase = .idle
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

    // MARK: - Confirm

    func confirmedTasks() -> [TaskModel] {
        guard case .review(let drafts) = phase else { return [] }

        return drafts.map { d in
            let m = TaskModel(
                title: d.title,
                dueDate: d.dueDate,
                isDone: false,
                createdAt: .now
            )

            // reminder
            m.reminderEnabled = d.reminderEnabled
            m.reminderMinutesBefore = d.reminderMinutesBefore
            m.notificationID = d.reminderEnabled ? UUID().uuidString : nil

            // location
            m.address = d.address
            m.locationLat = d.coordinate?.lat
            m.locationLon = d.coordinate?.lon

            return m
        }
    }

    // MARK: - Processing pipeline

    private func processTranscriptToReview() async {
        phase = .processing

        let raw = finalTranscript.isEmpty ? liveTranscript : finalTranscript
        let trimmed = raw.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            phase = .error("Пусто 😅 Скажи что-нибудь ещё раз.")
            return
        }

        // 1) split to chunks
        let parts = beautifier.splitTasks(trimmed)

        // 2) extract drafts (includes address)
        var drafts = parts.flatMap { extractor.extractDrafts(from: $0) }

        // 3) normalize / filter
        drafts = normalizeDrafts(drafts)

        guard !drafts.isEmpty else {
            phase = .error("Не нашёл задач в сообщении 😅 Попробуй сказать чуть конкретнее.")
            return
        }

        // 4) geocode addresses -> coordinates
        drafts = await hydrateLocations(drafts)

        phase = .review(drafts)
    }

    private func normalizeDrafts(_ drafts: [TaskDraft]) -> [TaskDraft] {
        drafts
            .map { d in
                var copy = d
                copy.title = copy.title.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                return copy
            }
            .filter { !$0.title.isEmpty }
    }

    private func hydrateLocations(_ drafts: [TaskDraft]) async -> [TaskDraft] {
        var updated = drafts

        for i in updated.indices {
            guard updated[i].coordinate == nil,
                  let address = updated[i].address?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
                  !address.isEmpty
            else { continue }

            if let coord: CLLocationCoordinate2D = await locationService.geocode(address) {
                updated[i].coordinate = Coordinate(lat: coord.latitude, lon: coord.longitude)
            }
        }

        return updated
    }

    // MARK: - Helpers

    private func resetTranscripts() {
        liveTranscript = ""
        finalTranscript = ""
    }

    private func pickFinalText(lastText: String) -> String {
        if !lastText.isEmpty { return lastText }
        if !liveTranscript.isEmpty { return liveTranscript }
        return ""
    }
}
