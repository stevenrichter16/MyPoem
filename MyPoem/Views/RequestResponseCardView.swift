// PoemCardView.swift (formerly RequestResponseCardView) - Updated for CloudKit
import SwiftUI

struct PoemCardViews: View {
    let request: RequestEnhanced
    @Environment(AppState.self) private var appState
    @Environment(DataManager.self) private var dataManager
    @Environment(ChatService.self) private var chatService
    @Environment(CloudKitSyncManager.self) private var syncManager
    
    // MARK: - Animation State
    @State private var isCardAnimating: Bool = false
    @State private var showCardContent: Bool = false
    @State private var isResponseExpanded: Bool = false
    @State private var fullTextHeight: CGFloat = .zero
    @State private var collapsedTextHeight: CGFloat = .zero
    @State private var showExpandCollapseButton: Bool = false
    @State private var showingActionSheet: Bool = false
    @State private var wasRecentlyTapped: Bool = false
    @State private var showingShareSheet: Bool = false
    @State private var isRegenerating: Bool = false
    
    @State private var showingRevisionHistory = false
    
    // Track response state for animations
    @State private var lastResponseId: String? = nil
    @State private var lastSyncStatus: SyncStatus? = nil
    
    private let collapsedLineLimit = 6
    private let heightComparisonFudgeFactor: CGFloat = 8.0
    
    // MARK: - Computed Properties
    
    private var response: ResponseEnhanced? {
        dataManager.response(for: request)
    }
    
    private var poemType: PoemType? {
        request.poemType
    }
    
    private var syncStatus: SyncStatus {
        // Check both request and response sync status
        let requestSync = request.syncStatus ?? .synced
        let responseSync = response?.syncStatus ?? .synced
        
        // Return the "worst" status
        if requestSync == .error || responseSync == .error {
            return .error
        } else if requestSync == .conflict || responseSync == .conflict {
            return .conflict
        } else if requestSync == .syncing || responseSync == .syncing {
            return .syncing
        } else if requestSync == .pending || responseSync == .pending {
            return .pending
        }
        return .synced
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            requestSection()
            responseSection()
                .onTapGesture {
                    if response != nil && !(response?.content ?? "").isEmpty {
                        provideTapFeedback()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isResponseExpanded.toggle()
                        }
                    }
                }
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: shadowColor, radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .onChange(of: dataManager.responses) { oldValue, newValue in
            handleDataManagerUpdate()
        }
        .onChange(of: response?.syncStatus) { oldValue, newValue in
            handleSyncStatusChange(from: oldValue, to: newValue)
        }
        .sheet(isPresented: $showingActionSheet) {
            actionSheetContent()
        }
        .sheet(isPresented: $showingShareSheet) {
            if let content = response?.content, let topic = request.userInput {
                ShareSheet(items: [formatPoemForSharing(content: content, topic: topic, type: poemType)])
            }
        }
        .contextMenu {
            Button {
                showingRevisionHistory = true
            } label: {
                Label("View Revision History", systemImage: "clock.arrow.circlepath")
            }
            
            Button {
                showingShareSheet = true
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            Button {
                copyToClipboard()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
        .sheet(isPresented: $showingRevisionHistory) {
            PoemRevisionTimelineView(request: request)
        }
    }
    
    // MARK: - Card Styling
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
    }
    
    private var borderColor: Color {
        switch syncStatus {
        case .error:
            return .red.opacity(0.5)
        case .conflict:
            return .yellow.opacity(0.5)
        case .pending, .syncing:
            return .orange.opacity(0.3)
        case .synced:
            return Color(.quaternaryLabel)
        }
    }
    
    private var borderWidth: CGFloat {
        syncStatus == .synced ? 0.5 : 1.5
    }
    
    private var shadowColor: Color {
        switch syncStatus {
        case .error:
            return .red.opacity(0.2)
        case .conflict:
            return .yellow.opacity(0.2)
        case .pending, .syncing:
            return .orange.opacity(0.15)
        case .synced:
            return .black.opacity(0.08)
        }
    }
    
    // MARK: - Request Section
    
    @ViewBuilder
    private func requestSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 18) {
                requestTypeChip()
                Spacer()
                requestActions()
            }
            
