// DataManager.swift - Updated for CloudKit
import Foundation
import SwiftData
import Observation
import CloudKit

@Observable
@MainActor
final class DataManager {
    // MARK: - Core Data Storage
    private(set) var requests: [RequestEnhanced] = []
    private(set) var responses: [ResponseEnhanced] = []
    private(set) var poemGroups: [PoemGroup] = []
    
    // MARK: - CloudKit Sync Status
    private(set) var unsyncedRequestsCount: Int = 0
    private(set) var unsyncedResponsesCount: Int = 0
    private(set) var lastSyncTime: Date?
    
    // MARK: - Performance Optimizations
    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private var isLoading = false
    @ObservationIgnored private var requestCache: [String: RequestEnhanced] = [:]
    @ObservationIgnored private var responseCache: [String: ResponseEnhanced] = [:]
    @ObservationIgnored private let syncManager: CloudKitSyncManager
    
    // MARK: - Computed Properties
    
    var sortedRequests: [RequestEnhanced] {
        requests.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
    }
    
    var favoriteRequests: [RequestEnhanced] {
        requests.filter { request in
            guard let response = response(for: request) else { return false }
            return response.isFavorite ?? false
        }
    }
    
    var hasUnsyncedChanges: Bool {
        unsyncedRequestsCount > 0 || unsyncedResponsesCount > 0
    }
    
    func requests(for poemType: PoemType) -> [RequestEnhanced] {
        requests.filter { $0.poemType?.id == poemType.id }
    }
    
    func requestCount(for poemType: PoemType) -> Int {
        requests.filter { $0.poemType?.id == poemType.id }.count
    }
    
