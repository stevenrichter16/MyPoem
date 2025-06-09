import Foundation

/// Represents a stylistic variation of a poem type
struct PoemTypeVariation: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let summary: String
    let prompt: String
    let icon: String // SF Symbol name
    
    init(id: String, name: String, summary: String, prompt: String, icon: String = "sparkles") {
        self.id = id
        self.name = name
        self.summary = summary
        self.prompt = prompt
        self.icon = icon
    }
}