            if let input = request.userInput {
                Text(input)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            
            // Sync status indicator
            if syncStatus != .synced {
                syncStatusBadge()
            }
        }
    }
    
    @ViewBuilder
    private func requestTypeChip() -> some View {
        if let poemType = poemType {
            Menu {
                ForEach(PoemType.all, id: \.self) { type in
                    if type.id != poemType.id {
                        Button(action: {
                            resendRequest(as: type)
                        }) {
                            Label(type.name, systemImage: "arrow.clockwise")
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(poemTypeColor)
                        .frame(width: 8, height: 8)
                    
                    Text(poemType.name)
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemBackground))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }
    
    private var poemTypeColor: Color {
        switch poemType?.name.lowercased() {
        case "haiku": return .blue
        case "sonnet": return .purple
        case "free verse": return .green
        case "limerick": return .orange
        case "ballad": return .red
        default: return .gray
        }
    }
    
    @ViewBuilder
    private func requestActions() -> some View {
        HStack(spacing: 8) {
            // Regenerate button
            Button(action: {
                regeneratePoem()
            }) {
                ZStack {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                        .opacity(isRegenerating ? 0 : 1)
                    
                    if isRegenerating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                    }
                }
                .frame(width: 42, height: 42)
                .background(Color(.tertiarySystemBackground))
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isRegenerating || chatService.isGenerating)
            
            // Favorite button
            if response != nil {
                Button(action: { favoriteRequest() }) {
                    Image(systemName: (response?.isFavorite ?? false) ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor((response?.isFavorite ?? false) ? .red : .secondary)
                        .frame(width: 42, height: 42)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .scaleEffect((response?.isFavorite ?? false) ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: response?.isFavorite)
            }
            
            // More actions menu
            Menu {
                Button(action: { showingShareSheet = true }) {
                    Label("Share Poem", systemImage: "square.and.arrow.up")
                }
                
                Button(action: { copyToClipboard() }) {
                    Label("Copy to Clipboard", systemImage: "doc.on.doc")
                }
                
                if syncStatus == .conflict {
                    Button(action: { resolveConflict() }) {
                        Label("Resolve Conflict", systemImage: "exclamationmark.triangle")
                    }
                }
                
                Divider()
                
                Button(role: .destructive, action: { deletePoem() }) {
                    Label("Delete Poem", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 42, height: 42)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private func syncStatusBadge() -> some View {
        HStack(spacing: 4) {
            switch syncStatus {
            case .pending:
                Image(systemName: "icloud.and.arrow.up")
                Text("Waiting to sync")
            case .syncing:
                ProgressView()
                    .scaleEffect(0.7)
                Text("Syncing...")
            case .conflict:
                Image(systemName: "exclamationmark.icloud")
                Text("Sync conflict")
            case .error:
                Image(systemName: "xmark.icloud")
                Text("Sync error")
            case .synced:
                EmptyView()
            }
        }
        .font(.caption)
        .foregroundColor(syncStatusColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(syncStatusColor.opacity(0.1))
        .clipShape(Capsule())
    }
    
    private var syncStatusColor: Color {
        switch syncStatus {
        case .pending: return .orange
        case .syncing: return .blue
        case .conflict: return .yellow
        case .error: return .red
        case .synced: return .green
        }
    }
    
    // MARK: - Response Section
    
    @ViewBuilder
    private func responseSection() -> some View {
        if let response = response {
            if isCardAnimating {
                responseContent(for: response)
                    .opacity(showCardContent ? 1 : 0)
                    .scaleEffect(showCardContent ? 1 : 0.96)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showCardContent)
            } else {
                responseContent(for: response)
            }
        } else if chatService.isGenerating || isRegenerating {
            generatingIndicator()
        } else {
            errorIndicator()
        }
    }
    
    @ViewBuilder
    private func responseContent(for response: ResponseEnhanced) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let content = response.content, !content.isEmpty {
                responseText(content)
                responseFooter(response)
            } else {
                Text("Empty response")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private func responseText(_ content: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(content)
                .font(.body)
                .lineSpacing(2)
                .foregroundColor(.primary)
                .lineLimit(isResponseExpanded ? nil : collapsedLineLimit)
                .multilineTextAlignment(.leading)
                .background(heightMeasurementOverlay(content: content))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isResponseExpanded)
            
            if showExpandCollapseButton {
                expandCollapseButton()
            }
        }
    }
    
    @ViewBuilder
    private func heightMeasurementOverlay(content: String) -> some View {
        GeometryReader { geometry in
            Color.clear
                .overlay(
                    VStack {
                        Text(content)
                            .font(.body)
                            .lineSpacing(2)
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
                        
                        Text(content)
                            .font(.body)
                            .lineSpacing(2)
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
    
    @ViewBuilder
    private func expandCollapseButton() -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isResponseExpanded.toggle()
            }
        }) {
            HStack(spacing: 4) {
                Text(isResponseExpanded ? "Show less" : "Show more")
                    .font(.caption)
                Image(systemName: isResponseExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2)
            }
            .foregroundColor(.blue)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private func responseFooter(_ response: ResponseEnhanced) -> some View {
        HStack {
            if let createdDate = response.dateCreated {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(formatDate(createdDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if response.syncStatus != .synced {
                Image(systemName: "icloud.and.arrow.up")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.top, 4)
    }
    
    @ViewBuilder
    private func generatingIndicator() -> some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
                .tint(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Crafting your \(poemType?.name ?? "poem")...")
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text("This may take a moment")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
    }
    
    @ViewBuilder
    private func errorIndicator() -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.body)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Unable to generate poem")
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text("Tap regenerate to try again")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Helper Methods
    
    private func updateExpandButtonVisibility() {
        if fullTextHeight > 0 && collapsedTextHeight > 0 {
            let shouldShow = fullTextHeight > (collapsedTextHeight + heightComparisonFudgeFactor)
            if showExpandCollapseButton != shouldShow {
                showExpandCollapseButton = shouldShow
            }
        }
    }
    
    private func handleDataManagerUpdate() {
        let currentResponse = dataManager.response(for: request)
        let currentResponseId = currentResponse?.id
        
        // Check if we got a new response
        if currentResponseId != lastResponseId {
            print("🔄 PoemCardView: Response changed from \(lastResponseId ?? "nil") to \(currentResponseId ?? "nil")")
            
            if let newResponse = currentResponse, !(newResponse.hasAnimated ?? true) {
                print("🎬 Starting animation for new response: \(newResponse.id ?? "unknown")")
                startCardAppearAnimation(newResponse)
            }
            
            lastResponseId = currentResponseId
        }
    }
    
    private func handleSyncStatusChange(from oldStatus: SyncStatus?, to newStatus: SyncStatus?) {
        guard let new = newStatus, new != oldStatus else { return }
        
        // Add subtle animation when sync status changes
        withAnimation(.easeInOut(duration: 0.3)) {
            lastSyncStatus = new
        }
        
        // Show feedback for specific transitions
        if oldStatus == .syncing && new == .synced {
            provideSyncSuccessFeedback()
        } else if new == .error {
            provideSyncErrorFeedback()
        }
    }
    
    private func startCardAppearAnimation(_ response: ResponseEnhanced) {
        showCardContent = false
        isCardAnimating = true
        isResponseExpanded = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showCardContent = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                isCardAnimating = false
                response.hasAnimated = true
                
                Task {
                    do {
                        try await dataManager.updateResponse(response)
                        print("✅ Marked response as animated: \(response.id ?? "unknown")")
                    } catch {
                        print("❌ Failed to save response after animation: \(error)")
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatPoemForSharing(content: String, topic: String, type: PoemType?) -> String {
        let typeName = type?.name ?? "Poem"
        return """
        \(typeName) about "\(topic)"
        
        \(content)
        
        Created with MyPoem
        """
    }
    
    // MARK: - Feedback Methods
    
    private func provideTapFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        wasRecentlyTapped = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            wasRecentlyTapped = false
        }
    }
    
    private func provideSyncSuccessFeedback() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    private func provideSyncErrorFeedback() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
    
    // MARK: - Actions
    
    private func resendRequest(as newPoemType: PoemType) {
        guard let topic = request.userTopic else { return }
        
        // Show creation state in UI
        appState.startPoemCreation(type: newPoemType, topic: topic)
    }
    
    private func regeneratePoem() {
        isRegenerating = true
        
        Task {
            do {
                try await chatService.regeneratePoem(for: request)
                isRegenerating = false
            } catch {
                isRegenerating = false
                appState.showCloudKitError("Failed to regenerate poem: \(error.localizedDescription)")
            }
        }
    }
    
    private func favoriteRequest() {
        Task {
            do {
                try await dataManager.toggleFavorite(for: request)
            } catch {
                print("❌ Failed to toggle favorite: \(error)")
                appState.showCloudKitError("Failed to update favorite status")
            }
        }
    }
    
    private func copyToClipboard() {
        guard let content = response?.content,
              let topic = request.userInput else { return }
        
        UIPasteboard.general.string = formatPoemForSharing(
            content: content,
            topic: topic,
            type: poemType
        )
        
        // Provide feedback
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    private func resolveConflict() {
        guard let requestId = request.id else { return }
        
        // Show conflict resolution UI
        appState.showSyncConflicts(items: [
            (local: request, remote: request, recordId: requestId)
        ])
    }
    
    private func deletePoem() {
        Task {
            do {
                try await dataManager.deleteRequest(request)
            } catch {
                appState.showCloudKitError("Failed to delete poem: \(error.localizedDescription)")
            }
        }
    }
    
    @ViewBuilder
    private func actionSheetContent() -> some View {
        NavigationView {
            List {
                Section("Poem Information") {
                    if let poemType = poemType {
                        LabeledContent("Type", value: poemType.name)
                    }
                    
                    if let createdDate = request.createdAt {
                        LabeledContent("Created", value: createdDate.formatted())
                    }
                    
                    if let wordCount = response?.content?.split(separator: " ").count {
                        LabeledContent("Word Count", value: "\(wordCount)")
                    }
                }
                
                Section("Sync Status") {
                    HStack {
                        Text("Status")
                        Spacer()
                        syncStatusBadge()
                    }
                    
                    if let lastModified = request.lastModified {
                        LabeledContent("Last Modified", value: lastModified.formatted())
                    }
                }
            }
            .navigationTitle("Poem Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingActionSheet = false
                    }
                }
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    let mockRequest = RequestEnhanced(
        userInput: "sunset over mountains",
        userTopic: "sunset over mountains",
        poemType: PoemType.all[0],
        temperature: Temperature.all[0]
    )
    
    let mockResponse = ResponseEnhanced(
        requestId: mockRequest.id,
        userId: "preview",
        content: """
        Golden fire descends
        Mountain peaks embrace the light
        Day becomes memory
        """,
        role: "assistant",
        isFavorite: false
    )
    
    mockRequest.responseId = mockResponse.id
    mockRequest.syncStatus = .synced
    mockResponse.syncStatus = .synced
    
    return ScrollView {
        VStack {
            PoemCardView(request: mockRequest)
                .padding(.vertical)
        }
    }
    .background(Color(.systemGroupedBackground))
}
