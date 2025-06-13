import SwiftUI
import AVFoundation
import Observation

@Observable
@MainActor
class PoemAudioRecorder {
    // MARK: - Observable Properties
    var isRecording = false
    var recordingTime: TimeInterval = 0
    var audioNoteURL: URL?
    
    // MARK: - Private Properties
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    
    // MARK: - Dependencies
    private let response: ResponseEnhanced
    private let dataManager: DataManager
    private let onRecordingComplete: ((URL, AudioNote) -> Void)?
    
    // MARK: - Initialization
    init(response: ResponseEnhanced, dataManager: DataManager, onRecordingComplete: ((URL, AudioNote) -> Void)? = nil) {
        self.response = response
        self.dataManager = dataManager
        self.onRecordingComplete = onRecordingComplete
    }
    
    // MARK: - Recording Functions
    func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            let fileName = "\(response.id ?? UUID().uuidString)_audio.m4a"
            let audioURL = AudioNote.documentsDirectory.appendingPathComponent(fileName)
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.record()
            
            isRecording = true
            recordingTime = 0
            audioNoteURL = audioURL
            
            // Start timer to track recording time
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                self.recordingTime += 1
            }
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Save audio note to database
        if let url = audioNoteURL {
            Task {
                do {
                    let audioNote = try await dataManager.createAudioNote(
                        for: response,
                        audioFileName: url.lastPathComponent,
                        duration: recordingTime
                    )
                    
                    // Notify completion handler
                    onRecordingComplete?(url, audioNote)
                } catch {
                    print("Failed to save audio note: \(error)")
                }
            }
        }
    }
    
    func deleteRecording() async {
        if let url = audioNoteURL {
            try? FileManager.default.removeItem(at: url)
            audioNoteURL = nil
            recordingTime = 0
            
            // Delete from database
            if let audioNote = try? await dataManager.fetchAudioNote(for: response) {
                try? await dataManager.deleteAudioNote(audioNote)
            }
        }
    }
    
    func cleanup() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioRecorder?.stop()
        audioRecorder = nil
    }
}