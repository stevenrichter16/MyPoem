// MyPoem/Views/RequestResponseCardView.swift
import SwiftUI
import SwiftData

struct RequestResponseCardView: View {
    @EnvironmentObject private var dataManager: DataManager
    @EnvironmentObject private var chatService: ChatService
    @EnvironmentObject private var poemFilterSettings: PoemFilterSettings
    @EnvironmentObject private var appUiSettings: AppUiSettings
    @EnvironmentObject private var poemCreationState: PoemCreationState
    @ObservedObject var request: RequestEnhanced
    
    // MARK: - Animation State
    @State private var isCardAnimating: Bool = false
    @State private var showCardContent: Bool = false
    @State private var isResponseExpanded: Bool = false
    @State private var fullTextHeight: CGFloat = .zero
    @State private var collapsedTextHeight: CGFloat = .zero
    @State private var showExpandCollapseButton: Bool = false
    @State private var showingActionSheet: Bool = false
    @State private var wasRecentlyTapped: Bool = false
    
    // Context tracking
    @State private var isInBrowseContext: Bool = false
    
    // Track response state for animations
    @State private var lastResponseId: String? = nil
    
    private let collapsedLineLimit = 6
    private let heightComparisonFudgeFactor: CGFloat = 8.0
    
    // MARK: - Styling Constants
    private struct Design {
        static let cardCornerRadius: CGFloat = 16
        static let cardPadding: CGFloat = 12
        static let headerSpacing: CGFloat = 18
        static let contentSpacing: CGFloat = 16
        static let buttonSize: CGFloat = 42
        static let iconSize: CGFloat = 20
        static let shadowRadius: CGFloat = 8
        static let animationDuration: Double = 0.35
    }
    
    // MARK: - Timestamp Formatter
    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()
    
