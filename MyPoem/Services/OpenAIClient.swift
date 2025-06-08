//
//  OpenAIClient.swift
//  MyPoem
//
//  Created by Steven Richter on 5/15/25.
//

import Foundation

/// A simple singleton wrapper around the OpenAI Chat Completions endpoint
@MainActor
final class OpenAIClient {
    static let shared = OpenAIClient()

    private let config: AppConfiguration
    private var apiKey: String
    private let session: URLSession
    private var requestCount = 0
    private let requestQueue = DispatchQueue(label: "com.mypoem.openai", qos: .userInitiated)
    
    
    private init() {
        self.config = DefaultConfiguration()
        self.apiKey = config.openAIAPIKey
        
        // Create a custom session with timeout configuration
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30.0
        sessionConfig.timeoutIntervalForResource = 60.0
        sessionConfig.httpMaximumConnectionsPerHost = 2
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: sessionConfig)
    }

    
//    "You are an award-winning poet and literary artisan with mastery over every form—from haiku to sonnet, free verse to limerick.  Whenever you receive a user’s topic or phrase, you craft a poem that: 1.Fits the requested form (e.g. haiku = 5-7-5 syllables; sonnet = 14 lines with a volta). 2.Conjures vivid imagery and emotional resonance—use concrete details, sensory language, and unexpected metaphors. 3.Honors the user’s tone preference (e.g. playful, solemn, romantic, whimsical). 4.Keeps lines concise and rhythmically balanced, with gentle variations in meter. 5.Never breaks the form’s rules, and always presents the finished poem as a standalone piece. If the user asks for additional constraints (rhyme scheme, maximum length, specific vocabulary), integrate them seamlessly.  Otherwise, default to a tone that is warm, accessible, and engaging for general readers."
  /// Sends a prompt via the chat/completions API and returns the model’s reply.
  func chatCompletion(
    systemPrompt: String = "You are an award-winning poet .",
    userPrompt:   String,
    temperature:  Double? = nil,
    model: String? = nil
  ) async throws -> String {
    // Use configuration values if not overridden
    let actualTemperature = temperature ?? config.openAITemperature
    let actualModel = model ?? config.openAIModel
    
    // 1) Build URL + request
    let url = URL(string: config.openAIEndpoint)!
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")

    // 2) Encode body
    let body = ChatRequest(
        model: actualModel,
      messages: [
        ChatMessage(role: "system", content: systemPrompt),
        ChatMessage(role: "user",   content: userPrompt)
      ],
      temperature: actualTemperature
    
    )
      if config.enableDebugLogging {
          print("REQUEST BODY: \(body)")
      }
    req.httpBody = try JSONEncoder().encode(body)
      if config.enableDebugLogging {
          print("REQUEST BODY: \(req.httpBody!)")
      }

    // 3) Fire it off
    let (data, resp) = try await session.data(for: req)
    
    guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      let msg = String(data: data, encoding: .utf8) ?? "(no body)"
      throw NSError(domain: "OpenAI", code: 1, userInfo: [
        NSLocalizedDescriptionKey: "Bad status code: \((resp as? HTTPURLResponse)?.statusCode ?? -1)\n\(msg)"
      ])
    }

    // 4) Decode the first choice
    let chat = try JSONDecoder().decode(ChatResponse.self, from: data)
    guard let first = chat.choices.first?.message.content else {
        if config.enableDebugLogging {
            print("NO CHOICES IN RESPONSE:", chat.choices)
        }
      throw NSError(domain: "OpenAI", code: 2, userInfo: [
        
        NSLocalizedDescriptionKey: "No choices in response"
      ])
    }
      if config.enableDebugLogging {
          print("RESULT: \(first.trimmingCharacters(in: .whitespacesAndNewlines))")
          print("RESULT: \(chat.choices)")
      }
    // Simple return without any complexity
    let result = first.trimmingCharacters(in: .whitespacesAndNewlines)
    return result
  }
}
