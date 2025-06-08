//
//  OpenAIModels.swift
//  MyPoem
//
//  Created by Steven Richter on 6/7/25.
//

// 2) Encode body
struct ChatMessage: Codable {
  let role: String
  let content: String
}
struct ChatRequest: Codable {
  let model: String
  let messages: [ChatMessage]
  let temperature: Double

}

struct Choice: Codable {
  struct Delta: Codable {
    let content: String?
  }
  let message: Delta
}
struct ChatResponse: Codable {
  let choices: [Choice]
}
