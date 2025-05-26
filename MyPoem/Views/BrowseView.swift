// MyPoem/Views/BrowseView.swift
import SwiftUI
import SwiftData

struct BrowseView: View {
    @EnvironmentObject private var dataManager: DataManager
    @EnvironmentObject private var poemFilterSettings: PoemFilterSettings
    @EnvironmentObject private var appUiSettings: AppUiSettings
    @EnvironmentObject private var navigationManager: NavigationManager
    @EnvironmentObject private var poemCreationState: PoemCreationState
    @State private var navigationPath = NavigationPath()
    
    // Grid layout configuration
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(PoemType.all, id: \.id) { poemType in
                        PoemTypeTile(
                            poemType: poemType,
                            requestCount: dataManager.requestCount(for: poemType),
                            recentPoem: dataManager.mostRecentRequest(for: poemType)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("Browse Poems")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
            .navigationDestination(for: PoemType.self) { poemType in
                PoemTypeDetailView(poemType: poemType)
            }
            .onAppear {
                print("Browse View Appear")
                // Keep fullInteractive context for browsing
                appUiSettings.setCardDisplayContext(displayContext: CardDisplayContext.fullInteractive)
            }
            .onDisappear {
                print("Browse View Disappear")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .popToBrowseRoot)) { _ in
            // Pop to root when Browse tab is tapped while already on Browse
            navigationPath = NavigationPath()
        }
        .onReceive(NotificationCenter.default.publisher(for: .browseNavigateTo)) { notification in
            if let poemType = notification.userInfo?["poemType"] as? PoemType {
                // Navigate to the specific poem type
                navigationPath.append(poemType)
            }
        }
    }
}

// MARK: - Poem Type Tile
struct PoemTypeTile: View {
    let poemType: PoemType
    let requestCount: Int
    let recentPoem: RequestEnhanced?
    
    @EnvironmentObject private var dataManager: DataManager
    
    var body: some View {
        NavigationLink(value: poemType) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with icon and count
                HStack {
                    Circle()
                        .fill(.white.opacity(0.3))
                        .frame(width: 12, height: 12)
                    
                    Spacer()
                    
                    Text("\(requestCount)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Content area
                VStack(alignment: .leading, spacing: 8) {
                    Text(poemType.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    if let recent = recentPoem,
                       let response = dataManager.response(for: recent) {
                        Text(response.content)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    } else if requestCount == 0 {
                        Text("No poems yet")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .italic()
                    } else {
                        Text("Tap to explore")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .padding(16)
            .frame(height: 160)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                poemTypeColor,
                                poemTypeColor.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: poemTypeColor.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    private var poemTypeColor: Color {
        switch poemType.name.lowercased() {
        case "haiku": return .blue
        case "sonnet": return .purple
        case "free verse": return .green
        case "limerick": return .orange
        case "ballad": return .red
        default: return .gray
        }
    }
}

// MARK: - Poem Type Detail View
struct PoemTypeDetailView: View {
    @EnvironmentObject private var dataManager: DataManager
    @EnvironmentObject private var appUiSettings: AppUiSettings
    @EnvironmentObject private var poemFilterSettings: PoemFilterSettings
    @EnvironmentObject private var poemCreationState: PoemCreationState
    @EnvironmentObject private var navigationManager: NavigationManager
    let poemType: PoemType
    
    private var requests: [RequestEnhanced] {
        dataManager.requests(for: poemType)
    }
    
    var body: some View {
        MessageHistoryView(requests: requests)
            .navigationTitle(poemType.name)
            .navigationBarTitleDisplayMode(.inline)
            .environmentObject(poemCreationState)
            .environmentObject(navigationManager)
            .environmentObject(poemFilterSettings)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(requests.count) poems")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(Capsule())
                }
            }
            .padding(.bottom, 80)
            .onAppear {
                print("PoemTypeDetailView Appear")
                // Set the filter to show we're viewing a specific type
                poemFilterSettings.setFilter(poemType)
                // Keep fullInteractive context
                appUiSettings.setCardDisplayContext(displayContext: CardDisplayContext.fullInteractive)
            }
            .onDisappear {
                print("PoemTypeDetailView Disappear")
                // Clear the filter when leaving
                poemFilterSettings.resetFilter()
            }
    }
}

// MARK: - Preview
#Preview("Browse View") {
    let container = try! ModelContainer(
        for: RequestEnhanced.self, ResponseEnhanced.self, PoemGroup.self,
        configurations: ModelConfiguration(
            schema: Schema([RequestEnhanced.self, ResponseEnhanced.self, PoemGroup.self]),
            isStoredInMemoryOnly: true
        )
    )
    let context = container.mainContext
    let dataManager = DataManager(context: context)
    
    // Create sample data for different poem types
    let samples: [(PoemType, String, String)] = [
        (PoemType.all[0], "mountains in winter", "Snow caps the peaks high,\nSilent giants touch the sky,\nWinter's breath is cold."),
        (PoemType.all[1], "ocean waves", "The endless ocean calls to me with ancient voices,\nWaves crash against the shore in rhythmic harmony,\nSalt spray dances in the morning light."),
        (PoemType.all[0], "cherry blossoms", "Pink petals flutter,\nSpring's gentle promise unfolds,\nBeauty brief but true.")
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
            userId: "test-user",
            content: content,
            role: "assistant",
            isFavorite: false,
            hasAnimated: true
        )
        req.responseId = resp.id
        
        try! dataManager.save(request: req)
        try! dataManager.save(response: resp)
    }
    
    return BrowseView()
        .environmentObject(dataManager)
        .environmentObject(PoemFilterSettings())
        .environmentObject(AppUiSettings())
        .environmentObject(NavigationManager())
        .environmentObject(PoemCreationState())
}

#Preview("Empty Browse View") {
    let container = try! ModelContainer(
        for: RequestEnhanced.self, ResponseEnhanced.self, PoemGroup.self,
        configurations: ModelConfiguration(
            schema: Schema([RequestEnhanced.self, ResponseEnhanced.self, PoemGroup.self]),
            isStoredInMemoryOnly: true
        )
    )
    let context = container.mainContext
    let dataManager = DataManager(context: context)
    
    return BrowseView()
        .environmentObject(dataManager)
        .environmentObject(PoemFilterSettings())
        .environmentObject(AppUiSettings())
        .environmentObject(NavigationManager())
        .environmentObject(PoemCreationState())
}
