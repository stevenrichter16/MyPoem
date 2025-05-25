// ChatServiceKey.swift
import SwiftUI   // <-- must be SwiftUI!

private struct ChatServiceKey: EnvironmentKey {
  // computed var lets you use fatalError() without returning a ChatService
  static var defaultValue: ChatService = {
    fatalError("ChatService not injected into environment")
  }()
}

extension EnvironmentValues {
  var chatService: ChatService {
    get { self[ChatServiceKey.self] }
    set { self[ChatServiceKey.self] = newValue }
  }
}
