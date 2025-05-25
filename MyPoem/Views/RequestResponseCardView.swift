// MyPoem/Views/RequestResponseCardView.swift
import SwiftUI
import SwiftData

struct RequestResponseCardView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var chatService: ChatService
    @EnvironmentObject private var poemFilterSettings: PoemFilterSettings
    @EnvironmentObject private var appUiSettings: AppUiSettings
    @ObservedObject var request: Request
    
    // MARK: - Animation State
    @State private var isCardAnimating: Bool = false
    @State private var showCardContent: Bool = false
    @State private var isResponseExpanded: Bool = false
    @State private var fullTextHeight: CGFloat = .zero
    @State private var collapsedTextHeight: CGFloat = .zero
    @State private var showExpandCollapseButton: Bool = false
    @State private var showingActionSheet: Bool = false
    @State private var wasRecentlyTapped: Bool = false
    
    private let collapsedLineLimit = 6 // Reduced for better mobile experience
    private let heightComparisonFudgeFactor: CGFloat = 8.0
    
    // MARK: - Styling Constants
    private struct Design {
        static let cardCornerRadius: CGFloat = 16
        static let cardPadding: CGFloat = 12
        static let headerSpacing: CGFloat = 18
        static let contentSpacing: CGFloat = 16
        static let buttonSize: CGFloat = 42 // Larger touch targets
        static let iconSize: CGFloat = 20
        static let shadowRadius: CGFloat = 8
        static let animationDuration: Double = 0.35
    }
    
    private struct DesignOriginal {
        static let cardCornerRadius: CGFloat = 16
        static let cardPadding: CGFloat = 12
        static let headerSpacing: CGFloat = 18
        static let contentSpacing: CGFloat = 16
        static let buttonSize: CGFloat = 42 // Larger touch targets
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
        .onChange(of: request.response) { newResp in
            handleResponseChange(newResp)
        }
        .sheet(isPresented: $showingActionSheet) {
            actionSheetContent()
        }
    }
    
    private func provideTapFeedback() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Visual feedback
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
    
    // MARK: - Background
    private var cardBackgroundAlt: some View {
        RoundedRectangle(cornerRadius: Design.cardCornerRadius)
            .fill(
                  Color(.secondarySystemBackground))
            
            .overlay(
                        // Inner shadow - only this animates
                        RoundedRectangle(cornerRadius: Design.cardCornerRadius - 2)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(wasRecentlyTapped ? 0.06 : 0.0),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .allowsHitTesting(false)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: wasRecentlyTapped)
                    )
                    .shadow(color: .black.opacity(0.08), radius: Design.shadowRadius, x: 0, y: 0)
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
        if appUiSettings.cardDisplayContext == CardDisplayContext.fullInteractive {
            requestTypeChipInteractive()
        } else {
            requestTypeChipTypeFiltered()
        }
    }
    
    @ViewBuilder
    private func requestTypeChipInteractive() -> some View {
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
    
    @ViewBuilder
    private func requestTypeChipTypeFiltered() -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(poemTypeColor)
                .frame(width: 8, height: 8)
            
            Text(request.poemType.name)
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground))
        .clipShape(Capsule())
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
            
            if request.response != nil {
                Button(action: { favoriteRequest(request: request) }) {
                    Image(systemName: request.response?.isFavorite == true ? "heart.fill" : "heart")
                        .font(.system(size: Design.iconSize, weight: .medium))
                        .foregroundColor(request.response?.isFavorite == true ? .red : .secondary)
                        .frame(width: Design.buttonSize, height: Design.buttonSize)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .scaleEffect(request.response?.isFavorite == true ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: request.response?.isFavorite)
            }
        }
    }
    
    // MARK: - Response Section
    @ViewBuilder
    private func responseSection() -> some View {
        if let response = request.response {
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
    private func responseContent(for response: Response) -> some View {
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
                //.animation(.easeInOut(duration: 0.1), value: isResponseExpanded) // Shorter, smoother animation
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
            //.foregroundColor(.accentColor)
            .foregroundColor(expandButtonColor)
            .padding(.horizontal, 10)
            //.frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(expandButtonColor.opacity(0.1))
            //.background(Color.accentColor.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 8)
    }
    
    private var expandButtonColor: Color {
        if appUiSettings.cardDisplayContext == CardDisplayContext.typeFiltered {
            return poemTypeColor
        } else {
            return .gray
        }
    }
    
    @ViewBuilder
    private func responseFooter(_ response: Response) -> some View {
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
            
            // Action sheet content would go here
            
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
    
    private func handleResponseChange(_ newResponse: Response?) {
        guard let response = newResponse else { return }
        
        if response.hasAnimated {
            isResponseExpanded = false
            DispatchQueue.main.async {
                updateExpandButtonVisibility()
            }
            return
        }
        
        startCardAppearAnimation(response)
    }
    
    private func startCardAppearAnimation(_ response: Response) {
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
                
                guard let context = request.modelContext else { return }
                context.insert(response)
                do { try context.save() } catch {
                    print("Failed to save response after animation: \(error)")
                }
            }
        }
    }
    
    // MARK: - Actions
    private func resendRequest(request: Request, as newPoemType: PoemType? = nil) {
        let poemTypeToUse = newPoemType ?? request.poemType
        
        if let currentFilter = poemFilterSettings.activeFilter,
           poemTypeToUse.id != currentFilter.id {
            poemFilterSettings.resetFilter()
        }
        
        let newRequest = Request(
            userInput: request.userInput,
            userTopic: request.userTopic,
            poemType: poemTypeToUse,
            temperature: request.temperature
        )
        
        do {
            context.insert(newRequest)
            try context.save()
        } catch {
            print("Failed to save new request for resend: \(error)")
            return
        }
        
        Task { @MainActor in
            do {
                let response = try await chatService.send(request: newRequest)
                newRequest.response = response
                if response.modelContext == nil {
                    context.insert(response)
                }
                try context.save()
            } catch {
                print("Failed to send or save resent request/response: \(error)")
            }
        }
    }
    
    private func favoriteRequest(request: Request) {
        guard let response = request.response else { return }
        
        response.isFavorite.toggle()
        do {
            try context.save()
        } catch {
            print("Failed to save favorite status: \(error)")
        }
    }
}

