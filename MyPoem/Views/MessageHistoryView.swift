// MessageHistoryView.swift - Minimalist Redesign
import SwiftUI

struct MessageHistoryView: View {
    let requests: [RequestEnhanced]
    
    @Environment(AppState.self) private var appState
    @Environment(DataManager.self) private var dataManager
    @Environment(CloudKitSyncManager.self) private var syncManager
    
    @State private var scrollPosition: String?
    @State private var isRefreshing: Bool = false
    @Namespace private var topID
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Header with ID for scrolling
                MinimalistHeader()
                    .padding(.top, 50)
                    .padding(.bottom, 20)
                    .id(topID)
            
            // Content
            if requests.isEmpty {
                MinimalistEmptyState()
                    .frame(minHeight: 400)
                    .padding(.top, 100)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(requests.enumerated()), id: \.element.id) { index, request in
                        if let id = request.id {
                            PoemCardView(request: request)
                                .id(id)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top)),
                                    removal: .opacity.combined(with: .scale(scale: 0.95))
                                ))
                                .animation(
                                    .spring(response: 0.6, dampingFraction: 0.8)
                                        .delay(Double(index) * 0.1),
                                    value: requests.count
                                )
                        }
                    }
                }
            }
            }
            .onChange(of: requests.count) { oldCount, newCount in
                // Scroll to top when a new poem is added
                if newCount > oldCount {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(topID, anchor: .top)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .scrollToTopAfterCreation)) { _ in
                // Scroll to top when poem creation completes
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(topID, anchor: .top)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .scrollToTop)) { _ in
                // Scroll to top on tab reselection
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(topID, anchor: .top)
                }
            }
        }
        .background(Color(hex: "FAFAFA"))
        .scrollContentBackground(.hidden)
        .refreshable {
            await performRefresh()
        }
    }
    
    private func performRefresh() async {
        isRefreshing = true
        await dataManager.triggerSync()
        
        // Wait for visual feedback
        try? await Task.sleep(nanoseconds: 500_000_000)
        isRefreshing = false
    }
}

// MARK: - Minimalist Header
struct MinimalistHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Poetry")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(Color(hex: "1A1A1A"))
                .kerning(-0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }
}

// MARK: - Minimalist Empty State
struct MinimalistEmptyState: View {
    @Environment(AppState.self) private var appState
    @Environment(CloudKitSyncManager.self) private var syncManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("✦")
                .font(.system(size: 64))
                .foregroundColor(Color(hex: "1A1A1A").opacity(0.1))
            
            Text("No poems yet")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(Color(hex: "666666"))
            
            Text("Tap the + button to create your first poem")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "999999"))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            
            if syncManager.syncState == .syncing {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(Color(hex: "666666"))
                    Text("Syncing...")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "666666"))
                }
                .padding(.top, 10)
            }
        }
        .padding(.horizontal, 40)
    }
}
