import SwiftUI
import Speech
import Observation

@Observable
@MainActor
class PoemSpeechTranscriber {
    // MARK: - Observable Properties
    var isTranscribing = false
    var transcriptionText: String = ""
    var transcriptionError: String?
    
    // MARK: - Private Properties
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // MARK: - Dependencies
    private let dataManager: DataManager
    
    // MARK: - Initialization
    init(dataManager: DataManager) {
        self.dataManager = dataManager
    }
    
    // MARK: - Transcription Functions
    func transcribeAudio(from url: URL, for audioNote: AudioNote) async {
        // Request speech recognition permission
        let authStatus = await requestSpeechAuthorization()
        guard authStatus == .authorized else {
            self.transcriptionError = "Speech recognition permission denied"
            return
        }
        
        self.isTranscribing = true
        self.transcriptionError = nil
        self.transcriptionText = ""
        
        let recognizer = SFSpeechRecognizer(locale: Locale.current)
        guard let recognizer = recognizer, recognizer.isAvailable else {
            self.isTranscribing = false
            self.transcriptionError = "Speech recognition not available"
            return
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = true
        
        await withCheckedContinuation { continuation in
            var hasResumed = false
            
            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                
                if let result = result {
                    Task { @MainActor in
                        self.transcriptionText = result.bestTranscription.formattedString
                        
                        if result.isFinal {
                            self.isTranscribing = false
                            
                            if !hasResumed {
                                hasResumed = true
                                continuation.resume()
                            }
                            
                            // Save transcription
                            Task {
                                await self.saveTranscription(result.bestTranscription.formattedString, for: audioNote)
                            }
                        }
                    }
                }
                
                if let error = error {
                    Task { @MainActor in
                        self.isTranscribing = false
                        self.transcriptionError = error.localizedDescription
                    }
                    
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume()
                    }
                }
            }
        }
    }
    
    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    private func saveTranscription(_ transcription: String, for audioNote: AudioNote) async {
        do {
            audioNote.transcription = transcription
            audioNote.lastModified = Date()
            audioNote.syncStatus = .pending
            
            try await dataManager.updateAudioNote(audioNote)
        } catch {
            print("Failed to save transcription: \(error)")
        }
    }
    
    func clearTranscription() {
        transcriptionText = ""
        transcriptionError = nil
    }
}