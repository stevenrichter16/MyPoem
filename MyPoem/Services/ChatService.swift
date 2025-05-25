//
//  ChatService.swift
//  MyPoem
//
//  Created by Steven Richter on 5/15/25.
//

import Foundation

import Foundation
import SwiftData

/// Just handles “prompt → API → save”
/// You can keep this in its own file if you like.
final class ChatService: ObservableObject {
    private let context: ModelContext

    /// Create your service with the same ModelContext you injected at the top of your app.
    init(context: ModelContext) {
        self.context = context
    }

  /// Send a Request: it will be saved, then the AI call fired, and the Response saved.
  func send(request: Request) async throws -> Response{
    // build prompt
    let fullPrompt = request.poemType.prompt + request.userInput

    
      // call OpenAI
      let aiText = try await OpenAIClient.shared.chatCompletion(
        userPrompt: fullPrompt,
        temperature: request.temperature.value
      )

      // save the response
      let resp = Response(
        id: UUID().uuidString,
        userId: "me_userid",
        content: aiText,
        role: "bot",
        isFavorite: false,
        request: request,
        hasAnimated: false
      )
      
      print("RESPONSE in ChatService: \(resp.content)")
      return resp
    

    }
}
