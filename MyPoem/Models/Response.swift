import Foundation
import SwiftData

@Model
class Response {
    @Attribute(.unique) var id: String
    var userId: String
    var content: String
    var role: String
    var isFavorite: Bool
    var hasAnimated: Bool
    var dateCreated: Date
    
    @Relationship var request: Request?

    init(id: String = UUID().uuidString,
         userId: String,
         content: String,
         role: String,
         isFavorite: Bool,
         request: Request,
         hasAnimated:Bool = false,
         dateCreated: Date = .now) {
        self.id = id
        self.userId = userId
        self.content = content
        self.role = role
        self.isFavorite = isFavorite
        self.request = request
        self.dateCreated = dateCreated
        self.hasAnimated = hasAnimated
    }
}
