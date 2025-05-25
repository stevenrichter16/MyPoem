//
//  ChatViewModel.swift
//  MyPoem
//
//  Created by Steven Richter on 5/15/25.
//

import SwiftData
import Foundation

//@MainActor
//final class ChatViewModel: ObservableObject {
//  private let requestStore: RequestStoring
//  private let responseStore: ResponseStoring
//  private let service: ChatService
//
//  init(context: ModelContext) {
//    self.requestStore  = SwiftDataRequestStore(context: context)
//    self.responseStore = SwiftDataResponseStore(context: context)
//      self.service       = ChatService(requestStore: <#any RequestStoring#>, responseStore: responseStore)
//  }
//
//  /// Call this when the user taps “Send”
//  func send(requestInput: String,
//            poemType: PoemType,
//            temperature: Temperature) async
//  {
//    // 1) Save the empty Request
//    let req = Request(
//      userInput: requestInput,
//      userTopic:    requestInput,
//      poemType:     poemType,
//      temperature:  temperature,
//      createdAt:    Date()
//    )
//    try? requestStore.save(req)
//
//    // 2) Fire off the AI call
//    do {
//        try await service.send(request: req)
//    } catch {
//      print("❌ AI Error:", error)
//      // optionally update a “failed” flag on the req/resp
//    }
//  }
//}
