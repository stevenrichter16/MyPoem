//
//  RequestResponseCardViewModel.swift
//  MyPoem
//
//  Created by Steven Richter on 5/15/25.
//

import SwiftUI
import Combine

final class RequestResponseCardViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var displayedText = ""
    private let requestStore: RequestStoring
    private let responseStore: ResponseStoring
    private let request: Request
    private var response: Response?

    init(request: Request, requestStore: RequestStoring, responseStore: ResponseStoring) {
        self.request = request
        self.requestStore = requestStore
        self.responseStore = responseStore
      
        
        
        do {
            if let resp = try requestStore.fetchResponse(requestId: request.id) {
                self.response = resp
                
                if resp.hasAnimated {
                    isLoading = false
                    displayedText = resp.content
                    return
                }
                isLoading = false
                loadAndType()
            } else {
                isLoading = true
                return
            }
        } catch {
            isLoading = false
            displayedText = "Error fetching"
            return
        }
        
//        guard let resp = try? requestStore.fetchResponse(requestId: request.id) else {
//          isLoading = false
//          displayedText = "Error fetching"
//          return
//        }
//
//        // If we’ve already animated this one, just show it immediately:
//        if resp.hasAnimated {
//            isLoading      = false
//            displayedText  = resp.content
//        } else {
//            // Otherwise, go animate
//            loadAndType()
//        }
    }
    public func triggerAnimation(response: Response) {
        self.response = response
        loadAndType()
    }

  private func loadAndType() {
    guard let responseText = response?.content else { return }
    DispatchQueue.global(qos: .userInitiated).async {

      DispatchQueue.main.async {
        self.isLoading = false
        self.typeOutByWords(responseText)
       
          
      }
    }
  }

    private func typeOutByWords(_ text: String) {
        let words = text.split(separator: " ").map(String.init)
        var delay: Double = 0

        for (i, word) in words.enumerated() {
          DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.displayedText += (self.displayedText.isEmpty ? "" : " ") + word

            // 4) If this is the *last* word, mark the response as “seen”:
            if i == words.count - 1 {
              self.markAnimated()
            }
          }
          delay += 0.05
        }
      }

      private func markAnimated() {
        guard var resp = response else { return }

        // Avoid double-writes
        guard !resp.hasAnimated else { return }

        resp.hasAnimated = true
        do {
          try responseStore.save(resp)
        } catch {
          print("Failed to save hasAnimated flag:", error)
        }
      }
}
