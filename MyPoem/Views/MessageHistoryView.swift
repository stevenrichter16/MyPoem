// MyPoem/Views/MessageHistoryView.swift
import SwiftUI
import SwiftData

struct MessageHistoryView: View {
    @EnvironmentObject private var dataManager: DataManager
    @EnvironmentObject private var appUiSettings: AppUiSettings
    @EnvironmentObject private var poemCreationState: PoemCreationState
    
    @State private var previousRequestCount: Int = 0
    @State private var showJumpToBottom: Bool = false
    
    let requests: [RequestEnhanced]
    
    init(requests: [RequestEnhanced] = []) {
        self.requests = requests
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollViewReader { proxy in
                messageListContent(proxy: proxy)
                    .onReceive(NotificationCenter.default.publisher(for: .scrollToBottom)) { _ in
                        jumpToBottom(proxy: proxy)
                    }
                
                if showJumpToBottom {
                    jumpToBottomButton(proxy: proxy)
                }
            }
            
            // Poem creation notification modal
            if poemCreationState.showCreationModal {
                poemCreationModal()
            }
        }
    }
    
    // MARK: - Poem Creation Modal
    @ViewBuilder
    private func poemCreationModal() -> some View {
        VStack {
            Spacer()
            
            HStack(spacing: 16) {
                if poemCreationState.isCreatingPoem {
                    // Loading state
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.white)
                } else {
                    // Success state
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.title2)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    if let poemType = poemCreationState.createdPoemType {
                        Text(poemCreationState.isCreatingPoem ? "Creating \(poemType.name)..." : "New \(poemType.name) Created!")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if poemCreationState.isCreatingPoem {
                            Text("Crafting your poem about \"\(poemCreationState.creationTopic)\"")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(1)
                        } else {
                            Text("Navigate to \(poemType.name) to see your new poem")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                poemCreationState.isCreatingPoem ? Color.blue : Color.green,
                                poemCreationState.isCreatingPoem ? Color.blue.opacity(0.8) : Color.green.opacity(0.8)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // Position above tab bar
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: poemCreationState.showCreationModal)
        .animation(.easeInOut(duration: 0.3), value: poemCreationState.isCreatingPoem)
    }

    // MARK: - Jump to Bottom Button
    @ViewBuilder
    private func jumpToBottomButton(proxy: ScrollViewProxy) -> some View {
        Button(action: {
            jumpToBottom(proxy: proxy)
        }) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
    }
    
    private func jumpToBottom(proxy: ScrollViewProxy) {
        if let lastRequest = requests.last {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                proxy.scrollTo(lastRequest.id, anchor: .bottom)
            }
        }
    }

    // MARK: - Subviews and Helpers

    private struct MessageRow: View {
        let request: RequestEnhanced
        var onDelete: () -> Void
        @EnvironmentObject private var poemCreationState: PoemCreationState

        var body: some View {
            RequestResponseCardView(request: request)
                .environmentObject(poemCreationState)
                .id(request.id)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation { onDelete() }
                    } label: { Label("Delete", systemImage: "trash") }
                }
        }
    }
    
    @ViewBuilder
    private func messageListContent(proxy: ScrollViewProxy) -> some View {
        List {
            ForEach(requests, id: \.id) { req in
                MessageRow(request: req, onDelete: { deleteRequest(request: req) })
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .onChange(of: requests.count) { oldCount, newCount in
            // Scroll to bottom for new messages
            if newCount > previousRequestCount {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    if let lastRequest = requests.last {
                        scrollTo(requestID: lastRequest.id, proxy: proxy, anchor: .bottom, animated: true)
                    }
                }
            }
            previousRequestCount = newCount
        }
        .onAppear {
            // Initial scroll logic
            if !appUiSettings.hasPerformedInitialHistoryScroll {
                if !requests.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let lastRequest = requests.last {
                            scrollTo(requestID: lastRequest.id, proxy: proxy, anchor: .bottom, animated: false)
                        }
                        appUiSettings.markInitialHistoryScrollPerformed()
                    }
                } else {
                    appUiSettings.markInitialHistoryScrollPerformed()
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func scrollTo(requestID: String, proxy: ScrollViewProxy, anchor: UnitPoint, animated: Bool) {
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(requestID, anchor: anchor)
            }
        } else {
            proxy.scrollTo(requestID, anchor: anchor)
        }
    }

    private func deleteRequest(request: RequestEnhanced) {
        do {
            try dataManager.delete(request: request)
        } catch {
            print("Failed to delete request: \(error)")
        }
    }
}
