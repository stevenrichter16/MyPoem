//
//  DataManager.swift
//  MyPoem
//
//  Created by Steven Richter on 5/26/25.
//

import Combine
import Foundation
import SwiftData

// MARK: - ID-Based DataManager
// MARK: - Enhanced ID-Based DataManager
import SwiftData
import SwiftUI
import Combine

// MARK: - Enhanced ID-Based DataManager with Proper Notifications
@MainActor
class DataManager: ObservableObject {
    @Published var allRequests: [RequestEnhanced] = []
    @Published var allResponses: [ResponseEnhanced] = []
    @Published var allPoemGroups: [PoemGroup] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Add this to trigger view updates when responses change
    @Published var lastResponseUpdate: Date = Date()
    
    // MARK: - Private Properties
    var context: ModelContext
    private var cancellables = Set<AnyCancellable>()
    
    // Filtering state
    private var activeFilter: PoemType?
    
    // Caching
    private var poemTypeCountCache: [String: Int] = [:]
    private var mostRecentPoemCache: [String: RequestEnhanced] = [:]
    private var lastCacheUpdate: Date = .distantPast
    private let cacheExpirationInterval: TimeInterval = 30
    
    // MARK: - Initialization
    init(context: ModelContext) {
        self.context = context
        loadData()
    }
    
