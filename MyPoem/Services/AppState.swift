//
//  AppState.swift
//  MyPoem
//
//  Created by Steven Richter on 5/31/25.
//


// AppState.swift - Updated for CloudKit
import SwiftUI
import Observation

@Observable
@MainActor
final class AppState {
    // MARK: - Navigation State
    private(set) var selectedTab: Int = 0
    var browseNavigationPath = NavigationPath()
    
    // MARK: - Filtering State
    private(set) var activeFilter: PoemType? = nil
    
    // MARK: - UI Behavior State
    private(set) var hasPerformedInitialScroll: Bool = false
    private(set) var cardDisplayContext: CardDisplayContext = .create
    
    // MARK: - Poem Creation State
    private(set) var poemCreation: PoemCreationInfo? = nil
    
    // MARK: - CloudKit UI State
    private(set) var showingSyncConflicts: Bool = false
    private(set) var conflictedItems: [(local: Any, remote: Any, recordId: String)] = []
    private(set) var showingCloudKitError: Bool = false
    private(set) var cloudKitErrorMessage: String? = nil
    
    // MARK: - Nested Types
    
    struct PoemCreationInfo: Equatable {
        let id = UUID()
        let type: PoemType
        let topic: String
        var isCreating: Bool = true
        let startedAt = Date()
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    enum CardDisplayContext {
        case create
        case browse
        case favorites
    }
    
    // MARK: - Computed Properties
    
    var isCreatingPoem: Bool {
        poemCreation?.isCreating ?? false
    }
    
    var currentCreationType: PoemType? {
        poemCreation?.type
    }
    
    var hasActiveFilters: Bool {
        activeFilter != nil
    }
    
    var filterDescription: String {
        activeFilter?.name ?? "All Poems"
    }
    
    var shouldShowCreationModal: Bool {
        poemCreation != nil
    }
    
    // MARK: - Navigation Methods
    
    func navigateToTab(_ tab: Int) {
        guard tab != selectedTab else {
            handleTabReselection(tab)
            return
        }
        
        selectedTab = tab
        
        // Update context based on destination
        switch tab {
        case 0:
            cardDisplayContext = .create
        case 1:
            cardDisplayContext = .browse
        case 2:
            cardDisplayContext = .favorites
        default:
            break
        }
        
        print("📍 Navigated to tab \(tab)")
    }
    
    private func handleTabReselection(_ tab: Int) {
        switch tab {
        case 0: // Create - scroll to top (newest poems)
            NotificationCenter.default.post(name: .scrollToTop, object: nil)
        case 1: // Browse - pop to root
            browseNavigationPath = NavigationPath()
        default:
            break
        }
    }
    
    func browsePoems(type: PoemType) {
        withAnimation(.smooth(duration: 0.3)) {
            activeFilter = type
            selectedTab = 1
            browseNavigationPath = NavigationPath()
            cardDisplayContext = .browse
        }
    }
    
    // MARK: - Filtering Methods
    
    func setFilter(_ poemType: PoemType?) {
        withAnimation(.smooth(duration: 0.2)) {
            activeFilter = poemType
        }
        print("🔍 Filter set to: \(poemType?.name ?? "All")")
    }
    
    func resetFilters() {
        withAnimation(.smooth(duration: 0.2)) {
            activeFilter = nil
        }
    }
    
    // MARK: - Poem Creation Methods
    
    func startPoemCreation(type: PoemType, topic: String) {
        // Validate input
        let trimmedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTopic.isEmpty else {
            print("⚠️ Cannot create poem with empty topic")
            return
        }
        
        // Create new session
        poemCreation = PoemCreationInfo(
            type: type,
            topic: trimmedTopic,
            isCreating: true
        )
        
        print("🎭 Started creating \(type.name) about '\(trimmedTopic)'")
    }
    
    func finishPoemCreation() {
        guard var creation = poemCreation else {
            print("⚠️ No active poem creation to finish")
            return
        }
        
        // Update creation state
        creation.isCreating = false
        poemCreation = creation
        
        print("✅ Poem creation finished")
        
        // Post notification to scroll to top in Create tab
        NotificationCenter.default.post(name: .scrollToTopAfterCreation, object: nil)
        
        // Auto-dismiss after delay
        Task {
            try? await Task.sleep(for: .seconds(3))
            
            await MainActor.run {
                if let current = self.poemCreation, current.id == creation.id {
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.poemCreation = nil
                    }
                }
            }
        }
    }
    
    func cancelPoemCreation() {
        guard poemCreation != nil else { return }
        
        withAnimation(.easeOut(duration: 0.2)) {
            poemCreation = nil
        }
        
        print("❌ Poem creation cancelled")
    }
    
    // MARK: - CloudKit UI Methods
    
    func showSyncConflicts(items: [(local: Any, remote: Any, recordId: String)]) {
        conflictedItems = items
        showingSyncConflicts = true
    }
    
    func dismissSyncConflicts() {
        showingSyncConflicts = false
        conflictedItems.removeAll()
    }
    
    func showCloudKitError(_ message: String) {
        cloudKitErrorMessage = message
        showingCloudKitError = true
    }
    
    func dismissCloudKitError() {
        showingCloudKitError = false
        cloudKitErrorMessage = nil
    }
    
    // MARK: - UI State Methods
    
    func markInitialScrollPerformed() {
        hasPerformedInitialScroll = true
    }
    
    func resetUIState(for context: CardDisplayContext) {
        switch context {
        case .create:
            hasPerformedInitialScroll = false
        case .browse:
            browseNavigationPath = NavigationPath()
        case .favorites:
            break
        }
    }
    
    // MARK: - State Coordination Methods
    
    func prepareForLaunch() {
        selectedTab = 0
        cardDisplayContext = .create
        activeFilter = nil
        
        print("🚀 AppState prepared for launch")
    }
    
    func handleAppBecameActive() {
        print("📱 App became active")
    }
    
    // MARK: - Debug Helpers
    
    #if DEBUG
    func resetAllState() {
        selectedTab = 0
        browseNavigationPath = NavigationPath()
        activeFilter = nil
        hasPerformedInitialScroll = false
        cardDisplayContext = .create
        poemCreation = nil
        showingSyncConflicts = false
        conflictedItems.removeAll()
        showingCloudKitError = false
        cloudKitErrorMessage = nil
        
        print("🔄 All state reset")
    }
    
    func mockPoemCreation() {
        startPoemCreation(
            type: PoemType.all.randomElement()!,
            topic: "Test poem topic \(Int.random(in: 1...100))"
        )
    }
    
    func mockSyncConflict() {
        let mockRequest = RequestEnhanced(
            userInput: "Mock conflict",
            poemType: PoemType.all[0],
            temperature: Temperature.all[0]
        )
        
        showSyncConflicts(items: [
            (local: mockRequest, remote: mockRequest, recordId: "mock-id")
        ])
    }
    #endif
}

// MARK: - Notification Names

extension Notification.Name {
    static let scrollToTop = Notification.Name("scrollToTop")
    static let scrollToTopAfterCreation = Notification.Name("scrollToTopAfterCreation")
    static let refreshContent = Notification.Name("refreshContent")
    static let syncCompleted = Notification.Name("syncCompleted")
    static let syncConflictDetected = Notification.Name("syncConflictDetected")
}
