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
struct ChatService {
  let responseStore: ResponseStoring

  func send(request: Request) async {
    // build prompt
    let fullPrompt = request.poemType.prompt + request.userInput

    do {
      // call OpenAI
      let aiText = try await OpenAIClient.shared.chatCompletion(
        userPrompt: fullPrompt,
        temperature: request.temperature.value
      )

      // save the response
      let resp = Response(
        userId:     "me",
        content:    aiText,
        role:       "assistant",
        isFavorite: false,
        requestId:  request.id
      )
      try responseStore.save(resp)

    } catch {
      print("❌ Chat error:", error)
      // you could save an error-response or set a flag on Request here…
    }
  }
}
