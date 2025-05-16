import Foundation
import SwiftData

@Model
class Response {
    @Attribute(.unique) var id: String
    var userId: String
    var content: String
    var role: String
    var isFavorite: Bool
    var requestId: String?
    var dateCreated: Date
    var hasAnimated: Bool = false

    init(id: String = UUID().uuidString,
         userId: String,
         content: String,
         role: String,
         isFavorite: Bool,
         requestId: String? = nil,
         dateCreated: Date = .now) {
        self.id = id
        self.userId = userId
        self.content = content
        self.role = role
        self.isFavorite = isFavorite
        self.requestId = requestId
        self.dateCreated = dateCreated
        self.hasAnimated = hasAnimated
    }
}