// MARK: - Preview
#Preview("Request Response Cards") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Request.self, Response.self, configurations: config)
    let context = container.mainContext
    
    // Create sample data with different poem types and states
    let samples: [(PoemType, String, String, Bool)] = [
        (PoemType.all[0], "Write a haiku about mountains", "Silent peaks stand tall,\nSnow-capped guardians of time,\nClouds dance at their feet.", false),
        (PoemType.all[1], "Write a sonnet about love", "When passion's fire burns bright within the heart,\nAnd gentle whispers float upon the breeze,\nTwo souls unite, no force can tear apart\nThe bond that brings both spirit to its knees.\n\nIn moonlit gardens where the roses bloom,\nSweet promises are made beneath the stars,\nLove conquers all, dispelling doubt and gloom,\nHealing the deepest of emotional scars.", true),
        (PoemType.all[2], "Write a free verse poem about the ocean", "The endless ocean calls to me with ancient voices,\nWaves crash against the shore in thunderous applause,\nSalt spray dances in the morning light,\nEach droplet a tiny prism reflecting the sun's golden rays.\n\nI stand at the water's edge, feeling the sand between my toes,\nThe rhythmic pulse of tides marking time like a heartbeat,\nEndless blue stretching beyond the horizon,\nWhere sky meets sea in a seamless embrace.", false),
        (PoemType.all[3], "Write a limerick about cats", "There once was a cat from Peru,\nWho dreamed of sailing the blue,\nHe built a small boat,\nBut it wouldn't float,\nSo he napped in the sun, as cats do.", true),
        (PoemType.all[4], "Write a ballad about a journey", "Upon a road both long and winding,\nA traveler set forth one day,\nWith hope and dreams forever binding,\nHis heart to find a better way.", false)
    ]
    
    // Create a thinking request (no response yet)
    let thinkingRequest = Request(
        userInput: "Write a haiku about rain",
        userTopic: "rain",
        poemType: PoemType.all[0],
        temperature: Temperature.all[0]
    )
    
    for (index, (poemType, userInput, content, isFavorite)) in samples.enumerated() {
        let request = Request(
            userInput: userInput,
            userTopic: userInput.replacingOccurrences(of: "Write a \\w+ (about|to) ", with: "", options: .regularExpression),
            poemType: poemType,
            temperature: Temperature.all[index % Temperature.all.count]
        )
        
        let response = Response(
            userId: "preview-user",
            content: content,
            role: "assistant",
            isFavorite: isFavorite,
            request: request,
            hasAnimated: true
        )
        
        request.response = response
        context.insert(request)
        context.insert(response)
    }
    
    // Insert thinking request
    context.insert(thinkingRequest)
    
    try! context.save()
    
    // Create mock services
    let chatService = ChatService(context: context)
    let poemFilterSettings = PoemFilterSettings()
    let appUiSettings = AppUiSettings()
    
    return ScrollView {
        LazyVStack(spacing: 16) {
            // Thinking card
            RequestResponseCardView(request: thinkingRequest)
            
            // Various poem cards
            ForEach(samples.indices, id: \.self) { index in
                if let request = try? container.mainContext.fetch(FetchDescriptor<Request>())[safe: index] {
                    RequestResponseCardView(request: request)
                }
            }
        }
        .padding(.vertical)
    }
    .modelContainer(container)
    .environmentObject(chatService)
    .environmentObject(poemFilterSettings)
    .environmentObject(appUiSettings)
    .background(Color(.systemGroupedBackground))
    .onAppear {
        appUiSettings.setCardDisplayContext(displayContext: .fullInteractive)
    }
}

