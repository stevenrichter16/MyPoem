/// A small, user-selectable temperature list.
struct Temperature: Identifiable, Codable, Hashable {
  let id: String
  let value: Double
  let textDescription: String

  static let all: [Temperature] = [
    .init(id: "med",  value: 1.0, textDescription: "Medium"),
    .init(id: "high", value: 1.3, textDescription: "High"),
    // add/remove more as you like
  ]
}