    func mostRecentRequest(for poemType: PoemType) -> RequestEnhanced? {
        requests
            .filter { $0.poemType?.id == poemType.id }
            .max { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) }
    }
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext, syncManager: CloudKitSyncManager) {
        self.modelContext = modelContext
        self.syncManager = syncManager
        
        Task {
            await loadData()
            await updateSyncCounts()
        }
        
        // Observe sync manager changes
        Task {
            await observeSyncChanges()
        }
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        isLoading = true
        
        do {
            // Fetch requests with sync status
            let requestDescriptor = FetchDescriptor<RequestEnhanced>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let fetchedRequests = try modelContext.fetch(requestDescriptor)
            
            // Fetch responses
            let responseDescriptor = FetchDescriptor<ResponseEnhanced>(
                sortBy: [SortDescriptor(\.dateCreated, order: .reverse)]
            )
            let fetchedResponses = try modelContext.fetch(responseDescriptor)
            
            // Fetch poem groups
            let groupDescriptor = FetchDescriptor<PoemGroup>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let fetchedGroups = try modelContext.fetch(groupDescriptor)
            
            // Update storage and build caches
            await MainActor.run {
                self.requests = fetchedRequests
                self.responses = fetchedResponses
                self.poemGroups = fetchedGroups
                self.rebuildCaches()
            }
            
            print("📊 DataManager: Loaded \(fetchedRequests.count) requests, \(fetchedResponses.count) responses")
            
        } catch {
            print("❌ Failed to load data: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - CloudKit Sync Support
    
    private func observeSyncChanges() async {
        // Monitor sync state changes
        withObservationTracking {
            _ = syncManager.syncState
            _ = syncManager.lastSyncDate
        } onChange: {
            Task { @MainActor in
                // Reload data after sync
                if self.syncManager.syncState == .idle {
                    await self.loadData()
                    self.lastSyncTime = self.syncManager.lastSyncDate
                }
                
                // Continue observing
                await self.observeSyncChanges()
            }
        }
    }
    
    private func updateSyncCounts() async {
        let unsyncedRequests = requests.filter { $0.syncStatus != .synced }
        let unsyncedResponses = responses.filter { $0.syncStatus != .synced }
        
        await MainActor.run {
            self.unsyncedRequestsCount = unsyncedRequests.count
            self.unsyncedResponsesCount = unsyncedResponses.count
        }
    }
    
    func triggerSync() async {
        await syncManager.syncNow()
    }
    
    // MARK: - Data Operations with CloudKit
    
    func createRequest(topic: String, poemType: PoemType, temperature: Temperature) async throws -> RequestEnhanced {
        let request = RequestEnhanced(
            userInput: topic,
            userTopic: topic,
            poemType: poemType,
            temperature: temperature
        )
        
        // Mark for sync
        request.syncStatus = .pending
        request.lastModified = Date()
        
        // Insert into context
        modelContext.insert(request)
        
        // Save to persistent storage
        try modelContext.save()
        
        // Update local storage
        await MainActor.run {
            self.requests.append(request)
            self.requestCache[request.id ?? ""] = request
            self.unsyncedRequestsCount += 1
        }
        
        print("✅ Created request: \(request.id ?? "unknown")")
        
        // Trigger background sync
        Task {
            await syncManager.syncNow()
        }
        
        return request
    }
    
    func saveResponse(_ response: ResponseEnhanced) async throws {
        guard let requestId = response.requestId,
              let request = requestCache[requestId] else {
            throw DataError.requestNotFound(response.requestId ?? "nil")
        }
        
        // Mark for sync
        response.syncStatus = .pending
        response.lastModified = Date()
        
        // Insert into context
        modelContext.insert(response)
        
        // Update request with response ID
        request.responseId = response.id
        request.lastModified = Date()
        
        // Save to persistent storage
        try modelContext.save()
        
        // Update local storage
        await MainActor.run {
            self.responses.append(response)
            self.responseCache[requestId] = response
            self.unsyncedResponsesCount += 1
        }
        
        print("✅ Saved response for request: \(requestId)")
        
        // Trigger background sync
        Task {
            await syncManager.syncNow()
        }
    }
    
    func updateResponse(_ response: ResponseEnhanced) async throws {
        guard responses.contains(where: { $0.id == response.id }) else {
            throw DataError.responseNotFound(response.id ?? "nil")
        }
        
        // Mark for sync
        response.syncStatus = .pending
        response.lastModified = Date()
        
        // Save changes
        try modelContext.save()
        
        // Update cache
        await MainActor.run {
            if let requestId = response.requestId {
                self.responseCache[requestId] = response
            }
        }
        
        await updateSyncCounts()
        
        print("✅ Updated response: \(response.id ?? "unknown")")
        
        // Trigger sync
        Task {
            await syncManager.syncNow()
        }
    }
    
    func deleteRequest(_ request: RequestEnhanced) async throws {
        // Delete associated response first
        if let response = response(for: request) {
            modelContext.delete(response)
            await MainActor.run {
                self.responses.removeAll { $0.id == response.id }
                if let requestId = request.id {
                    self.responseCache.removeValue(forKey: requestId)
                }
            }
        }
        
        // Delete request
        modelContext.delete(request)
        try modelContext.save()
        
        // Update local storage
        await MainActor.run {
            self.requests.removeAll { $0.id == request.id }
            if let id = request.id {
                self.requestCache.removeValue(forKey: id)
            }
        }
        
        await updateSyncCounts()
        
        print("✅ Deleted request: \(request.id ?? "unknown")")
        
        // Note: CloudKit deletion will be handled by sync manager
        Task {
            await syncManager.syncNow()
        }
    }
    
    func toggleFavorite(for request: RequestEnhanced) async throws {
        guard let response = response(for: request) else {
            throw DataError.responseNotFound("No response for request \(request.id ?? "nil")")
        }
        
        response.isFavorite = !(response.isFavorite ?? false)
        try await updateResponse(response)
    }
    
    // MARK: - Query Methods
    
    func response(for request: RequestEnhanced) -> ResponseEnhanced? {
        guard let id = request.id else { return nil }
        return responseCache[id]
    }
    
    func request(withId id: String) -> RequestEnhanced? {
        requestCache[id]
    }
    
    func hasResponse(for request: RequestEnhanced) -> Bool {
        guard let id = request.id else { return false }
        return responseCache[id] != nil
    }
    
    // MARK: - Conflict Resolution
    
    func resolveConflict(for itemId: String, strategy: ConflictStrategy) async {
        await syncManager.resolveConflict(for: itemId, strategy: strategy)
        await loadData() // Reload after conflict resolution
    }
    
    // MARK: - Cache Management
    
    private func rebuildCaches() {
        requestCache.removeAll()
        responseCache.removeAll()
        
        // Build request cache
        for request in requests {
            if let id = request.id {
                requestCache[id] = request
            }
        }
        
        // Build response cache with request ID as key for quick lookup
        for response in responses {
            if let requestId = response.requestId {
                responseCache[requestId] = response
            }
        }
    }
    
    // MARK: - Bulk Operations
    
    func clearAllData() async throws {
        // Delete all responses
        for response in responses {
            modelContext.delete(response)
        }
        
        // Delete all requests
        for request in requests {
            modelContext.delete(request)
        }
        
        // Delete all groups
        for group in poemGroups {
            modelContext.delete(group)
        }
        
        // Save changes
        try modelContext.save()
        
        // Clear local storage
        await MainActor.run {
            self.requests.removeAll()
            self.responses.removeAll()
            self.poemGroups.removeAll()
            self.rebuildCaches()
        }
        
        print("🗑️ Cleared all data")
    }
    
    // MARK: - Export/Import for CloudKit Migration
    
    func exportDataForCloudKit() async throws -> (requests: [RequestEnhanced], responses: [ResponseEnhanced], groups: [PoemGroup]) {
        return (requests, responses, poemGroups)
    }
    
    func markAllForSync() async throws {
        // Mark all items as pending sync
        for request in requests {
            request.syncStatus = .pending
            request.lastModified = Date()
        }
        
        for response in responses {
            response.syncStatus = .pending
            response.lastModified = Date()
        }
        
        for group in poemGroups {
            group.syncStatus = .pending
            group.lastModified = Date()
        }
        
        try modelContext.save()
        await updateSyncCounts()
        
        print("📤 Marked all data for sync")
    }
    
    #if DEBUG
    func createSampleData() async throws {
        let sampleTopics = [
            "sunset over mountains",
            "morning coffee ritual",
            "rain on windows",
            "childhood memories",
            "ocean waves at dawn"
        ]
        
        for (index, topic) in sampleTopics.enumerated() {
            let poemType = PoemType.all[index % PoemType.all.count]
            let request = try await createRequest(
                topic: topic,
                poemType: poemType,
                temperature: Temperature.all[0]
            )
            
            // Create a mock response
            let response = ResponseEnhanced(
                requestId: request.id,
                userId: "sample",
                content: "This is a beautiful \(poemType.name) about \(topic)",
                role: "assistant",
                isFavorite: index % 2 == 0
            )
            
            try await saveResponse(response)
        }
        
        print("🧪 Created sample data")
    }
    #endif
}

// MARK: - Error Types

enum DataError: LocalizedError {
    case requestNotFound(String)
    case responseNotFound(String)
    case invalidInput(String)
    
    var errorDescription: String? {
        switch self {
        case .requestNotFound(let id):
            return "Request not found: \(id)"
        case .responseNotFound(let id):
            return "Response not found: \(id)"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        }
    }
}
