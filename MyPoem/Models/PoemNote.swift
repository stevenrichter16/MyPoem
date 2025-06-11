import Foundation
import SwiftData

@Model
final class PoemNote: Identifiable {
    @Attribute(.unique) var id: String?
    var responseId: String? // Links to ResponseEnhanced
    var lineNumber: Int? // nil for overall poem notes, Int for line-specific
    var lineContent: String? // Store line content for reference
    var noteContent: String?
    var colorHex: String? // Color coding for visual organization
    var createdAt: Date?
    var modifiedAt: Date?
    
    // CloudKit sync metadata
    var lastModified: Date?
    var syncStatus: SyncStatus?
    
    init(
        id: String? = UUID().uuidString,
        responseId: String? = nil,
        lineNumber: Int? = nil,
        lineContent: String? = nil,
        noteContent: String? = nil,
        colorHex: String? = "#F5F5F5", // Default neutral gray
        createdAt: Date? = Date()
    ) {
        self.id = id
        self.responseId = responseId
        self.lineNumber = lineNumber
        self.lineContent = lineContent
        self.noteContent = noteContent
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.modifiedAt = createdAt
        self.lastModified = Date()
        self.syncStatus = .pending
    }
}
