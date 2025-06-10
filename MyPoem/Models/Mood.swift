import Foundation

struct Mood: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String
    let icon: String // SF Symbol
    
    static let all: [Mood] = [
        Mood(
            id: "neutral",
            name: "Neutral",
            description: "Balanced, observational tone",
            icon: "minus.circle"
        ),
        Mood(
            id: "joyful",
            name: "Joyful",
            description: "Celebratory, uplifting energy",
            icon: "sun.max"
        ),
        Mood(
            id: "melancholic",
            name: "Melancholic",
            description: "Wistful, reflective sadness",
            icon: "cloud.rain"
        ),
        Mood(
            id: "playful",
            name: "Playful",
            description: "Light, whimsical tone",
            icon: "sparkles"
        ),
        Mood(
            id: "contemplative",
            name: "Contemplative",
            description: "Thoughtful, meditative",
            icon: "brain"
        ),
        Mood(
            id: "passionate",
            name: "Passionate",
            description: "Intense, fervent emotion",
            icon: "flame"
        ),
        Mood(
            id: "mysterious",
            name: "Mysterious",
            description: "Enigmatic, atmospheric",
            icon: "moon.stars"
        ),
        Mood(
            id: "nostalgic",
            name: "Nostalgic",
            description: "Yearning for the past",
            icon: "clock.arrow.circlepath"
        )
    ]
    
    static let defaultMood = all[0] // Neutral
}