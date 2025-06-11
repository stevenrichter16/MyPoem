// ChatService.swift - Updated for CloudKit
import Foundation
import Observation

@Observable
@MainActor
final class ChatService {
    // MARK: - Dependencies
    private let dataManager: DataManager
    private weak var appState: AppState?
    private let config: AppConfiguration
    
    // MARK: - State
    private(set) var isGenerating: Bool = false
    private(set) var lastError: Error?
    
    // MARK: - Performance Tracking
    @ObservationIgnored private var generationStartTime: Date?
    private(set) var averageGenerationTime: TimeInterval = 0
    @ObservationIgnored private var generationCount: Int = 0
    
    
    // MARK: - Initialization
    init(dataManager: DataManager, appState: AppState, configuration: AppConfiguration = DefaultConfiguration()) {
        print("in ChatService init")
        self.dataManager = dataManager
        self.appState = appState
        self.config = configuration
        
        // Set up reactive observation
        setupObservation()
    }
    
    deinit {
        observationTask?.cancel()
    }
    
    // MARK: - Reactive Setup
    
    @ObservationIgnored private var observationTask: Task<Void, Never>?
    @ObservationIgnored private var lastProcessedId: UUID?
    
    private func setupObservation() {
        observationTask = Task { [weak self] in
            while !Task.isCancelled {
                // Check if there's an active creation that needs processing
                if let self = self,
                   let creation = self.appState?.poemCreation,
                   creation.isCreating,
                   creation.id != self.lastProcessedId,
                   !self.isGenerating {
                    
                    print("🔍 Found new poem creation to process: \(creation.id)")
                    self.lastProcessedId = creation.id
                    
                    await MainActor.run {
                        self.isGenerating = true
                    }
                    
                    do {
                        try await self.handlePoemCreation(creation)
                    } catch {
                        await MainActor.run {
                            self.lastError = error
                        }
                        await self.appState?.showCloudKitError(error.localizedDescription)
                        await self.appState?.cancelPoemCreation()
                    }
                    
                    await MainActor.run {
                        self.isGenerating = false
                    }
                }
                
                // Small delay to prevent tight loops
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }
    
    // MARK: - Poem Generation
    
    private func handlePoemCreation(_ creation: AppState.PoemCreationInfo) async throws {
        generationStartTime = Date()
        
        let variation = creation.type.variation(withId: creation.variationId)
        print("🤖 Starting poem generation: \(creation.type.name) (\(variation.name)) about '\(creation.topic)'")
        
        // Create the request in DataManager (with CloudKit support)
        let request = try await dataManager.createRequest(
            topic: creation.topic,
            poemType: creation.type,
            poemVariationId: creation.variationId,
            temperature: Temperature.all[0], // Default temperature
            suggestions: creation.suggestions
        )
        
        // Generate the poem using the variation
        let poemContent = try await generatePoem(
            type: creation.type,
            topic: creation.topic,
            variationId: creation.variationId,
            temperature: Temperature.all[0],
            suggestions: creation.suggestions,
            mood: creation.mood,
            config: self.config
        )
        
        print("in ChatService.handlePoemCreation after generatePoem() call")
        
        // Create and save the response (will trigger CloudKit sync)
        let response = ResponseEnhanced(
            requestId: request.id,
            userId: "user",
            content: poemContent,
            role: "assistant",
            isFavorite: false
        )
        
        try await dataManager.saveResponse(response)
        
        // Create initial revision
        do {
            try await dataManager.createRevision(
                for: request,
                content: poemContent,
                changeNote: "Initial poem generation",
                changeType: .initial
            )
            print("📝 Created initial revision")
        } catch {
            print("⚠️ Failed to create initial revision: \(error)")
        }
        
        // Update generation metrics
        updateGenerationMetrics()
        
        // Mark creation as complete in AppState
        await appState?.finishPoemCreation()
        
        print("✅ Poem generation completed successfully")
    }
    
    private nonisolated func generatePoem(type: PoemType, topic: String, variationId: String? = nil, temperature: Temperature, suggestions: String? = nil, mood: Mood? = nil, config: AppConfiguration) async throws -> String {
        // Get the variation to use
        let variation = type.variation(withId: variationId)
        
        // Smarter anti-AI instructions based on actual patterns
        let antiAIInstructions = """
        
        AVOID these common AI poetry patterns:
        - Predictable emotional progressions (sad→hopeful, dark→light)
        - Overused nature metaphors for emotions (storms for anger, sunshine for joy)
        - Abstract concept + "of" + abstract concept ("tapestry of dreams", "symphony of souls")
        - Ending with uplifting universal truths or life lessons
        - Perfect resolution that ties everything up neatly
        
        INSTEAD:
        - End on an image, not an explanation
        - Use specific, unexpected details (not "a bird" but "a crow missing two tail feathers")
        - Let contradictions and complexity exist without resolution
        - Trust the reader to find meaning without stating it
        """
        
        // Get technical guidance for the poem form
        let technicalGuidance = getPoetPersona(for: type, variation: variation)
        
        // Get concreteness cues to ground the imagery
        let concretenessCues = getConcretenessCues(for: topic)
        
        // Get mood guidance if specified
        let moodGuidance = getMoodGuidance(for: mood)
        
        // Build the system prompt - cleaner and more focused
        let systemPrompt = """
        You are a contemporary poet who values authentic expression and precise craft.
        
        \(technicalGuidance)
        
        \(moodGuidance)
        
        \(concretenessCues)
        
        \(antiAIInstructions)
        """
        
        // Build user prompt with variation prompt and suggestions
        var userPrompt = variation.prompt.replacingOccurrences(of: "{TOPIC}", with: topic)
        
        // Add user suggestions if provided
        if let suggestions = suggestions, !suggestions.isEmpty {
            userPrompt += "\n\nAdditional instructions from the user:\n\(suggestions)"
        }
        
        // Use the temperature as selected by the user
        let adjustedTemperature = temperature.value
        
        // Call OpenAI (handling optional properties)
        print("About to call OpenAI...")
        print("Thread: \(Thread.current)")
        
        do {
            print("=== CALLING OPENAI CLIENT ===")
            let generatedContent = try await OpenAIClient.shared.chatCompletion(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                temperature: adjustedTemperature,
                model: config.openAIModel
            )
            print("=== RETURNED FROM OPENAI CLIENT ===")
            print("After Returning from OpenAI Chat Completion - \(generatedContent.prefix(50))...")
            print("Thread after OpenAI: \(Thread.current)")
            print("About to return from generatePoem")
            return generatedContent
        } catch {
            print("❌ OpenAI call failed in generatePoem: \(error)")
            throw error
        }
    }
    
    // MARK: - Manual Generation Methods
    
    func generatePoem(topic: String, type: PoemType, temperature: Temperature) async throws -> RequestEnhanced {
        isGenerating = true
        lastError = nil
        generationStartTime = Date()
        
        defer {
            isGenerating = false
        }
        
        // Create request (with CloudKit sync)
        let request = try await dataManager.createRequest(
            topic: topic,
            poemType: type,
            temperature: temperature
        )
        
        // Generate poem
        let poemContent = try await generatePoem(
            type: type,
            topic: topic,
            temperature: temperature,
            suggestions: nil,
            mood: nil,
            config: self.config
        )
        
        // Save response (with CloudKit sync)
        let response = ResponseEnhanced(
            requestId: request.id,
            userId: "user",
            content: poemContent,
            role: "assistant",
            isFavorite: false
        )
        
        try await dataManager.saveResponse(response)
        
        updateGenerationMetrics()
        
        return request
    }
    
    func regeneratePoem(for request: RequestEnhanced) async throws {
        print("🔄 regeneratePoem called on thread: \(Thread.current)")
        isGenerating = true
        lastError = nil
        
        defer {
            isGenerating = false
        }
        
        // Validate request has required data
        guard let poemType = request.poemType,
              let temperature = request.temperature,
              let topic = request.userTopic else {
            throw ChatServiceError.invalidRequest("Missing required data for regeneration")
        }
        
        // Create a revision of the current content before regenerating
        if let existingResponse = dataManager.response(for: request),
           let currentContent = existingResponse.content,
           !currentContent.isEmpty {
            do {
                // Save the current version as a revision
                try await dataManager.createRevision(
                    for: request,
                    content: currentContent,
                    changeNote: "Before AI regeneration",
                    changeType: .regeneration
                )
                print("📝 Created revision before regeneration")
            } catch {
                print("⚠️ Failed to create revision: \(error)")
                // Continue with regeneration even if revision fails
            }
        }
        
        print("in ChatService.regeneratePoem right before calling ChatService.generatePoem()")
        
        // Get the existing response first
        guard let existingResponse = dataManager.response(for: request) else {
            print("⚠️ No existing response found")
            throw ChatServiceError.invalidRequest("No response found for regeneration")
        }
        
        print("🔍 Found existing response to update: \(existingResponse.id ?? "unknown")")
        
        // Generate new poem
        print("=== BEFORE GENERATE POEM ===")
        let poemContent: String
        do {
            poemContent = try await generatePoem(
                type: poemType,
                topic: topic,
                temperature: temperature,
                suggestions: request.userSuggestions,
                mood: nil, // TODO: Store mood in request for regeneration
                config: self.config
            )
        } catch {
            print("❌ Failed to generate poem in regeneratePoem")
            throw error
        }
        
        print("=== AFTER GENERATE POEM ===")
        print("Generated content length: \(poemContent.count) characters")
        print("🎨 Generated poem content: \(poemContent.prefix(50))...")
        
        // Update the response with new content
        existingResponse.content = poemContent
        existingResponse.lastModified = Date()
        existingResponse.syncStatus = .pending
        
        print("💾 About to call updateResponse")
        try await dataManager.updateResponse(existingResponse)
        print("✅ updateResponse completed")
            
            // Create a revision for the new regenerated content
            do {
                try await dataManager.createRevision(
                    for: request,
                    content: poemContent,
                    changeNote: "AI regenerated poem",
                    changeType: .regeneration
                )
                print("📝 Created revision for regenerated content")
            } catch {
                print("⚠️ Failed to create revision for new content: \(error)")
            }
        
        print("✅ Poem regenerated for request: \(request.id ?? "unknown")")
    }
    
    // MARK: - Prompt Building Helpers
    
    private nonisolated func getPoetPersona(for type: PoemType, variation: PoemTypeVariation) -> String {
        // Minimal technical guidance focused on craft, not imposed voice
        switch type.id {
        case "haiku":
            return "Write a haiku in 5-7-5 syllables. Include a concrete image from nature or daily life. Create a subtle shift or juxtaposition between images (the 'cutting' effect). Avoid explaining or moralizing."
            
        case "freeverse":
            if variation.id == "fragmented" {
                return "Write in free verse using short, fragmented lines and strategic white space. Let gaps and silences carry meaning."
            }
            return "Write in free verse. Use line breaks purposefully to control pacing and emphasis. Let the form follow the content's natural rhythm."
            
        case "sonnet":
            switch variation.id {
            case "shakespearean":
                return "Write a 14-line Shakespearean sonnet in iambic pentameter (10 syllables per line, unstressed-stressed pattern). Follow ABAB CDCD EFEF GG rhyme scheme. Place the volta (turn) before the final couplet, which should reframe or resolve the poem."
            case "petrarchan":
                return "Write a 14-line Petrarchan sonnet. The octave (8 lines, ABBAABBA) presents a situation or question. The sestet (6 lines, CDECDE or CDCDCD) responds or resolves. Place the volta at line 9."
            default:
                return "Write a 14-line sonnet with a clear structural turn (volta). Maintain consistent meter and include a strong resolution in the final lines."
            }
            
        case "limerick":
            return "Write a limerick in anapestic meter (da-da-DUM). Lines 1, 2, and 5 have 3 beats; lines 3 and 4 have 2 beats. AABBA rhyme scheme. The final line should land with surprise or wit."
            
        case "ode":
            return "Write an ode using heightened language and specific sensory details. Build through accumulation of precise observations. Maintain genuine enthusiasm without empty superlatives."
            
        case "ballad":
            return "Write a ballad in quatrains (4-line stanzas). Use ballad meter: alternating lines of 8 and 6 syllables (8-6-8-6). Focus on narrative action and dialogue. Include a refrain if appropriate."
            
        default:
            return "Write with precision and authenticity. Focus on concrete imagery over abstract statements."
        }
    }
    
    
    private nonisolated func getMoodGuidance(for mood: Mood?) -> String {
        guard let mood = mood else {
            return "" // No mood specified, no guidance needed
        }
        
        switch mood.id {
        case "joyful":
            return "MOOD: Express genuine joy through specific, celebratory details. Avoid forced happiness - let joy emerge from precise observations."
        case "melancholic":
            return "MOOD: Capture quiet sadness through understated imagery. Avoid melodrama - let melancholy arise from careful, specific details."
        case "playful":
            return "MOOD: Use light, surprising language and unexpected connections. Keep playfulness natural, not forced or childish."
        case "contemplative":
            return "MOOD: Create space for thought through measured pacing and open-ended imagery. Avoid stating conclusions."
        case "passionate":
            return "MOOD: Express intensity through vivid, physical language. Let passion show in the urgency of images, not declarations."
        case "mysterious":
            return "MOOD: Use suggestive, atmospheric details that hint rather than explain. Create questions, not answers."
        case "nostalgic":
            return "MOOD: Evoke the past through specific sensory memories. Avoid sentimentality - let longing emerge from concrete details."
        default:
            return ""
        }
    }
    
    private nonisolated func getConcretenessCues(for topic: String) -> String {
        // Provide specific guidance to ground abstract topics in concrete details
        let topicLower = topic.lowercased()
        
        var cues = "CONCRETENESS: "
        
        // Check for abstract concepts and provide grounding suggestions
        if topicLower.contains("love") || topicLower.contains("happiness") || topicLower.contains("sadness") || 
           topicLower.contains("fear") || topicLower.contains("anger") || topicLower.contains("joy") {
            cues += "Ground this emotion in physical sensations and specific moments. What does it taste like? How does it change breathing? What small gesture reveals it?"
        } else if topicLower.contains("time") || topicLower.contains("memory") || topicLower.contains("future") || 
                   topicLower.contains("past") || topicLower.contains("change") {
            cues += "Anchor this abstract concept in tangible objects and specific scenes. Use worn objects, faded photographs, calendar pages, clock hands - things we can touch and see."
        } else if topicLower.contains("nature") || topicLower.contains("season") || topicLower.contains("weather") {
            cues += "Move beyond generic nature imagery. Name specific plants, describe exact weather conditions, capture particular moments of light. Make it feel like a real place at a real time."
        } else {
            cues += "Use specific, sensory details that readers can see, hear, touch, taste, or smell. Avoid abstract descriptions - show through concrete examples and precise observations."
        }
        
        cues += """
        
        
        Remember: Specificity is the soul of narrative. A 'bird' is forgettable; a 'crow with one white feather' stays in memory.
        """
        
        return cues
    }
    
    
    // MARK: - Metrics
    
    private func updateGenerationMetrics() {
        guard let startTime = generationStartTime else { return }
        
        let generationTime = Date().timeIntervalSince(startTime)
        generationCount += 1
        
        // Calculate running average
        averageGenerationTime = ((averageGenerationTime * Double(generationCount - 1)) + generationTime) / Double(generationCount)
        
        print("⏱️ Generation took \(String(format: "%.2f", generationTime))s (avg: \(String(format: "%.2f", averageGenerationTime))s)")
    }
    
    // MARK: - Utility Methods
    
    func clearError() {
        lastError = nil
    }
    
    // MARK: - Error Handling
    
    enum ChatServiceError: LocalizedError {
        case invalidRequest(String)
        case generationFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidRequest(let message):
                return "Invalid request: \(message)"
            case .generationFailed(let message):
                return "Generation failed: \(message)"
            }
        }
    }
    
    // MARK: - Debug Helpers
    
    #if DEBUG
    func simulateGeneration(type: PoemType, topic: String) async throws -> String {
        // Simulate network delay
        try await Task.sleep(for: .seconds(2))
        
        // Return mock poem
        return """
        [Mock \(type.name)]
        
        This is a beautifully crafted \(type.name)
        About the topic of \(topic)
        Generated for testing purposes
        With simulated AI brilliance
        
        - Generated at \(Date().formatted())
        """
    }
    #endif
}
