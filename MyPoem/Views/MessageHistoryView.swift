// MessageHistoryView.swift - Updated for CloudKit
import SwiftUI

struct MessageHistoryView: View {
    let requests: [RequestEnhanced]
    
    @Environment(AppState.self) private var appState
    @Environment(DataManager.self) private var dataManager
    @Environment(CloudKitSyncManager.self) private var syncManager
    
    @State private var previousRequestCount: Int = 0
    @State private var showJumpToBottom: Bool = false
    @State private var scrollPosition: String?
    @State private var isAutoScrolling: Bool = false
    @State private var refreshID = UUID()
    
    // Pull to refresh state
    @State private var isRefreshing: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollViewReader { proxy in
                messageListContent(proxy: proxy)
                    .onChange(of: requests.count) { oldCount, newCount in
                        handleRequestCountChange(oldCount: oldCount, newCount: newCount, proxy: proxy)
                    }
                    .onChange(of: dataManager.responses.count) { _, _ in
                        // Force refresh when responses change
                        refreshID = UUID()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .scrollToTop)) { _ in
                        jumpToBottom(proxy: proxy, animated: true)
                    }
            }
            
            // Jump to bottom button
            if showJumpToBottom && !requests.isEmpty {
                jumpToBottomButton()
            }
            
            // Sync status overlay for empty state
            if requests.isEmpty && syncManager.syncState == .syncing {
                syncingEmptyState()
            }
        }
        .onAppear {
            previousRequestCount = requests.count
        }
    }
    
    // MARK: - Main Content
    
    @ViewBuilder
    private func messageListContent(proxy: ScrollViewProxy) -> some View {
        List {
            // Pull to refresh indicator
            if !requests.isEmpty {
                pullToRefreshView()
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
            
            // Empty state
            if requests.isEmpty {
                emptyStateView()
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .frame(maxWidth: .infinity)
                    .frame(height: 400)
            } else {
                // Message rows
                ForEach(requests, id: \.id) { request in
                    if let id = request.id {
                        MessageRow(
                            request: request,
                            onDelete: { deleteRequest(request) },
                            scrollProxy: proxy,
                            dataManager: dataManager
                        )
                        .id(id)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                    }
                }
                
                // Loading indicator for pending syncs
                if dataManager.hasUnsyncedChanges {
                    pendingSyncIndicator()
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            }
        }
        .id(refreshID) // Force refresh when needed
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .scrollDismissesKeyboard(.interactively)
        .scrollDetection(coordinateSpace: "messageList", showJumpToBottom: $showJumpToBottom)
        .refreshable {
            await performRefresh()
        }
    }
    
    // MARK: - Subviews
    
    private struct MessageRow: View {
        let request: RequestEnhanced
        let onDelete: () -> Void
        let scrollProxy: ScrollViewProxy
        let dataManager: DataManager
        
        @Environment(AppState.self) private var appState
        @State private var isDeleting: Bool = false
        
        var body: some View {
            PoemCardView(request: request)
                .opacity(isDeleting ? 0.5 : 1.0)
                .scaleEffect(isDeleting ? 0.95 : 1.0)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isDeleting = true
                            onDelete()
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    
                    if request.syncStatus == SyncStatus.error {
                        Button {
                            Task {
                                await retrySync(for: request)
                            }
                        } label: {
                            Label("Retry Sync", systemImage: "arrow.clockwise")
                        }
                        .tint(.orange)
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        sharePoem(request)
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .tint(.blue)
                }
        }
        
        private func retrySync(for request: RequestEnhanced) async {
            request.syncStatus = SyncStatus.pending
            request.lastModified = Date()
            
            if let response = dataManager.response(for: request) {
                response.syncStatus = SyncStatus.pending
                response.lastModified = Date()
            }
            
            await dataManager.triggerSync()
        }
        
        private func sharePoem(_ request: RequestEnhanced) {
            // Implementation handled by PoemCardView
        }
    }
    
    @ViewBuilder
    private func emptyStateView() -> some View {
        VStack(spacing: 20) {
            // Context-aware empty state
            if let filter = appState.activeFilter {
                // Filtered empty state
                Image(systemName: "text.badge.slash")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text("No \(filter.name) poems yet")
                    .font(.title3)
                    .foregroundColor(.primary)
                
                Text("Create your first \(filter.name.lowercased()) using the + button")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else if syncManager.syncState == .syncing {
                // Syncing state
                ProgressView()
                    .scaleEffect(1.5)
                    .padding(.bottom, 10)
                
                Text("Syncing your poems...")
                    .font(.title3)
                    .foregroundColor(.primary)
                
                Text("Your poems will appear here shortly")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if !syncManager.isConnected {
                // Offline state
                Image(systemName: "wifi.slash")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text("You're offline")
                    .font(.title3)
                    .foregroundColor(.primary)
                
                Text("Your poems will sync when you're back online")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                // Default empty state
                Image(systemName: "text.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text("No poems yet")
                    .font(.title3)
                    .foregroundColor(.primary)
                
                Text("Tap the + button to create your first poem")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Quick actions for empty state
            if syncManager.isConnected {
                Button(action: {
                    NotificationCenter.default.post(name: .showComposer, object: nil)
                }) {
                    Label("Create Poem", systemImage: "plus.circle.fill")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func pullToRefreshView() -> some View {
        HStack {
            Spacer()
            
            if isRefreshing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "arrow.down")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Text(isRefreshing ? "Syncing..." : "Pull to sync")
                .font(.caption)
                .foregroundColor(.gray)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .opacity(0.6)
    }
    
    @ViewBuilder
    private func pendingSyncIndicator() -> some View {
        HStack {
            Spacer()
            
            ProgressView()
                .scaleEffect(0.7)
            
            Text("\(dataManager.unsyncedRequestsCount + dataManager.unsyncedResponsesCount) items syncing...")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.vertical, 12)
    }
    
    @ViewBuilder
    private func syncingEmptyState() -> some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            
            Text("Loading poems from iCloud...")
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding()
        .background(
            Capsule()
                .fill(Color.black.opacity(0.7))
        )
        .padding(.bottom, 100)
    }
    
    @ViewBuilder
    private func jumpToBottomButton() -> some View {
        Button(action: {
            withAnimation {
                if let firstRequest = requests.first {
                    scrollPosition = firstRequest.id
                }
            }
        }) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 48, height: 48)
                
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.trailing, 16)
        .padding(.bottom, 100)
        .transition(.scale.combined(with: .opacity))
    }
    
    // MARK: - Helper Methods
    
    private func handleRequestCountChange(oldCount: Int, newCount: Int, proxy: ScrollViewProxy) {
        // Scroll to new items if they were added
        if newCount > oldCount {
            // Delay to ensure view is rendered
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Since requests are sorted newest first, scroll to the first item
                if let firstRequest = requests.first, let id = firstRequest.id {
                    isAutoScrolling = true
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        proxy.scrollTo(id, anchor: .top)
                    }
                    
                    // Reset auto-scrolling flag
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        isAutoScrolling = false
                    }
                }
            }
        }
        previousRequestCount = newCount
    }
    
    private func jumpToBottom(proxy: ScrollViewProxy, animated: Bool) {
        // Since newest items are at the top, we'll rename this to jumpToTop
        guard let firstRequest = requests.first, let id = firstRequest.id else { return }
        
        isAutoScrolling = true
        
        if animated {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                proxy.scrollTo(id, anchor: .top)
            }
        } else {
            proxy.scrollTo(id, anchor: .top)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            isAutoScrolling = false
            withAnimation(.easeInOut(duration: 0.2)) {
                showJumpToBottom = false
            }
        }
    }
    
    private func deleteRequest(_ request: RequestEnhanced) {
        Task {
            do {
                try await dataManager.deleteRequest(request)
            } catch {
                print("Failed to delete request: \(error)")
                appState.showCloudKitError("Failed to delete poem: \(error.localizedDescription)")
            }
        }
    }
    
    private func performRefresh() async {
        isRefreshing = true
        
        // Trigger sync
        await dataManager.triggerSync()
        
        // Wait a moment for visual feedback
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        isRefreshing = false
    }
}

// MARK: - Scroll Phase Detection

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ScrollDetector: View {
    let coordinateSpace: String
    @Binding var showJumpToBottom: Bool
    let threshold: CGFloat = 100
    
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geometry.frame(in: .named(coordinateSpace)).minY
                )
        }
        .frame(height: 0)
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
            withAnimation(.easeInOut(duration: 0.2)) {
                showJumpToBottom = offset < -threshold
            }
        }
    }
}

extension View {
    func scrollDetection(coordinateSpace: String, showJumpToBottom: Binding<Bool>) -> some View {
        self
            .coordinateSpace(name: coordinateSpace)
            .overlay(alignment: .bottom) {
                ScrollDetector(
                    coordinateSpace: coordinateSpace,
                    showJumpToBottom: showJumpToBottom
                )
            }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let showComposer = Notification.Name("showComposer")
}

// MARK: - Preview

#Preview("Message History") {
    let mockRequests = (0..<5).map { index in
        let request = RequestEnhanced(
            userInput: "Test poem \(index)",
            userTopic: "Test topic \(index)",
            poemType: PoemType.all[index % PoemType.all.count],
            temperature: Temperature.all[0]
        )
        request.syncStatus = [SyncStatus.synced, SyncStatus.pending, SyncStatus.syncing].randomElement()
        return request
    }
    
    return MessageHistoryView(requests: mockRequests)
        .background(Color(.systemGroupedBackground))
}

#Preview("Empty State") {
    MessageHistoryView(requests: [])
        .background(Color(.systemGroupedBackground))
}
