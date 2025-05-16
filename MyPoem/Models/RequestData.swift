import Foundation
import SwiftData

@Model
class Request: Identifiable {
    @Attribute(.unique) var id: String
    var userInput: String
    var userTopic: String
    var poemType: PoemType
    var temperature: Temperature
    var createdAt: Date

    init(id: String = UUID().uuidString,
         userInput: String,
         userTopic: String,
         poemType: PoemType,
         temperature: Temperature,
         createdAt: Date = .now) {
        self.id = id
        self.userInput = userInput
        self.userTopic = userTopic
        self.poemType = poemType
        self.temperature = temperature
        self.createdAt = createdAt
    }
}
