import Foundation
import SwiftData

@Model
final class RequestEnhanced: Identifiable {
    // CloudKit requires all properties to be optional
    @Attribute(.unique) var id: String?
    var userInput: String?
    var userTopic: String?
    var poemTypeData: Data? // Store as Data for CloudKit compatibility
    var poemVariationId: String?
    var temperatureData: Data? // Store as Data
    var createdAt: Date?
    
    // ID references
    var responseId: String?
    var poemGroupId: String?
    var parentRequestId: String?
    
    // Metadata
    var isOriginal: Bool?
    var variationNote: String?
    
    // CloudKit sync metadata
    var lastModified: Date?
    var syncStatus: SyncStatus?
    var conflictResolutionStrategy: ConflictStrategy?
    
    // Computed properties for type safety
    var poemType: PoemType? {
        get {
            guard let data = poemTypeData else { return nil }
            return try? JSONDecoder().decode(PoemType.self, from: data)
        }
        set {
            poemTypeData = try? JSONEncoder().encode(newValue)
        }
    }
    
    var temperature: Temperature? {
        get {
            guard let data = temperatureData else { return nil }
            return try? JSONDecoder().decode(Temperature.self, from: data)
        }
        set {
            temperatureData = try? JSONEncoder().encode(newValue)
        }
    }
    
    init(
        id: String? = UUID().uuidString,
        userInput: String? = nil,
        userTopic: String? = nil,
        poemType: PoemType? = nil,
        poemVariationId: String? = nil,
        temperature: Temperature? = nil,
        createdAt: Date? = Date(),
        isOriginal: Bool? = true,
        variationNote: String? = nil,
        parentRequestId: String? = nil
    ) {
        self.id = id
        self.userInput = userInput
        self.userTopic = userTopic
        self.poemType = poemType
        self.poemVariationId = poemVariationId
        self.temperature = temperature
        self.createdAt = createdAt
        self.isOriginal = isOriginal
        self.variationNote = variationNote
        self.parentRequestId = parentRequestId
        self.lastModified = Date()
        self.syncStatus = .pending
    }
}
