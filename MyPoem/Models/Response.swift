import Foundation
import SwiftData

@Model
final class ResponseEnhanced: Identifiable {
    @Attribute(.unique) var id: String?
    var requestId: String?
    var userId: String?
    var content: String?
    var role: String?
    var isFavorite: Bool?
    var hasAnimated: Bool?
    var dateCreated: Date?
    
    // CloudKit sync metadata
    var lastModified: Date?
    var syncStatus: SyncStatus?
    
    init(
        id: String? = UUID().uuidString,
        requestId: String? = nil,
        userId: String? = nil,
        content: String? = nil,
        role: String? = nil,
        isFavorite: Bool? = false,
        hasAnimated: Bool? = false,
        dateCreated: Date? = Date()
    ) {
        self.id = id
        self.requestId = requestId
        self.userId = userId
        self.content = content
        self.role = role
        self.isFavorite = isFavorite
        self.hasAnimated = hasAnimated
        self.dateCreated = dateCreated
        self.lastModified = Date()
        self.syncStatus = .pending
    }
}