    // MARK: - Data Loading
    func loadData() {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load all three tables separately
            var requestDescriptor = FetchDescriptor<RequestEnhanced>()
            requestDescriptor.sortBy = [SortDescriptor(\RequestEnhanced.createdAt, order: .forward)]
            allRequests = try context.fetch(requestDescriptor)
            
            var responseDescriptor = FetchDescriptor<ResponseEnhanced>()
            responseDescriptor.sortBy = [SortDescriptor(\ResponseEnhanced.dateCreated, order: .forward)]
            allResponses = try context.fetch(responseDescriptor)
            
            var groupDescriptor = FetchDescriptor<PoemGroup>()
            groupDescriptor.sortBy = [SortDescriptor(\PoemGroup.createdAt, order: .forward)]
            allPoemGroups = try context.fetch(groupDescriptor)
            
            updateCache()
            print("📊 DataManager: Loaded \(allRequests.count) requests, \(allResponses.count) responses, \(allPoemGroups.count) groups")
        } catch {
            errorMessage = "Failed to load data: \(error.localizedDescription)"
            print("❌ DataManager: Failed to load data - \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Save Operations with Proper Notifications
    func save(request: RequestEnhanced) throws {
        context.insert(request)
        try context.save()
        
        // Update local array if not already present
        if !allRequests.contains(where: { $0.id == request.id }) {
            allRequests.append(request) // Insert at beginning for reverse chronological order
        }
        
        updateCache()
        
        // Trigger UI update
        objectWillChange.send()
    }
    
    func save(response: ResponseEnhanced) throws {
        context.insert(response)
        try context.save()
        
        // Update local array if not already present
        if !allResponses.contains(where: { $0.id == response.id }) {
            allResponses.append(response) // Insert at beginning for reverse chronological order
        }
        
        // Update the linked request's responseId if needed
        if let request = allRequests.first(where: { $0.id == response.requestId }) {
            if request.responseId != response.id {
                request.responseId = response.id
                // Save the updated request
                try context.save()
            }
        }
        
        updateCache()
        
        // CRITICAL: Trigger UI updates
        lastResponseUpdate = Date()
        objectWillChange.send()
        
        print("✅ DataManager: Saved response \(response.id) and triggered UI update")
    }
    
    func save(poemGroup: PoemGroup) throws {
        context.insert(poemGroup)
        try context.save()
        
        // Update local array if not already present
        if !allPoemGroups.contains(where: { $0.id == poemGroup.id }) {
            allPoemGroups.append(poemGroup)
        }
        
        updateCache()
        objectWillChange.send()
    }
    
    // MARK: - Delete Operations
    func delete(request: RequestEnhanced) throws {
        // Delete associated response first
        if let responseId = request.responseId,
           let response = allResponses.first(where: { $0.id == responseId }) {
            try delete(response: response)
        }
        
        context.delete(request)
        try context.save()
        
        // Remove from local array
        allRequests.removeAll { $0.id == request.id }
        updateCache()
        objectWillChange.send()
    }
    
    func delete(response: ResponseEnhanced) throws {
        context.delete(response)
        try context.save()
        
        // Remove from local array and update associated request
        allResponses.removeAll { $0.id == response.id }
        
        // Clear the responseId from the associated request
        if let request = allRequests.first(where: { $0.responseId == response.id }) {
            request.responseId = nil
            try context.save()
        }
        
        updateCache()
        lastResponseUpdate = Date()
        objectWillChange.send()
    }
    
    func delete(poemGroup: PoemGroup) throws {
        context.delete(poemGroup)
        try context.save()
        
        // Remove from local array
        allPoemGroups.removeAll { $0.id == poemGroup.id }
        updateCache()
        objectWillChange.send()
    }
    
    // MARK: - Query Operations
    /// Get response for a request
    func response(for request: RequestEnhanced) -> ResponseEnhanced? {
        guard let responseId = request.responseId else { return nil }
        return allResponses.first { $0.id == responseId }
    }
    
    /// Get request for a response
    func request(for response: ResponseEnhanced) -> RequestEnhanced? {
        return allRequests.first { $0.id == response.requestId }
    }
    
    /// Get requests filtered by poem type
    func requests(for poemType: PoemType) -> [RequestEnhanced] {
        return allRequests.filter { $0.poemType.id == poemType.id }
    }
    
    /// Get favorite requests
    func favoriteRequests() -> [RequestEnhanced] {
        return allRequests.filter { request in
            guard let responseId = request.responseId else { return false }
            return allResponses.first(where: { $0.id == responseId })?.isFavorite == true
        }
    }
    
    /// Get requests count for a poem type
    func requestCount(for poemType: PoemType) -> Int {
        if Date().timeIntervalSince(lastCacheUpdate) < cacheExpirationInterval,
           let cachedCount = poemTypeCountCache[poemType.id] {
            return cachedCount
        }
        
        let count = allRequests.filter { $0.poemType.id == poemType.id }.count
        poemTypeCountCache[poemType.id] = count
        return count
    }
    
    /// Get most recent request for a poem type
    func mostRecentRequest(for poemType: PoemType) -> RequestEnhanced? {
        if Date().timeIntervalSince(lastCacheUpdate) < cacheExpirationInterval,
           let cachedRequest = mostRecentPoemCache[poemType.id] {
            return cachedRequest
        }
        
        let recent = allRequests
            .filter { $0.poemType.id == poemType.id }
            .first // Already sorted by date descending
        
        mostRecentPoemCache[poemType.id] = recent
        return recent
    }
    
    func refreshData() {
        loadData()
    }
    
    private func updateCache() {
        updatePoemTypeCaches()
        lastCacheUpdate = Date()
    }
    
    private func updatePoemTypeCaches() {
        poemTypeCountCache.removeAll()
        mostRecentPoemCache.removeAll()
        
        for poemType in PoemType.all {
            let typeRequests = allRequests.filter { $0.poemType.id == poemType.id }
            poemTypeCountCache[poemType.id] = typeRequests.count
            mostRecentPoemCache[poemType.id] = typeRequests.first
        }
        
        lastCacheUpdate = Date()
    }
}

// MARK: - Request Model (No Relationships)
@Model
class RequestEnhanced: Identifiable, ObservableObject {
    @Attribute(.unique) var id: String
    var userInput: String
    var userTopic: String
    var poemType: PoemType
    var poemVariationId: String?
    var temperature: Temperature
    var createdAt: Date
    
    // Simple ID references instead of relationships
    var responseId: String?        // Links to Response
    var poemGroupId: String?       // Links to PoemGroup
    var parentRequestId: String?   // Links to parent Request for variations
    
    // Metadata for variations
    var isOriginal: Bool = true
    var variationNote: String?

    init(id: String = UUID().uuidString,
         userInput: String,
         userTopic: String,
         poemType: PoemType,
         poemVariationId: String? = nil,
         temperature: Temperature,
         createdAt: Date = .now,
         isOriginal: Bool = true,
         variationNote: String? = nil,
         parentRequestId: String? = nil) {
        self.id = id
        self.userInput = userInput
        self.userTopic = userTopic
        self.poemType = poemType
        self.poemVariationId = poemVariationId
        self.temperature = temperature
        self.createdAt = createdAt
        self.isOriginal = isOriginal
        self.variationNote = variationNote
        self.parentRequestId = parentRequestId
    }
    
//     Get the actual variation that was used
//    var usedVariation: PoemTypeVariation {
//        return poemType.variation(withId: poemVariationId)
//    }
}

// MARK: - Response Model (No Relationships)
@Model
class ResponseEnhanced {
    @Attribute(.unique) var id: String
    var requestId: String          // Simple ID reference to Request
    var userId: String
    var content: String
    var role: String
    var isFavorite: Bool
    var hasAnimated: Bool
    var dateCreated: Date

    init(id: String = UUID().uuidString,
         requestId: String,
         userId: String,
         content: String,
         role: String,
         isFavorite: Bool,
         hasAnimated: Bool = false,
         dateCreated: Date = .now) {
        self.id = id
        self.requestId = requestId
        self.userId = userId
        self.content = content
        self.role = role
        self.isFavorite = isFavorite
        self.hasAnimated = hasAnimated
        self.dateCreated = dateCreated
    }
}

// MARK: - PoemGroup Model (No Relationships)
@Model
class PoemGroup {
    @Attribute(.unique) var id: String
    var originalTopic: String
    var createdAt: Date
    
    init(id: String = UUID().uuidString, originalTopic: String) {
        self.id = id
        self.originalTopic = originalTopic
        self.createdAt = Date()
    }
}
