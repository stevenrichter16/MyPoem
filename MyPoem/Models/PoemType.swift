import Foundation

/// A size-limited, in-memory list of poem styles.
/// Conforms to Identifiable & Codable so you can still store it on your Request.
struct PoemType: Identifiable, Codable, Hashable {
  let id: String
  let name: String
  let prompt: String
  let maxLength: Int

  /// Your built-in library
  static let all: [PoemType] = [
    .init(id: "haiku",     name: "Haiku",       prompt: "Write a haiku about ",    maxLength: 30),
    .init(id: "freeverse", name: "Free verse",  prompt: "Write a free verse poem about ", maxLength: 100),
    .init(id: "ode",       name: "Ode",         prompt: "Write an ode to ",       maxLength: 100),
    .init(id: "limerick",  name: "Limerick",    prompt: "Write a limerick about ", maxLength: 80),
    .init(id: "ballad",    name: "Ballad",      prompt: "Write a ballad about ",   maxLength: 100),
    .init(id: "sonnet",    name: "Sonnet",      prompt: "Write a sonnet about ",   maxLength: 140),
  ]
}
