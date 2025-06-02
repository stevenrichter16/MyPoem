// MyPoem/Views/BrowseView.swift
import SwiftUI
import SwiftData

struct BrowseView: View {
    @Environment(AppState.self) private var appState
    @Environment(DataManager.self) private var dataManager
    @State private var localNavigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $localNavigationPath) {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 16) {
                    ForEach(PoemType.all, id: \.id) { poemType in
                        PoemTypeTile(
                            poemType: poemType,
                            requestCount: dataManager.requestCount(for: poemType),
                            recentPoem: dataManager.mostRecentRequest(for: poemType),
                            syncPending: hasPendingSyncForType(poemType)
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
        }
        .onChange(of: appState.selectedTab) { oldValue, newValue in
            // If Browse tab is reselected while already on Browse
            if oldValue == 1 && newValue == 1 {
                localNavigationPath = NavigationPath()
            }
        }
    }
    
    private func hasPendingSyncForType(_ poemType: PoemType) -> Bool {
        let requests = dataManager.requests(for: poemType)
        return requests.contains { request in
            request.syncStatus != .synced ||
            (dataManager.response(for: request)?.syncStatus != .synced)
        }
    }
}

// MARK: - Poem Type Tile
struct PoemTypeTile: View {
    let poemType: PoemType
    let requestCount: Int
    let recentPoem: RequestEnhanced?
    let syncPending: Bool
    
    @Environment(DataManager.self) private var dataManager
    
    var body: some View {
        NavigationLink(value: poemType) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with icon and count
                HStack {
                    Circle()
                        .fill(.white.opacity(0.3))
                        .frame(width: 12, height: 12)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        if syncPending {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        Text("\(requestCount)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
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
                        Text(response.content ?? "")
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
                        Text("Loading...")
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
    let poemType: PoemType
    @Environment(AppState.self) private var appState
    @Environment(DataManager.self) private var dataManager
    
    private var requests: [RequestEnhanced] {
        dataManager.requests(for: poemType)
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
                appState.setFilter(poemType)
            }
            .onDisappear {
                appState.resetFilters()
            }
    }
}
