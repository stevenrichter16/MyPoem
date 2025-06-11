import Foundation
import SwiftData

@Model
final class AudioNote: Identifiable {
    @Attribute(.unique) var id: String?
    var responseId: String? // Links to ResponseEnhanced
    var audioFileName: String? // Unique filename for the audio file
    var duration: TimeInterval?
    var createdAt: Date?
    var transcription: String? // Optional transcription of the audio
    
    // CloudKit sync metadata
    var lastModified: Date?
    var syncStatus: SyncStatus?
    
    init(
        id: String? = UUID().uuidString,
        responseId: String? = nil,
        audioFileName: String? = nil,
        duration: TimeInterval? = nil,
        createdAt: Date? = Date(),
        transcription: String? = nil
    ) {
        self.id = id
        self.responseId = responseId
        self.audioFileName = audioFileName
        self.duration = duration
        self.createdAt = createdAt
        self.transcription = transcription
        self.lastModified = Date()
        self.syncStatus = .pending
    }
    
    // Computed property for the full file URL
    var audioFileURL: URL? {
        guard let fileName = audioFileName else { return nil }
        return AudioNote.documentsDirectory.appendingPathComponent(fileName)
    }
    
    // Static helper for documents directory
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}