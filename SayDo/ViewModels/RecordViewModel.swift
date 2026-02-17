//
//  RecordViewModel.swift
//  SayDo
//
//  Created by Denys Ilchenko on 16.02.26.
//

import Foundation
internal import Combine


@MainActor

final class RecordViewModel: ObservableObject {
    
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var errorMessage: String? = nil
    @Published var language: SpeechLanguage = .ru
    
    
    private let speechService = SpeechService()
    private var streamTask: Task<Void,Never>? = nil
    
    private let beautifier = TextBeautifier()
    private let extractor = TaskExtractor()
    
    
    func requestPermission() async {
        let ok = await speechService.requestSpeechAuthorization()
        if !ok {
            errorMessage = "Нет доступа к распознаванию речи. Проверь разрешения в настройках."
        } else {
            errorMessage = nil
        }
        
    }
    
    
    func start() {
        
        errorMessage = nil
        transcript = ""
        
        guard !isRecording else { return }
        
        do {
            speechService.setLocale(language.rawValue)
            let stream = try speechService.startTranscribing()
            isRecording = true
            
            streamTask = Task { [weak self] in
                guard let self else { return }
                do{
                    for try await text in stream {
                        self.transcript = text
                    }
                } catch {
                    self.errorMessage = error.localizedDescription
                }
                self .isRecording = false
            }
            
        } catch {
            errorMessage = error.localizedDescription
            isRecording = false
        }
    }
    
    func stop() {
        speechService.stop()
        streamTask?.cancel()
        streamTask = nil
        isRecording = false
    }
    
    func makeTasks() -> [TaskItem] {
        let pretty = beautifier.beautify(transcript)
        return extractor.extract(from: pretty)
    }
    
}



enum SpeechLanguage: String, CaseIterable, Identifiable {
    case ru = "ru-RU"
    case en = "en-US"
    
    var id : String { rawValue }
    
    var title: String {
        switch self {
        case .ru: return "RU"
        case .en: return "EN"
            
        }
    }
}
