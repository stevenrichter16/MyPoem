//
//  PoemRevision.swift
//  MyPoem
//
//  Created by Steven Richter on 6/1/25.
//


// MyPoem/Models/PoemRevision.swift
import Foundation
import SwiftData

@Model
final class PoemRevision: Identifiable {
    // CloudKit requires all properties to be optional
    @Attribute(.unique) var id: String?
    var requestId: String? // Links to the original request
    var content: String?
    var revisionNumber: Int?
    var createdAt: Date?
    var changeNote: String? // Optional user note about the change
    var wordCount: Int?
    var lineCount: Int?
    var parentRevisionId: String? // For tracking revision chain
    var isCurrentVersion: Bool?
    
    // Change metadata
    var changeType: ChangeType?
    var linesAdded: Int?
    var linesRemoved: Int?
    var linesModified: Int?
    
    // CloudKit sync metadata
    var lastModified: Date?
    var syncStatus: SyncStatus?
    
    init(
        id: String? = UUID().uuidString,
        requestId: String? = nil,
        content: String? = nil,
        revisionNumber: Int? = 1,
        createdAt: Date? = Date(),
        changeNote: String? = nil,
        parentRevisionId: String? = nil,
        isCurrentVersion: Bool? = true
    ) {
        self.id = id
        self.requestId = requestId
        self.content = content
        self.revisionNumber = revisionNumber
        self.createdAt = createdAt
        self.changeNote = changeNote
        self.parentRevisionId = parentRevisionId
        self.isCurrentVersion = isCurrentVersion
        self.lastModified = Date()
        self.syncStatus = .pending
        
        // Calculate word and line counts
        if let content = content {
            self.wordCount = content.split(separator: " ").count
            self.lineCount = content.components(separatedBy: .newlines).count
        }
    }
}

// Change type enum stored as String for CloudKit compatibility
enum ChangeType: String, Codable {
    case initial = "initial"
    case minor = "minor" // Small edits, word changes
    case major = "major" // Structural changes, new stanzas
    case regeneration = "regeneration" // AI regeneration
    case manual = "manual" // User manual edit
}
