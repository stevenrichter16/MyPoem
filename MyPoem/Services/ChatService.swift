//
//  ChatService.swift
//  MyPoem
//
//  Created by Steven Richter on 5/15/25.
//

import Foundation
import SwiftData

/// Handles "prompt → API → save" using DataManager
final class ChatService: ObservableObject {
    private let dataManager: DataManager

    init(dataManager: DataManager) {
        self.dataManager = dataManager
    }

    /// Send a Request: it will be saved, then the AI call fired, and the Response saved.
    func send(request: RequestEnhanced) async throws -> ResponseEnhanced {
        // Build prompt
        let fullPrompt = request.poemType.prompt + request.userInput

        // Call OpenAI
        let aiText = try await OpenAIClient.shared.chatCompletion(
            userPrompt: fullPrompt,
            temperature: request.temperature.value
        )

        // Create the response
        let response = ResponseEnhanced(
            requestId: request.id,
            userId: "me_userid",
            content: aiText,
            role: "bot",
            isFavorite: false,
            hasAnimated: false
        )
        
        // Save the response and link it to the request
        try await dataManager.save(response: response)
        request.responseId = response.id
        try await dataManager.save(request: request)
        
        print("RESPONSE in ChatService: \(response.content)")
        return response
    }
}
