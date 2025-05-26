//
//  TestHarnessView.swift
//  MyPoem
//
//  A simple UI for manually adding, listing, and deleting
//  Requests and Responses in your SwiftData store.
//

import SwiftUI
import SwiftData

struct TestHarnessView: View {
    @EnvironmentObject private var dataManager: DataManager
    @EnvironmentObject private var chatService: ChatService
    @EnvironmentObject private var poemFilterSettings: PoemFilterSettings
    @EnvironmentObject private var appUiSettings: AppUiSettings
    @EnvironmentObject private var poemCreationState: PoemCreationState

    @State private var selectedPoemType: PoemType = PoemType.all[0]
    @State private var selectedTemperature: Temperature = Temperature.all[0]
    @State private var showingComposer = false
    @State private var previousRequestCount: Int = 0
    
    // Computed property for filtered requests
    private var filteredRequests: [RequestEnhanced] {
        if let filter = poemFilterSettings.activeFilter {
            return dataManager.requests(for: filter)
        } else {
            return dataManager.allRequests
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Clean message history - full screen
            MessageHistoryView(requests: filteredRequests)
                .padding(.bottom, 60) // Space for tab bar
                .environmentObject(poemCreationState)
                .onAppear {
                    print("Create MessageHistoryView Appear")
                    appUiSettings.setCardDisplayContext(displayContext: CardDisplayContext.fullInteractive)
                }
            
            // Floating action button - positioned above tab bar
            Button(action: { showingComposer = true }) {
                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.bottom, 100) // 80 (tab bar) + 20 (spacing)
            .padding(.trailing, 16)
        }
        .onAppear {
            appUiSettings.setCardDisplayContext(displayContext: CardDisplayContext.fullInteractive)
        }
        .sheet(isPresented: $showingComposer) {
            PoemComposerView(
                selectedPoemType: $selectedPoemType,
                selectedTemperature: $selectedTemperature,
                onSubmit: { topic in
                    sendRequest(topic: topic)
                    showingComposer = false
                }
            )
        }
    }
    
    private func sendRequest(topic: String) {
        guard !topic.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }
        
        // Check if the selected poem type is different from the current filter
        if let currentFilter = poemFilterSettings.activeFilter,
           selectedPoemType.id != currentFilter.id {
            print("🔄 Poem type (\(selectedPoemType.name)) differs from filter (\(currentFilter.name)). Resetting filter to 'All'.")
            poemFilterSettings.resetFilter()
        }
        
        let req = RequestEnhanced(
            userInput: topic,
            userTopic: topic,
            poemType: selectedPoemType,
            temperature: selectedTemperature
        )
        
        do {
            try dataManager.save(request: req)
        } catch {
            print("Failed to save request: \(error)")
            return
        }
        
        Task { @MainActor in
            do {
                let resp = try await chatService.send(request: req)
                print("Successfully created and saved response: \(resp.id)")
            } catch {
                print("Failed to send or save request/response: \(error)")
            }
        }
    }
}

// MARK: – Preview
#Preview("Test Harness with FAB") {
    let container = try! ModelContainer(
        for: RequestEnhanced.self, ResponseEnhanced.self, PoemGroup.self,
        configurations: ModelConfiguration(
            schema: Schema([RequestEnhanced.self, ResponseEnhanced.self, PoemGroup.self]),
            isStoredInMemoryOnly: true
        )
    )
    let context = container.mainContext
    let dataManager = DataManager(context: context)
    let chatService = ChatService(dataManager: dataManager)
    let appUiSettings = AppUiSettings()
    
    // Create sample data with variety of poem types
    let samples: [(PoemType, String, String)] = [
        (PoemType.all[0], "falling snow", "Snowflakes drift in peace\nBlanketing the world in white\nWinter whispers hush."),
        (PoemType.all[1], "ocean waves at sunset", "The endless ocean calls to me with ancient voices,\nWaves crash against the shore in rhythmic harmony,\nSalt spray dances in the golden evening light,\nAs the sun melts into the horizon's embrace."),
        (PoemType.all[0], "cherry blossoms", "Pink petals flutter,\nSpring's gentle promise unfolds,\nBeauty brief but true."),
        (PoemType.all[2], "mountain sunrise", "Mountain peaks stand tall and proud,\nSilent guardians of the dawn,\nSunlight paints them gold and bright,\nA majestic sight to see."),
        (PoemType.all[0], "quiet forest", "Still trees guard the hush\nSunlight paints the mossy floor\nTime forgets this place."),
        (PoemType.all[1], "starry night", "In the velvet darkness above us,\nStars twinkle like scattered diamonds,\nEach one holding ancient secrets,\nWhispering stories of distant worlds,\nGuiding dreamers through the night."),
    ]
    
    for (poemType, topic, content) in samples {
        let req = RequestEnhanced(
            userInput: topic,
            userTopic: topic,
            poemType: poemType,
            temperature: Temperature.all[0]
        )
        let resp = ResponseEnhanced(
            requestId: req.id,
            userId: "preview-user",
            content: content,
            role: "assistant",
            isFavorite: [true, false].randomElement() ?? false, // Mix of favorited and regular
            hasAnimated: true
        )
        req.responseId = resp.id
        
        try! dataManager.save(request: req)
        try! dataManager.save(response: resp)
    }
    
    return TestHarnessView()
        .environmentObject(dataManager)
        .environmentObject(chatService)
        .environmentObject(PoemFilterSettings())
        .environmentObject(appUiSettings)
        .environmentObject(PoemCreationState())
}