//#Preview("Type Filtered Cards") {
//    let config = ModelConfiguration(isStoredInMemoryOnly: true)
//    let container = try! ModelContainer(for: Request.self, Response.self, configurations: config)
//    let context = container.mainContext
//    
//    // Create haiku-only samples for type filtered view
//    let haikuSamples: [(String, String, Bool)] = [
//        ("mountains", "Silent peaks stand tall,\nSnow-capped guardians of time,\nClouds dance at their feet.", false),
//        ("ocean waves", "Waves crash on the shore,\nEndless rhythm of the sea,\nPeace in every sound.", true),
//        ("cherry blossoms", "Pink petals flutter,\nSpring's gentle promise unfolds,\nBeauty brief but true.", false)
//    ]
//    
//    for (topic, content, isFavorite) in haikuSamples {
//        let request = Request(
//            userInput: "Write a haiku about \(topic)",
//            userTopic: topic,
//            poemType: PoemType.all[0], // Haiku
//            temperature: Temperature.all[0]
//        )
//        
//        let response = Response(
//            userId: "preview-user",
//            content: content,
//            role: "assistant",
//            isFavorite: isFavorite,
//            request: request,
//            hasAnimated: true
//        )
//        
//        request.response = response
//        context.insert(request)
//        context.insert(response)
//    }
//    
//    try! context.save()
//    
//    let chatService = ChatService(context: context)
//    let poemFilterSettings = PoemFilterSettings()
//    let appUiSettings = AppUiSettings()
//    
//    return ScrollView {
//        LazyVStack(spacing: 16) {
//            ForEach(container.mainContext.fetch(FetchDescriptor<Request>()), id: \.id) { request in
//                RequestResponseCardView(request: request)
//            }
//        }
//        .padding(.vertical)
//    }
//    .modelContainer(container)
//    .environmentObject(chatService)
//    .environmentObject(poemFilterSettings)
//    .environmentObject(appUiSettings)
//    .background(Color(.systemGroupedBackground))
//    .onAppear {
//        appUiSettings.setCardDisplayContext(displayContext: .typeFiltered)
//    }
//}

