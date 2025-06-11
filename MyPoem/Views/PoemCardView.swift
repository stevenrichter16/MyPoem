// PoemCardView.swift - Minimalist Redesign
import SwiftUI

struct PoemCardView: View {
    let request: RequestEnhanced
    @Environment(AppState.self) private var appState
    @Environment(DataManager.self) private var dataManager
    @Environment(ChatService.self) private var chatService
    @Environment(CloudKitSyncManager.self) private var syncManager
    
    // MARK: - State
    @State private var isHovered: Bool = false
    @State private var showingRevisionHistory = false
    @State private var showingShareSheet = false
    @State private var showingMoreMenu = false
    @State private var showingPoemDetail = false
    @State private var isRegenerating = false
    @State private var isDeleting = false
    @State private var isResponseExpanded: Bool = false
    @State private var showExpandButton: Bool = false
    
    // For text measurement
    @State private var fullTextHeight: CGFloat = .zero
    @State private var collapsedTextHeight: CGFloat = .zero
    
    private let collapsedLineLimit = 6
    private let heightComparisonFudgeFactor: CGFloat = 8.0
    
    // MARK: - Computed Properties
    private var response: ResponseEnhanced? {
        dataManager.response(for: request)
    }
    
    private var poemType: PoemType? {
        request.poemType
    }
    
    @State private var revisionCount: Int = 0
    
