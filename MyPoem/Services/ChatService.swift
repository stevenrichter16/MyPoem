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
    
    // MARK: - Recent Generation Memory
    @ObservationIgnored private var recentGenerations: [(type: String, keyPhrases: [String], timestamp: Date)] = []
    @ObservationIgnored private let maxRecentMemory = 10 // Keep last 10 generations
    @ObservationIgnored private let memoryWindowHours: TimeInterval = 2.0 // Remember for 2 hours
    
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
        
        // Update generation metrics
        updateGenerationMetrics()
        
        // Mark creation as complete in AppState
        await appState?.finishPoemCreation()
        
        print("✅ Poem generation completed successfully")
    }
    
    private nonisolated func generatePoem(type: PoemType, topic: String, variationId: String? = nil, temperature: Temperature, suggestions: String? = nil, config: AppConfiguration) async throws -> String {
        // Get the variation to use
        let variation = type.variation(withId: variationId)
        
        // Build anti-AI instructions to avoid generic AI poetry
        let antiAIInstructions = """
        
        CRITICAL: Avoid these AI-generated poetry clichés at all costs:
        - 'whispers of', 'echoes through', 'dance of light', 'tapestry of', 'symphony of', 'embrace of'
        - Generic references to 'golden hues', 'emerald seas', 'azure skies', 'crimson sunsets'
        - Abstract generalizations instead of concrete, specific details
        - Forced rhymes or artificial-sounding meter
        - Overly flowery or 'poetic' language that no real person would use
        
        Instead:
        - Write with authentic human voice and subtle imperfections
        - Use specific, concrete imagery from real observation
        - Let natural speech patterns guide the rhythm
        - Include unexpected word choices that feel fresh
        - Show don't tell - use precise details not abstract concepts
        """
        
        // Get dynamic poet persona based on variation
        let poetPersona = getPoetPersona(for: type, variation: variation)
        
        // Get rhythm guidance for the poem type
        let rhythmGuidance = getRhythmGuidance(for: type)
        
        // Get concreteness cues to ground the imagery
        let concretenessCues = getConcretenessCues(for: topic)
        
        // Get recent imagery to avoid repetition
        let recentImageryWarning = await getRecentImageryWarning(for: type)
        
        // Build the system prompt with dynamic persona and guidance
        let systemPrompt = """
        \(poetPersona)
        
        \(rhythmGuidance)
        
        \(concretenessCues)
        
        \(recentImageryWarning)
        
        \(antiAIInstructions)
        """
        
        // Build user prompt with variation prompt and suggestions
        var userPrompt = variation.prompt.replacingOccurrences(of: "{TOPIC}", with: topic)
        
        // Add user suggestions if provided
        if let suggestions = suggestions, !suggestions.isEmpty {
            userPrompt += "\n\nAdditional instructions from the user:\n\(suggestions)"
        }
        
        // Apply proven temperature adjustments for specific poem types
        let temperatureMultiplier: Double = {
            switch type.id {
            case "haiku": return 0.85      // Precision and constraint benefit from lower temp
            case "sonnet": return 0.9       // Formal structure needs some control
            case "limerick": return 1.1     // Wordplay and humor benefit from higher temp
            case "freeverse": return 1.05   // Creative freedom benefits from slight increase
            default: return 1.0             // Ode and ballad work well at base temperature
            }
        }()
        
        let adjustedTemperature = temperature.value * temperatureMultiplier
        
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
            
            // Track key phrases from this generation
            await MainActor.run {
                self.trackRecentGeneration(type: type, content: generatedContent)
            }
            
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
        
        // DISABLED: Revision creation for debugging
        /*
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
        */
        
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
            
            // DISABLED: Revision creation for debugging
            /*
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
            */
        
        print("✅ Poem regenerated for request: \(request.id ?? "unknown")")
    }
    
    // MARK: - Prompt Building Helpers
    
    private nonisolated func getPoetPersona(for type: PoemType, variation: PoemTypeVariation) -> String {
        // Create dynamic personas based on poem type and variation
        switch type.id {
        case "haiku":
            switch variation.id {
            case "traditional":
                return "You are a contemplative poet in the tradition of Basho and Issa, finding profound meaning in small moments. Your voice is quiet but penetrating, noticing what others overlook."
            case "emotional":
                return "You write with the sensitivity of someone who feels deeply but speaks sparingly. Your haikus capture emotional truths through precise, understated imagery."
            case "modern":
                return "You're a contemporary observer who finds poetry in urban life, technology, and modern experience. Your voice is fresh and current while honoring haiku's essence."
            default:
                return "You craft haikus with the precision of a jeweler, where every syllable matters and silence speaks as loudly as words."
            }
            
        case "freeverse":
            switch variation.id {
            case "flowing":
                return "You write like someone thinking out loud, letting thoughts flow naturally onto the page. Your voice is conversational yet lyrical, like a friend sharing something important."
            case "fragmented":
                return "You're an experimental poet who uses white space and line breaks as instruments. Your voice fractures and reassembles meaning in surprising ways."
            case "voice-driven":
                return "You have a distinctive speaking voice that comes through in every line. You write like you talk - with personality, quirks, and authentic human rhythms."
            default:
                return "You're a contemporary free verse poet who values authentic expression over artificial beauty. Your voice is clear, direct, and emotionally honest."
            }
            
        case "sonnet":
            switch variation.id {
            case "shakespearean":
                return "You write with the wit and wordplay of an Elizabethan poet updated for modern times. Your voice balances formal skill with emotional accessibility."
            case "modern":
                return "You're a contemporary sonneteer who respects tradition while breaking new ground. Your voice is both classical and current, formal yet intimate."
            default:
                return "You craft sonnets with architectural precision, building arguments that resolve in surprising ways. Your voice combines intellectual rigor with emotional depth."
            }
            
        case "limerick":
            return "You're a playful wordsmith with a gift for rhythm and unexpected rhymes. Your voice is mischievous but clever, finding humor in language itself."
            
        case "ode":
            switch variation.id {
            case "personal":
                return "You write odes like love letters to the world, with intimate knowledge and genuine affection. Your voice is warm, specific, and deeply appreciative."
            case "playful":
                return "You celebrate the ordinary with wit and wonder, finding profound joy in simple things. Your voice is enthusiastic but never naive."
            default:
                return "You're a poet of celebration who sees the extraordinary in everything. Your voice lifts subjects up without losing sight of their reality."
            }
            
        case "ballad":
            return "You're a storyteller at heart, weaving narratives that feel both timeless and immediate. Your voice carries the weight of tradition while speaking to now."
            
        default:
            return "You're a skilled contemporary poet who writes with authentic voice and fresh perspective, avoiding clichés and generic 'poetic' language."
        }
    }
    
    private nonisolated func getRhythmGuidance(for type: PoemType) -> String {
        switch type.id {
        case "haiku":
            return """
            RHYTHM: Follow the 5-7-5 syllable pattern naturally. Don't force words to fit - let the constraint guide you to more precise language. The rhythm should feel like breathing: inhale (5), pause (7), exhale (5).
            """
            
        case "sonnet":
            return """
            RHYTHM: Write in iambic pentameter (da-DUM da-DUM da-DUM da-DUM da-DUM) but let it flow naturally. Don't force the meter - occasional variations keep it human. The rhythm should support meaning, not dominate it.
            """
            
        case "limerick":
            return """
            RHYTHM: Keep the bouncy anapestic meter (da-da-DUM) that makes limericks fun to read aloud. Lines 1, 2, and 5 should have 3 beats; lines 3 and 4 have 2 beats. The rhythm should gallop playfully.
            """
            
        case "ballad":
            return """
            RHYTHM: Use the traditional ballad meter (alternating lines of 8 and 6 syllables) but prioritize storytelling over strict counting. The rhythm should feel like a song someone would remember.
            """
            
        case "freeverse":
            return """
            RHYTHM: Let the natural rhythm of speech guide your line breaks. Use enjambment and caesura to control pacing. Short lines create urgency; long lines create flow. Make rhythm serve emotion.
            """
            
        case "ode":
            return """
            RHYTHM: Build momentum through repetition and parallel structures. Vary line lengths to create waves of enthusiasm. The rhythm should feel expansive and celebratory.
            """
            
        default:
            return "RHYTHM: Find the natural rhythm that serves your content. Don't force artificial patterns."
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
    
    private nonisolated func getRecentImageryWarning(for type: PoemType) async -> String {
        let recentPhrases = await MainActor.run {
            self.getRecentPhrasesForType(type.id)
        }
        
        guard !recentPhrases.isEmpty else {
            return "" // No recent generations to worry about
        }
        
        return """
        VARIETY WARNING: Recent \(type.name) poems have used these images/phrases:
        \(recentPhrases.joined(separator: ", "))
        
        Please avoid repeating these specific images and find fresh, unexpected alternatives.
        """
    }
    
    // MARK: - Recent Generation Tracking
    
    private func trackRecentGeneration(type: PoemType, content: String) {
        // Extract key phrases and imagery from the generated content
        let keyPhrases = extractKeyPhrases(from: content, poemType: type)
        
        // Add to recent generations
        recentGenerations.append((
            type: type.id,
            keyPhrases: keyPhrases,
            timestamp: Date()
        ))
        
        // Clean up old entries
        cleanupOldGenerations()
    }
    
    private func extractKeyPhrases(from content: String, poemType: PoemType) -> [String] {
        var phrases: [String] = []
        let lines = content.components(separatedBy: .newlines)
        
        // Common patterns to extract based on poem type
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines
            guard !trimmed.isEmpty else { continue }
            
            // For haikus, look for key imagery in each line
            if poemType.id == "haiku" {
                // Extract nouns and verb phrases that create imagery
                if trimmed.contains("breath") || trimmed.contains("breathing") {
                    phrases.append("breath/breathing imagery")
                }
                if trimmed.contains("candle") || trimmed.contains("flame") {
                    phrases.append("candle/flame imagery")
                }
                if trimmed.contains("shadow") {
                    phrases.append("shadow imagery")
                }
                if trimmed.contains("flicker") {
                    phrases.append("flickering")
                }
                // Look for specific sensory details
                let words = trimmed.lowercased().components(separatedBy: .whitespaces)
                for word in words {
                    if word.contains("soft") || word.contains("warm") || word.contains("cold") {
                        phrases.append("\(word) sensation")
                    }
                }
            } else {
                // For longer poems, track repeated metaphors or phrases
                if trimmed.count > 20 && trimmed.count < 50 {
                    // Look for metaphorical phrases
                    if trimmed.contains("like") || trimmed.contains("as") {
                        phrases.append(trimmed)
                    }
                }
            }
        }
        
        // Remove duplicates and limit to most significant
        return Array(Set(phrases)).prefix(5).map { $0 }
    }
    
    private func getRecentPhrasesForType(_ typeId: String) -> [String] {
        let cutoffTime = Date().addingTimeInterval(-memoryWindowHours * 3600)
        
        // Filter for recent generations of the same type
        let recentOfType = recentGenerations.filter { generation in
            generation.type == typeId && generation.timestamp > cutoffTime
        }
        
        // Collect all key phrases
        var allPhrases: [String] = []
        for generation in recentOfType {
            allPhrases.append(contentsOf: generation.keyPhrases)
        }
        
        // Count occurrences and return most common
        let phraseCounts = allPhrases.reduce(into: [:]) { counts, phrase in
            counts[phrase, default: 0] += 1
        }
        
        // Return phrases that appear more than once, sorted by frequency
        return phraseCounts
            .filter { $0.value > 1 }
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }
    
    private func cleanupOldGenerations() {
        let cutoffTime = Date().addingTimeInterval(-memoryWindowHours * 3600)
        
        // Remove old entries beyond the time window
        recentGenerations.removeAll { $0.timestamp < cutoffTime }
        
        // Keep only the most recent if we exceed max memory
        if recentGenerations.count > maxRecentMemory {
            recentGenerations = Array(recentGenerations.suffix(maxRecentMemory))
        }
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
