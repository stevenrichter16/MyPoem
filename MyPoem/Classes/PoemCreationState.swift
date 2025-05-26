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
    @Published var shouldNavigateToPoemType: PoemType? = nil
    
    private var dismissTimer: Timer?
    
    func startCreatingPoem(type: PoemType, topic: String) {
        isCreatingPoem = true
        createdPoemType = type
        creationTopic = topic
        showCreationModal = true
        // Cancel any existing timer
        dismissTimer?.invalidate()
    }
    
    func finishCreatingPoem() {
        isCreatingPoem = false
        // Keep the modal visible for 5 seconds after creation (longer to allow tap)
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            withAnimation {
                self.hideModal()
            }
        }
    }
    
    func cancelCreation() {
        dismissTimer?.invalidate()
        isCreatingPoem = false
        showCreationModal = false
        createdPoemType = nil
        creationTopic = ""
    }
    
    func hideModal() {
        dismissTimer?.invalidate()
        showCreationModal = false
        createdPoemType = nil
        creationTopic = ""
        shouldNavigateToPoemType = nil
    }
    
    func navigateToPoemType() {
        // Set the navigation trigger
        shouldNavigateToPoemType = createdPoemType
        // Hide modal immediately when tapped
        hideModal()
    }
}