    private func loadRevisionCount() async {
        do {
            let count = try await dataManager.getRevisionCount(for: request)
            await MainActor.run {
                self.revisionCount = count
            }
        } catch {
            print("Failed to load revision count: \(error)")
        }
    }
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main card content
            VStack(alignment: .leading, spacing: 0) {
                // Topic header with revision indicator
                HStack(alignment: .center, spacing: 0) {
                    if let topic = request.userInput {
                        Text(topic)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(hex: "000000"))
                            .lineLimit(1)
                    }
                    
                    Spacer(minLength: 12)
                    
                    // Revision indicator
                    if revisionCount > 1 {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: "34C759"))
                                .frame(width: 5, height: 5)
                            Text("v\(revisionCount)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(hex: "34C759"))
                        }
                    }
                    
                    // Small ellipsis menu in top right
                    Button(action: { showingMoreMenu = true }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#999999"))
                            .frame(width: 24, height: 24)
                            .background(Color(hex: "#F0F0F0"))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.bottom, 12)
                
                // Poem content with expand/collapse
                if let content = response?.content {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(content)
                            .font(.system(size: 16, weight: .regular))
                            .lineSpacing(6)
                            .foregroundColor(Color(hex: "1A1A1A"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(isResponseExpanded ? nil : collapsedLineLimit)
                            .background(heightMeasurementOverlay(content: content))
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isResponseExpanded)
                        
                        // Minimalist expand/collapse button
                        if showExpandButton {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isResponseExpanded.toggle()
                                }
                            }) {
                                Text(isResponseExpanded ? "Show less" : "Show more")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color(hex: "007AFF"))
                                    .padding(.top, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                } else if (chatService.isGenerating && isActiveGeneration()) || isRegenerating {
                    HStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(Color(hex: "666666"))
                        Text("Crafting your \(poemType?.name.lowercased() ?? "poem")...")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "666666"))
                    }
                    .padding(.vertical, 20)
                } else {
                    Text("Unable to generate poem")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "999999"))
                        .padding(.vertical, 20)
                }
                
                // Bottom meta section
                HStack(alignment: .center, spacing: 0) {
                    // Poem type selector (restored functionality)
                    if let type = poemType {
                        Menu {
                            ForEach(PoemType.all, id: \.self) { poemType in
                                if poemType.id != type.id {
                                    Button(action: {
                                        resendRequest(as: poemType)
                                    }) {
                                        Label(poemType.name, systemImage: "arrow.clockwise")
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(type.name.uppercased())
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .kerning(0.5)
                                
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "1A1A1A"))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    HStack(spacing: 16) {
                        // Favorite button
                        CircularActionButton(
                            icon: (response?.isFavorite ?? false) ? "heart.fill" : "heart",
                            isActive: response?.isFavorite ?? false,
                            activeColor: Color(hex: "FF3B30"),
                            action: { toggleFavorite() }
                        )
                        
                        // Regenerate button
                        CircularActionButton(
                            icon: "arrow.clockwise",
                            isLoading: isRegenerating,
                            action: { regeneratePoem() }
                        )
                        .disabled(chatService.isGenerating)
                        
                        // View details button
                        CircularActionButton(
                            icon: "eye",
                            action: { showingPoemDetail = true }
                        )
                    }
                }
                .padding(.top, 16)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(Color(hex: "FAFAFA"))
        }
        .background(Color.white)
        .overlay(
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.black.opacity(0.04))
                    .frame(height: 1)
                Spacer()
                Rectangle()
                    .fill(Color.black.opacity(0.08))
                    .frame(height: 1)
            }
        )
        .opacity(isDeleting ? 0.5 : 1.0)
        .scaleEffect(isDeleting ? 0.95 : 1.0)
        .confirmationDialog("More Actions", isPresented: $showingMoreMenu) {
            Button("Share Poem") {
                showingShareSheet = true
            }
            
            Button("Copy to Clipboard") {
                copyToClipboard()
            }
            
            Button("Delete Poem", role: .destructive) {
                deletePoem()
            }
            
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingRevisionHistory) {
            PoemRevisionTimelineView(request: request)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let content = response?.content, let topic = request.userInput {
                ShareSheet(items: [formatPoemForSharing(content: content, topic: topic, type: poemType)])
            }
        }
        .sheet(isPresented: $showingPoemDetail) {
            if let response = response {
                PoemDetailView(request: request, response: response)
            }
        }
        .task {
            await loadRevisionCount()
        }
    }
    
    // MARK: - Height Measurement
    @ViewBuilder
    private func heightMeasurementOverlay(content: String) -> some View {
        GeometryReader { geometry in
            Color.clear
                .overlay(
                    VStack {
                        // Full text measurement
                        Text(content)
                            .font(.custom("Georgia", size: 18))
                            .lineSpacing(8)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(width: geometry.size.width, alignment: .leading)
                            .background(
                                GeometryReader { textGeometry in
                                    Color.clear
                                        .onAppear {
                                            fullTextHeight = textGeometry.size.height
                                            updateExpandButtonVisibility()
                                        }
                                }
                            )
                        
                        // Collapsed text measurement
                        Text(content)
                            .font(.custom("Georgia", size: 18))
                            .lineSpacing(8)
                            .lineLimit(collapsedLineLimit)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(width: geometry.size.width, alignment: .leading)
                            .background(
                                GeometryReader { textGeometry in
                                    Color.clear
                                        .onAppear {
                                            collapsedTextHeight = textGeometry.size.height
                                            updateExpandButtonVisibility()
                                        }
                                }
                            )
                    }
                    .opacity(0)
                )
        }
    }
    
    private func updateExpandButtonVisibility() {
        if fullTextHeight > 0 && collapsedTextHeight > 0 {
            let shouldShow = fullTextHeight > (collapsedTextHeight + heightComparisonFudgeFactor)
            if showExpandButton != shouldShow {
                showExpandButton = shouldShow
            }
        }
    }
    
    // MARK: - Helper Methods
    private func isActiveGeneration() -> Bool {
        // Check if this card's request matches the active poem creation
        guard let creation = appState.poemCreation,
              let topic = request.userTopic,
              let type = request.poemType else {
            return false
        }
        
        // For resend as new type, the creation will have different type but same topic
        // So we should NOT show loading for the original card
        return creation.topic == topic && creation.type.id == type.id
    }
    
    // MARK: - Actions
    private func resendRequest(as newPoemType: PoemType) {
        guard let topic = request.userTopic else { return }
        
        // Show creation state in UI
        appState.startPoemCreation(type: newPoemType, topic: topic)
    }
    
    private func toggleFavorite() {
        Task {
            do {
                try await dataManager.toggleFavorite(for: request)
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            } catch {
                print("Failed to toggle favorite: \(error)")
            }
        }
    }
    
    private func regeneratePoem() {
        guard let topic = request.userTopic,
              let poemType = request.poemType else { return }
        
        // Simply use startPoemCreation like onSubmit and resendRequest do
        appState.startPoemCreation(type: poemType, topic: topic)
    }
    
    private func copyToClipboard() {
        guard let content = response?.content,
              let topic = request.userInput else { return }
        
        UIPasteboard.general.string = formatPoemForSharing(
            content: content,
            topic: topic,
            type: poemType
        )
        
        // Haptic feedback
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    private func deletePoem() {
        withAnimation(.easeOut(duration: 0.3)) {
            isDeleting = true
        }
        
        Task {
            do {
                try await dataManager.deleteRequest(request)
            } catch {
                isDeleting = false
                appState.showCloudKitError("Failed to delete poem: \(error.localizedDescription)")
            }
        }
    }
    
    private func formatPoemForSharing(content: String, topic: String, type: PoemType?) -> String {
        let typeName = type?.name ?? "Poem"
        return """
        \(typeName) about "\(topic)"
        
        \(content)
        
        Created with MyPoem
        """
    }
}

// MARK: - Circular Action Button
struct CircularActionButton: View {
    let icon: String
    var isActive: Bool = false
    var isLoading: Bool = false
    var activeColor: Color = Color(hex: "1A1A1A")
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isActive ? activeColor : Color.white)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(Color(hex: "E0E0E0"), lineWidth: 2)
                    )
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "666666")))
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isActive ? .white : Color(hex: "666666"))
                }
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}