//#Preview("Single Card - Expanded") {
//    let config = ModelConfiguration(isStoredInMemoryOnly: true)
//    let container = try! ModelContainer(for: Request.self, Response.self, configurations: config)
//    let context = container.mainContext
//    
//    let request = Request(
//        userInput: "Write a free verse poem about a starry night",
//        userTopic: "starry night",
//        poemType: PoemType.all[2], // Free verse
//        temperature: Temperature.all[1]
//    )
//    
//    let longResponse = Response(
//        userId: "preview-user",
//        content: """
//        In the velvet darkness above us,
//        Stars twinkle like scattered diamonds,
//        Each one holding ancient secrets,
//        Whispers of distant galaxies,
//        Stories older than memory itself.
//        
//        The moon hangs like a silver lantern,
//        Casting ethereal shadows below,
//        While night creatures sing their lullabies,
//        And the world settles into peaceful slumber.
//        
//        Here beneath this cosmic tapestry,
//        I am reminded of my place,
//        Small yet significant,
//        Connected to the infinite dance
//        Of light and darkness,
//        Time and space,
//        Dreams and reality.
//        """,
//        role: "assistant",
//        isFavorite: true,
//        request: request,
//        hasAnimated: true
//    )
//    
//    request.response = longResponse
//    context.insert(request)
//    context.insert(longResponse)
//    
//    try! context.save()
//    
//    let chatService = ChatService(context: context)
//    let poemFilterSettings = PoemFilterSettings()
//    let appUiSettings = AppUiSettings()
//    
//    return RequestResponseCardView(request: request)
//        .modelContainer(container)
//        .environmentObject(chatService)
//        .environmentObject(poemFilterSettings)
//        .environmentObject(appUiSettings)
//        .padding()
//        .background(Color(.systemGroupedBackground))
//        .onAppear {
//            appUiSettings.setCardDisplayContext(displayContext: .fullInteractive)
//        }
//}
//
//#Preview("Dark Mode Cards") {
//    let config = ModelConfiguration(isStoredInMemoryOnly: true)
//    let container = try! ModelContainer(for: Request.self, Response.self, configurations: config)
//    let context = container.mainContext
//    
//    let request = Request(
//        userInput: "Write a sonnet about moonlight",
//        userTopic: "moonlight",
//        poemType: PoemType.all[1], // Sonnet
//        temperature: Temperature.all[0]
//    )
//    
//    let response = Response(
//        userId: "preview-user",
//        content: "Silver streams of moonlight fall,\nThrough windowpanes of midnight blue,\nIlluminating one and all\nWith gentle light, forever true.",
//        role: "assistant",
//        isFavorite: false,
//        request: request,
//        hasAnimated: true
//    )
//    
//    request.response = response
//    context.insert(request)
//    context.insert(response)
//    
//    try! context.save()
//    
//    let chatService = ChatService(context: context)
//    let poemFilterSettings = PoemFilterSettings()
//    let appUiSettings = AppUiSettings()
//    
//    return RequestResponseCardView(request: request)
//        .modelContainer(container)
//        .environmentObject(chatService)
//        .environmentObject(poemFilterSettings)
//        .environmentObject(appUiSettings)
//        .padding()
//        .background(Color(.systemGroupedBackground))
//        .preferredColorScheme(.dark)
//        .onAppear {
//            appUiSettings.setCardDisplayContext(displayContext: .fullInteractive)
//        }
//}

// MARK: - Safe Array Extension for Preview
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

//// MARK: - Size Reading Extension
//extension View {
//    func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
//        background(
//            GeometryReader { geometry in
//                Color.clear
//                    .preference(key: SizePreferenceKey.self, value: geometry.size)
//            }
//        )
//        .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
//    }
//}
//
//struct SizePreferenceKey: PreferenceKey {
//    static var defaultValue: CGSize = .zero
//    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
//}
