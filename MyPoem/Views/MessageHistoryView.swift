// MyPoem/Views/MessageHistoryView.swift
import SwiftUI
import SwiftData

struct MessageHistoryView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var appUiSettings: AppUiSettings
    
    @State private var previousRequestCount: Int = 0
    @State private var showJumpToBottom: Bool = false
    
    let requests: [Request]
    
    init(requests: [Request] = []) {
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
        }
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
//                .background(
//                    Circle()
//                        .fill(Color.accentColor.opacity(0.9))
//                        .frame(width: 44, height: 44)
//                )
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
//        .frame(width: 44, height: 44)
//        .padding(.trailing, 16)
//        .padding(.bottom, 100)
//        .transition(.asymmetric(
//            insertion: .scale(scale: 0.8).combined(with: .opacity),
//            removal: .scale(scale: 0.8).combined(with: .opacity)
//        ))
//        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showJumpToBottom)
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
        let request: Request
        var onDelete: () -> Void

        var body: some View {
            RequestResponseCardView(request: request)
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
            
//            // Invisible detector at the bottom
//            Color.clear
//                .frame(height: 0)
//                .id("bottom-detector")
//                .onAppear {
//                    // User can see the bottom, hide button
//                    if showJumpToBottom {
//                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
//                            showJumpToBottom = false
//                        }
//                    }
//                }
//                .onDisappear {
//                    // User scrolled away from bottom, show button
//                    if !showJumpToBottom && requests.count > 5 { // Only show if there's content to scroll to
//                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
//                            showJumpToBottom = true
//                        }
//                    }
//                }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .onChange(of: requests.count) { oldCount, newCount in
            // Hide jump button when new content arrives
//            if newCount > previousRequestCount {
//                showJumpToBottom = false
//            }
            
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

    private func deleteRequest(request: Request) {
        context.delete(request)
        try? context.save()
    }
}
