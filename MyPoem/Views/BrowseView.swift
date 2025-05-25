// MyPoem/Views/BrowseView.swift
import SwiftUI
import SwiftData

struct BrowseView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var poemFilterSettings: PoemFilterSettings
    @EnvironmentObject private var appUiSettings: AppUiSettings
    @EnvironmentObject private var navigationManager: NavigationManager
    @State private var navigationPath = NavigationPath()
    @Query private var allRequests: [Request]
    
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
                            requestCount: requestCount(for: poemType),
                            recentPoem: mostRecentPoem(for: poemType)
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
                appUiSettings.setCardDisplayContext(displayContext: CardDisplayContext.typeFiltered)
            }
            .onDisappear {
                print("Browse View Disappear")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .popToBrowseRoot)) { _ in
            // Pop to root when Browse tab is tapped while already on Browse
            navigationPath = NavigationPath()
        }
    }
    // MARK: - Helper Methods
    
    private func requestCount(for poemType: PoemType) -> Int {
        allRequests.filter { $0.poemType.id == poemType.id }.count
    }
    
    private func mostRecentPoem(for poemType: PoemType) -> Request? {
        allRequests
            .filter { $0.poemType.id == poemType.id }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }
}

// MARK: - Poem Type Tile
struct PoemTypeTile: View {
    let poemType: PoemType
    let requestCount: Int
    let recentPoem: Request?
    
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
                    
                    if let recent = recentPoem, let response = recent.response {
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
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var appUiSettings: AppUiSettings
    let poemType: PoemType
    
    @Query private var requests: [Request]
    
    init(poemType: PoemType) {
        self.poemType = poemType
        // Filter requests for this specific poem type
        self._requests = Query(
            filter: #Predicate<Request> { request in
                request.poemType.id == poemType.id
            },
            sort: \Request.createdAt,
            order: .reverse
        )
    }
    
    var body: some View {
        MessageHistoryView(requests: requests)
            .navigationTitle(poemType.name)
            .navigationBarTitleDisplayMode(.inline)
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
                appUiSettings.setCardDisplayContext(displayContext: CardDisplayContext.typeFiltered)
            }
            .onDisappear {
                print("PoemTypeDetailView Disappear")
            }
    }
    

}

// MARK: - Preview
#Preview("Browse View") {
    let container = try! ModelContainer(
        for: Request.self, Response.self,
        configurations: ModelConfiguration(
            schema: Schema([Request.self, Response.self]),
            isStoredInMemoryOnly: true
        )
    )
    let context = container.mainContext
    
    // Create sample data for different poem types
    let samples: [(PoemType, String, String)] = [
        (PoemType.all[0], "mountains in winter", "Snow caps the peaks high,\nSilent giants touch the sky,\nWinter's breath is cold."),
        (PoemType.all[1], "ocean waves", "The endless ocean calls to me with ancient voices,\nWaves crash against the shore in rhythmic harmony,\nSalt spray dances in the morning light."),
        (PoemType.all[0], "cherry blossoms", "Pink petals flutter,\nSpring's gentle promise unfolds,\nBeauty brief but true.")
    ]
    
    for (poemType, topic, content) in samples {
        let req = Request(
            userInput: topic,
            userTopic: topic,
            poemType: poemType,
            temperature: Temperature.all[0]
        )
        let resp = Response(
            userId: "test-user",
            content: content,
            role: "assistant",
            isFavorite: false,
            request: req
        )
        req.response = resp
        context.insert(req)
        context.insert(resp)
    }
    
    try! context.save()
    
    return BrowseView()
        .modelContainer(container)
        .environmentObject(PoemFilterSettings())
}

#Preview("Empty Browse View") {
    let container = try! ModelContainer(
        for: Request.self, Response.self,
        configurations: ModelConfiguration(
            schema: Schema([Request.self, Response.self]),
            isStoredInMemoryOnly: true
        )
    )
    
    return BrowseView()
        .modelContainer(container)
        .environmentObject(PoemFilterSettings())
}
