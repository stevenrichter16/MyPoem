//
//  TestHarnessView.swift
//  MyPoem
//
//  A simple UI for manually adding, listing, and deleting
//  Requests and Responses in your SwiftData store.
//

import SwiftUI
import SwiftData

//struct TestHarnessView: View {
//    @EnvironmentObject private var dataManager: DataManager
//    @EnvironmentObject private var chatService: ChatService
//    @EnvironmentObject private var poemFilterSettings: PoemFilterSettings
//    @EnvironmentObject private var appUiSettings: AppUiSettings
//    @EnvironmentObject private var poemCreationState: PoemCreationState
//    @EnvironmentObject private var navigationManager: NavigationManager
//
//    @State private var selectedPoemType: PoemType = PoemType.all[0]
//    @State private var selectedTemperature: Temperature = Temperature.all[0]
//    @State private var showingComposer = false
//    @State private var previousRequestCount: Int = 0
//    
//    // Computed property for filtered requests
//    private var filteredRequests: [RequestEnhanced] {
//        if let filter = poemFilterSettings.activeFilter {
//            return dataManager.requests(for: filter)
//        } else {
//            return dataManager.allRequests
//        }
//    }
//
//    var body: some View {
//        ZStack(alignment: .bottomTrailing) {
//            // Clean message history - full screen
//            MessageHistoryView(requests: filteredRequests)
//                .padding(.bottom, 60) // Space for tab bar
//                .environmentObject(poemCreationState)
//                .environmentObject(navigationManager)
//                .environmentObject(poemFilterSettings)
//                .onAppear {
//                    print("Create MessageHistoryView Appear")
//                    appUiSettings.setCardDisplayContext(displayContext: CardDisplayContext.fullInteractive)
//                }
//            
//            // Floating action button - positioned above tab bar
//            Button(action: { showingComposer = true }) {
//                Image(systemName: "plus")
//                    .font(.title2)
//                    .fontWeight(.medium)
//                    .foregroundColor(.white)
//                    .frame(width: 56, height: 56)
//                    .background(
//                        Circle()
//                            .fill(
//                                LinearGradient(
//                                    colors: [Color.blue, Color.blue.opacity(0.8)],
//                                    startPoint: .topLeading,
//                                    endPoint: .bottomTrailing
//                                )
//                            )
//                    )
//                    .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
//            }
//            .padding(.bottom, 100) // 80 (tab bar) + 20 (spacing)
//            .padding(.trailing, 16)
//        }
//        .onAppear {
//            appUiSettings.setCardDisplayContext(displayContext: CardDisplayContext.fullInteractive)
//        }
//        .sheet(isPresented: $showingComposer) {
//            PoemComposerView(
//                selectedPoemType: $selectedPoemType,
//                selectedTemperature: $selectedTemperature,
//                onSubmit: { topic in
//                    sendRequest(topic: topic)
//                    showingComposer = false
//                }
//            )
//        }
//    }
//    
//    private func sendRequest(topic: String) {
//        guard !topic.trimmingCharacters(in: .whitespaces).isEmpty else {
//            return
//        }
//        
//        // Check if the selected poem type is different from the current filter
//        if let currentFilter = poemFilterSettings.activeFilter,
//           selectedPoemType.id != currentFilter.id {
//            print("🔄 Poem type (\(selectedPoemType.name)) differs from filter (\(currentFilter.name)). Resetting filter to 'All'.")
//            poemFilterSettings.resetFilter()
//        }
//        
//        let req = RequestEnhanced(
//            userInput: topic,
//            userTopic: topic,
//            poemType: selectedPoemType,
//            temperature: selectedTemperature
//        )
//        
//        do {
//            try dataManager.save(request: req)
//        } catch {
//            print("Failed to save request: \(error)")
//            return
//        }
//        
//        Task { @MainActor in
//            do {
//                let resp = try await chatService.send(request: req)
//                print("Successfully created and saved response: \(resp.id)")
//            } catch {
//                print("Failed to send or save request/response: \(error)")
//            }
//        }
//    }
//}
