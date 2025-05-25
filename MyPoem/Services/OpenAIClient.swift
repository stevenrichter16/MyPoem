//
//  OpenAIClient.swift
//  MyPoem
//
//  Created by Steven Richter on 5/15/25.
//

import Foundation

/// A simple singleton wrapper around the OpenAI Chat Completions endpoint
actor OpenAIClient {
  static let shared = OpenAIClient()

    private var apiKey: String

    private init() { // Make init private for singleton
        // Load the API key from Secrets.plist
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let nsDictionary = NSDictionary(contentsOfFile: path),
              let key = nsDictionary["OPENAI_API_KEY"] as? String else {
            fatalError("Missing or invalid OPENAI_API_KEY in Secrets.plist. Please create Secrets.plist (from Secrets.plist.example) and add your key.")
        }
        
        if key.isEmpty || key == "YOUR_API_KEY_GOES_HERE" {
             fatalError("OPENAI_API_KEY is empty or placeholder in Secrets.plist. Please add your actual key.")
        }
        
        self.apiKey = key
    }

    
//    "You are an award-winning poet and literary artisan with mastery over every form—from haiku to sonnet, free verse to limerick.  Whenever you receive a user’s topic or phrase, you craft a poem that: 1.Fits the requested form (e.g. haiku = 5-7-5 syllables; sonnet = 14 lines with a volta). 2.Conjures vivid imagery and emotional resonance—use concrete details, sensory language, and unexpected metaphors. 3.Honors the user’s tone preference (e.g. playful, solemn, romantic, whimsical). 4.Keeps lines concise and rhythmically balanced, with gentle variations in meter. 5.Never breaks the form’s rules, and always presents the finished poem as a standalone piece. If the user asks for additional constraints (rhyme scheme, maximum length, specific vocabulary), integrate them seamlessly.  Otherwise, default to a tone that is warm, accessible, and engaging for general readers."
  /// Sends a prompt via the chat/completions API and returns the model’s reply.
  func chatCompletion(
    systemPrompt: String = "You are an award-winning poet .",
    userPrompt:   String,
    temperature:  Double = 1.0,
    model: String = "gpt-4"
  ) async throws -> String {
    // 1) Build URL + request
    let url = URL(string: "https://api.openai.com/v1/chat/completions")!
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")

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
    let body = ChatRequest(
        model: model,
      messages: [
        ChatMessage(role: "system", content: systemPrompt),
        ChatMessage(role: "user",   content: userPrompt)
      ],
      temperature: temperature
    
    )
      print("REQUEST BODY: \(body)")
    req.httpBody = try JSONEncoder().encode(body)
      print("REQUEST BODY: \(req.httpBody!)")

    // 3) Fire it off
    let (data, resp) = try await URLSession.shared.data(for: req)
    guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      let msg = String(data: data, encoding: .utf8) ?? "(no body)"
      throw NSError(domain: "OpenAI", code: 1, userInfo: [
        NSLocalizedDescriptionKey: "Bad status code: \((resp as? HTTPURLResponse)?.statusCode ?? -1)\n\(msg)"
      ])
    }

    // 4) Decode the first choice
    struct Choice: Codable {
      struct Delta: Codable {
        let content: String?
      }
      let message: Delta
    }
    struct ChatResponse: Codable {
      let choices: [Choice]
    }
    let chat = try JSONDecoder().decode(ChatResponse.self, from: data)
    guard let first = chat.choices.first?.message.content else {
        print("NO CHOICES IN RESPONSE:", chat.choices)
      throw NSError(domain: "OpenAI", code: 2, userInfo: [
        
        NSLocalizedDescriptionKey: "No choices in response"
      ])
    }
      print("RESULT: \(first.trimmingCharacters(in: .whitespacesAndNewlines))")
      print("RESULT: \(chat.choices)")
    return first.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
