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
    
    @ObservationIgnored private var activeGenerationTask: Task<Void, Never>?
    private(set) var isGenerating: Bool = false
    private(set) var lastError: Error?
    
    // MARK: - Performance Tracking
    
    @ObservationIgnored private var generationStartTime: Date?
    private(set) var averageGenerationTime: TimeInterval = 0
    @ObservationIgnored private var generationCount: Int = 0
    
    // MARK: - Initialization
    
    init(dataManager: DataManager, appState: AppState, configuration: AppConfiguration = DefaultConfiguration()) {
        self.dataManager = dataManager
        self.appState = appState
        self.config = configuration
        
        // Set up reactive observation
        setupObservation()
    }
    
    // MARK: - Reactive Setup
    
    private func setupObservation() {
        Task {
            await observeAppStateChanges()
        }
    }
    
    private func observeAppStateChanges() async {
        while true {
            await withObservationTracking {
                // Check if there's an active creation that needs processing
                if let creation = appState?.poemCreation,
                   creation.isCreating,
                   !isGenerating {
                    // Found a new creation to process
                    Task {
                        await handlePoemCreation(creation)
                    }
                }
            } onChange: {
                // This closure is called when observed properties change
                // We'll re-run the observation
            }
            
            // Small delay to prevent tight loops
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
    
    // MARK: - Poem Generation
    
    private func handlePoemCreation(_ creation: AppState.PoemCreationInfo) async {
        // Prevent duplicate generation
        guard !isGenerating else { return }
        
        isGenerating = true
        lastError = nil
        generationStartTime = Date()
        
        print("🤖 Starting poem generation: \(creation.type.name) about '\(creation.topic)'")
        
        do {
            // Create the request in DataManager (with CloudKit support)
            let request = try await dataManager.createRequest(
                topic: creation.topic,
                poemType: creation.type,
                temperature: Temperature.all[0] // Default temperature
            )
            
            // Generate the poem
            let poemContent = try await generatePoem(
                type: creation.type,
                topic: creation.topic,
                temperature: Temperature.all[0]
            )
            
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
            
        } catch {
            lastError = error
            print("❌ Poem generation failed: \(error)")
            
            // Show error in UI
            await appState?.showCloudKitError("Failed to generate poem: \(error.localizedDescription)")
            
            // Cancel the creation on error
            await appState?.cancelPoemCreation()
        }
        
        isGenerating = false
    }
    
    private func generatePoem(type: PoemType, topic: String, temperature: Temperature) async throws -> String {
        // Build the prompt based on poem type
        let systemPrompt = """
        You are an award-winning poet with mastery over every poetic form. 
        Create beautiful, emotionally resonant poems that follow the exact 
        requirements of the requested form while incorporating vivid imagery 
        and thoughtful language.
        
        For \(type.name):
        - Follow the traditional structure and rules
        - Use concrete imagery and sensory details
        - Create emotional resonance
        - Ensure rhythmic flow appropriate to the form
        """
        
        let userPrompt = "\(type.prompt)\(topic)"
        
        // Call OpenAI (handling optional properties)
        print("About to call OpenAI...")
        print("Thread: \(Thread.current)")
        
        do {
            print("=== CALLING OPENAI CLIENT ===")
            let generatedContent = try await OpenAIClient.shared.chatCompletion(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                temperature: temperature.value,
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
        // Cancel any active generation
        activeGenerationTask?.cancel()
        
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
            temperature: temperature
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
                temperature: temperature
            )
        } catch {
            print("❌ Failed to generate poem in regeneratePoem")
            throw error
        }
        
        print("=== AFTER GENERATE POEM ===")
        print("Generated content length: \(poemContent.count) characters")
        print("🎨 Generated poem content: \(poemContent.prefix(50))...")
        
        // EXPERIMENT: Create new content string completely disconnected from async context
        let newContent = String(poemContent.map { $0 })  // Force character-by-character copy
        print("🔄 Created new content string: \(newContent.count) chars")
        
        // Update the response with new content
        existingResponse.content = newContent
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
    
    func cancelGeneration() {
        activeGenerationTask?.cancel()
        activeGenerationTask = nil
        isGenerating = false
        
        print("🛑 Generation cancelled")
    }
    
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
