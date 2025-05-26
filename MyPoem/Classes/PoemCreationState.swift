//
//  PoemCreationState.swift
//  MyPoem
//
//  Manages the state of poem creation notifications across views
//

import SwiftUI
import Combine

class PoemCreationState: ObservableObject {
    @Published var isCreatingPoem: Bool = false
    @Published var createdPoemType: PoemType? = nil
    @Published var showCreationModal: Bool = false
    @Published var creationTopic: String = ""
    
    func startCreatingPoem(type: PoemType, topic: String) {
        isCreatingPoem = true
        createdPoemType = type
        creationTopic = topic
        showCreationModal = true
    }
    
    func finishCreatingPoem() {
        isCreatingPoem = false
        // Keep the modal visible for 3 seconds after creation
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                self.showCreationModal = false
                self.createdPoemType = nil
                self.creationTopic = ""
            }
        }
    }
    
    func cancelCreation() {
        isCreatingPoem = false
        showCreationModal = false
        createdPoemType = nil
        creationTopic = ""
    }
}