    // Computed property to get the response - this will update when DataManager changes
    private var response: ResponseEnhanced? {
        dataManager.response(for: request)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Design.contentSpacing) {
            requestSection()
            responseSection()
                .onTapGesture {
                    provideTapFeedback()
                    isResponseExpanded.toggle()
                }
        }
        .padding(Design.cardPadding)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Design.cardCornerRadius))
        .shadow(color: .black.opacity(0.08), radius: Design.shadowRadius, x: 0, y: 4)
        .padding(.horizontal, 16)
        // CRITICAL: Listen to DataManager changes
        .onReceive(dataManager.$lastResponseUpdate) { _ in
            handleDataManagerUpdate()
        }
        .onReceive(dataManager.$allResponses) { _ in
            handleDataManagerUpdate()
        }
        .onAppear {
            // Check if we're in browse context by looking at the current filter
            isInBrowseContext = poemFilterSettings.activeFilter != nil
        }
        .sheet(isPresented: $showingActionSheet) {
            actionSheetContent()
        }
    }
    
    // MARK: - Data Manager Update Handler
    private func handleDataManagerUpdate() {
        let currentResponse = dataManager.response(for: request)
        let currentResponseId = currentResponse?.id
        
        // Check if we got a new response
        if currentResponseId != lastResponseId {
            print("🔄 RequestResponseCardView: Response changed from \(lastResponseId ?? "nil") to \(currentResponseId ?? "nil")")
            
            if let newResponse = currentResponse, !newResponse.hasAnimated {
                print("🎬 Starting animation for new response: \(newResponse.id)")
                startCardAppearAnimation(newResponse)
            }
            
            lastResponseId = currentResponseId
        }
    }
    
    private func provideTapFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        wasRecentlyTapped = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            wasRecentlyTapped = false
        }
    }
    
    // MARK: - Background
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: Design.cardCornerRadius)
            .fill(Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: Design.cardCornerRadius)
                    .stroke(Color(.quaternaryLabel), lineWidth: 0.5)
            )
    }
    
    // MARK: - Request Section
    @ViewBuilder
    private func requestSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: Design.headerSpacing) {
                requestTypeChip()
                Spacer()
                requestActions()
            }
            
            Text(request.userInput)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
    }
    
    @ViewBuilder
    private func requestTypeChip() -> some View {
        // Always show interactive chip now
        Menu {
            ForEach(PoemType.all, id: \.self) { poemType in
                if poemType != request.poemType {
                    Button(action: { resendRequest(request: request, as: poemType) }) {
                        Label(poemType.name, systemImage: "arrow.clockwise")
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(poemTypeColor)
                    .frame(width: 8, height: 8)
                
                Text(request.poemType.name)
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
    
    private var poemTypeColor: Color {
        switch request.poemType.name.lowercased() {
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
            Button(action: { resendRequest(request: request) }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: Design.iconSize, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: Design.buttonSize, height: Design.buttonSize)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            if response != nil {
                Button(action: { favoriteRequest(request: request) }) {
                    Image(systemName: response?.isFavorite == true ? "heart.fill" : "heart")
                        .font(.system(size: Design.iconSize, weight: .medium))
                        .foregroundColor(response?.isFavorite == true ? .red : .secondary)
                        .frame(width: Design.buttonSize, height: Design.buttonSize)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .scaleEffect(response?.isFavorite == true ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: response?.isFavorite)
            }
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
        } else {
            thinkingIndicator()
        }
    }
    
    @ViewBuilder
    private func responseContent(for response: ResponseEnhanced) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            responseText(response.content)
            responseFooter(response)
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
                    Text(content)
                        .font(.body)
                        .lineSpacing(2)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: geometry.size.width)
                        .readSize { size in
                            if fullTextHeight != size.height {
                                fullTextHeight = size.height
                                updateExpandButtonVisibility()
                            }
                        }
                        .opacity(0),
                    alignment: .topLeading
                )
                .overlay(
                    Text(content)
                        .font(.body)
                        .lineSpacing(2)
                        .lineLimit(collapsedLineLimit)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: geometry.size.width)
                        .readSize { size in
                            if collapsedTextHeight != size.height {
                                collapsedTextHeight = size.height
                                updateExpandButtonVisibility()
                            }
                        }
                        .opacity(0),
                    alignment: .topLeading
                )
        }
    }
    
    @ViewBuilder
    private func expandCollapseButton() -> some View {
        Button(action: { isResponseExpanded.toggle() }) {
            HStack(spacing: 4) {
                Image(systemName: isResponseExpanded ? "chevron.up" : "chevron.down")
                    .font(.footnote)
            }
            .foregroundColor(.gray)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private func responseFooter(_ response: ResponseEnhanced) -> some View {
        HStack {
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(Self.timeFmt.string(from: response.dateCreated))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func thinkingIndicator() -> some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
                .tint(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Crafting your poem...")
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
    private func actionSheetContent() -> some View {
        VStack(spacing: 20) {
            Text("Poem Options")
                .font(.headline)
                .padding(.top)
            
            Button("Dismiss") {
                showingActionSheet = false
            }
            .padding(.bottom)
        }
        .presentationDetents([.medium])
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
                
                do {
                    try dataManager.save(response: response)
                    print("✅ Marked response as animated: \(response.id)")
                } catch {
                    print("❌ Failed to save response after animation: \(error)")
                }
            }
        }
    }
    
    // MARK: - Actions
    private func resendRequest(request: RequestEnhanced, as newPoemType: PoemType? = nil) {
        let poemTypeToUse = newPoemType ?? request.poemType
        
        // Check if we're changing poem type in browse context
        let isChangingTypeInBrowse = isInBrowseContext && newPoemType != nil && newPoemType != request.poemType
        
        // Only reset filter if we're in Create tab
        if !isInBrowseContext {
            if let currentFilter = poemFilterSettings.activeFilter,
               poemTypeToUse.id != currentFilter.id {
                poemFilterSettings.resetFilter()
            }
        }
        
        // Start loading indicator if changing type in browse
        if isChangingTypeInBrowse {
            poemCreationState.startCreatingPoem(type: poemTypeToUse, topic: request.userInput)
        }
        
        let newRequest = RequestEnhanced(
            userInput: request.userInput,
            userTopic: request.userTopic,
            poemType: poemTypeToUse,
            temperature: request.temperature
        )
        
        do {
            try dataManager.save(request: newRequest)
        } catch {
            print("Failed to save new request for resend: \(error)")
            if isChangingTypeInBrowse {
                poemCreationState.cancelCreation()
            }
            return
        }
        
        Task { @MainActor in
            do {
                let response = try await chatService.send(request: newRequest)
                print("✅ Successfully resent request and got response: \(response.id)")
                
                // Finish creation if we changed type in browse context
                if isChangingTypeInBrowse {
                    poemCreationState.finishCreatingPoem()
                }
            } catch {
                print("❌ Failed to send or save resent request/response: \(error)")
                if isChangingTypeInBrowse {
                    poemCreationState.cancelCreation()
                }
            }
        }
    }
    
    private func favoriteRequest(request: RequestEnhanced) {
        guard let response = dataManager.response(for: request) else { return }
        
        response.isFavorite.toggle()
        do {
            try dataManager.save(response: response)
            print("✅ Toggled favorite status for response: \(response.id)")
        } catch {
            print("❌ Failed to save favorite status: \(error)")
        }
    }
}
