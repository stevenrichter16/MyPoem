// CloudKitSyncManager.swift
import Foundation
import CloudKit
import SwiftData
import Observation
import Network

@Observable
@MainActor
final class CloudKitSyncManager {
    // MARK: - Properties
    private(set) var syncState: SyncState = .idle
    private(set) var lastSyncDate: Date?
    private(set) var syncErrors: [SyncError] = []
    private(set) var pendingChangesCount: Int = 0
    
    // CloudKit components
    @ObservationIgnored private let container: CKContainer
    @ObservationIgnored private let privateDatabase: CKDatabase
    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private let networkMonitor = NWPathMonitor()
    @ObservationIgnored private let syncQueue = DispatchQueue(label: "com.mypoem.sync")
    
    // Network state
    private(set) var isConnected: Bool = true
    
    // Sync tokens for change tracking
    @ObservationIgnored private var serverChangeToken: CKServerChangeToken? {
        didSet {
            saveServerChangeToken()
        }
    }
    
    // MARK: - Initialization
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.container = CKContainer.default()
        self.privateDatabase = container.privateCloudDatabase
        
        setupNetworkMonitoring()
        loadServerChangeToken()
        
        Task {
            await checkiCloudAvailability()
            await performInitialSync()
        }
    }
    
    // MARK: - Public Methods
    
    /// Manually trigger a sync
    func syncNow() async {
        guard isConnected else {
            addSyncError(.noNetwork)
            return
        }
        
        await performSync()
    }
    
    /// Handle conflict resolution
    func resolveConflict(for recordId: String, strategy: ConflictStrategy) async {
        // Implementation for conflict resolution
        syncState = .resolvingConflicts
        
        do {
            switch strategy {
            case .keepLocal:
                try await keepLocalVersion(recordId: recordId)
            case .keepRemote:
                try await keepRemoteVersion(recordId: recordId)
            case .merge:
                try await mergeVersions(recordId: recordId)
            case .manual:
                // Present UI for manual resolution
                break
            }
            
            syncState = .idle
        } catch {
            addSyncError(.conflictResolution(error))
        }
    }
    
    // MARK: - Conflict Resolution Methods
    
    private func keepLocalVersion(recordId: String) async throws {
        // Find the local record
        let localRecord = try await findLocalRecord(recordId: recordId)
        
        // Convert to CKRecord and force save to CloudKit
        if let ckRecord = try await convertLocalToCKRecord(localRecord) {
            ckRecord["lastModified"] = Date() as CKRecordValue
            
            let operation = CKModifyRecordsOperation(
                recordsToSave: [ckRecord],
                recordIDsToDelete: nil
            )
            operation.savePolicy = .allKeys // Force overwrite remote
            
            try await privateDatabase.add(operation)
            
            // Mark as synced
            updateSyncStatus(for: recordId, status: .synced)
        }
    }
    
    private func keepRemoteVersion(recordId: String) async throws {
        // Fetch the remote record
        let recordID = CKRecord.ID(recordName: recordId, zoneID: defaultZoneID)
        let ckRecord = try await privateDatabase.record(for: recordID)
        
        // Update local with remote data
        if ckRecord.recordType == "Request" {
            try await processRequestRecord(ckRecord)
        } else if ckRecord.recordType == "Response" {
            try await processResponseRecord(ckRecord)
        } else if ckRecord.recordType == "PoemGroup" {
            try await processPoemGroupRecord(ckRecord)
        }
        
        // Mark as synced
        updateSyncStatus(for: recordId, status: .synced)
    }
    
    private func mergeVersions(recordId: String) async throws {
        // Fetch both versions
        let localRecord = try await findLocalRecord(recordId: recordId)
        let recordID = CKRecord.ID(recordName: recordId, zoneID: defaultZoneID)
        let remoteRecord = try await privateDatabase.record(for: recordID)
        
        // Merge based on record type
        if let request = localRecord as? RequestEnhanced {
            try await mergeRequestRecords(local: request, remote: remoteRecord)
        } else if let response = localRecord as? ResponseEnhanced {
            try await mergeResponseRecords(local: response, remote: remoteRecord)
        } else if let group = localRecord as? PoemGroup {
            try await mergePoemGroupRecords(local: group, remote: remoteRecord)
        }
    }
    
    private func findLocalRecord(recordId: String) async throws -> Any {
        // Try to find in each model type
        if let request = try modelContext.fetch(
            FetchDescriptor<RequestEnhanced>(
                predicate: #Predicate { $0.id == recordId }
            )
        ).first {
            return request
        }
        
        if let response = try modelContext.fetch(
            FetchDescriptor<ResponseEnhanced>(
                predicate: #Predicate { $0.id == recordId }
            )
        ).first {
            return response
        }
        
        if let group = try modelContext.fetch(
            FetchDescriptor<PoemGroup>(
                predicate: #Predicate { $0.id == recordId }
            )
        ).first {
            return group
        }
        
        throw SyncError.recordProcess(recordId, NSError(domain: "MyPoem", code: 404, userInfo: [NSLocalizedDescriptionKey: "Record not found"]))
    }
    
    private func convertLocalToCKRecord(_ localRecord: Any) async throws -> CKRecord? {
        if let request = localRecord as? RequestEnhanced {
            return try createCKRecord(from: request)
        } else if let response = localRecord as? ResponseEnhanced {
            return try createCKRecord(from: response)
        } else if let group = localRecord as? PoemGroup {
            return try createCKRecord(from: group)
        }
        return nil
    }
    
    private func mergeRequestRecords(local: RequestEnhanced, remote: CKRecord) async throws {
        // Merge strategy: Keep newer content, combine metadata
        let localDate = local.lastModified ?? Date.distantPast
        let remoteDate = remote["lastModified"] as? Date ?? Date.distantPast
        
        // Use newer content
        if remoteDate > localDate {
            // Update local with remote content
            updateRequest(local, from: remote)
        } else {
            // Keep local content, but update lastModified to trigger sync
            local.lastModified = Date()
        }
        
        // Always keep favorite status if either has it
        if let remoteFavorite = remote["isFavorite"] as? Bool, remoteFavorite {
            // Find associated response and mark as favorite
            if let responseId = local.responseId,
               let response = try modelContext.fetch(
                   FetchDescriptor<ResponseEnhanced>(
                       predicate: #Predicate { $0.id == responseId }
                   )
               ).first {
                response.isFavorite = true
            }
        }
        
        local.syncStatus = .synced
        try modelContext.save()
    }
    
    private func mergeResponseRecords(local: ResponseEnhanced, remote: CKRecord) async throws {
        // Merge strategy: Keep content from newer, preserve favorite status
        let localDate = local.lastModified ?? Date.distantPast
        let remoteDate = remote["lastModified"] as? Date ?? Date.distantPast
        
        if remoteDate > localDate {
            updateResponse(local, from: remote)
        }
        
        // Preserve favorite if either version has it
        let localFavorite = local.isFavorite ?? false
        let remoteFavorite = remote["isFavorite"] as? Bool ?? false
        local.isFavorite = localFavorite || remoteFavorite
        
        local.syncStatus = .synced
        local.lastModified = Date()
        try modelContext.save()
    }
    
    private func mergePoemGroupRecords(local: PoemGroup, remote: CKRecord) async throws {
        // Merge strategy: Combine request IDs from both
        let localDate = local.lastModified ?? Date.distantPast
        let remoteDate = remote["lastModified"] as? Date ?? Date.distantPast
        
        if remoteDate > localDate {
            updatePoemGroup(local, from: remote)
        }
        
        // Merge request IDs
        let localIds = Set(local.requestIds ?? [])
        let remoteIds = Set(remote["requestIds"] as? [String] ?? [])
        local.requestIds = Array(localIds.union(remoteIds))
        
        local.syncStatus = .synced
        local.lastModified = Date()
        try modelContext.save()
    }
    
    // MARK: - Private Sync Methods
    
    private func performSync() async {
        syncState = .syncing
        clearSyncErrors()
        
        do {
            // 1. Push local changes
            try await pushLocalChanges()
            
            // 2. Fetch remote changes
            try await fetchRemoteChanges()
            
            // 3. Update sync status
            lastSyncDate = Date()
            syncState = .idle
            
            print("✅ CloudKit sync completed successfully")
        } catch {
            syncState = .error
            addSyncError(.syncFailed(error))
            print("❌ CloudKit sync failed: \(error)")
        }
    }
    
    private func pushLocalChanges() async throws {
        // Fetch all pending changes
        let pendingRequests = try await fetchPendingRecords(RequestEnhanced.self)
        let pendingResponses = try await fetchPendingRecords(ResponseEnhanced.self)
        let pendingGroups = try await fetchPendingRecords(PoemGroup.self)
        
        pendingChangesCount = pendingRequests.count + pendingResponses.count + pendingGroups.count
        
        // Convert to CKRecords and save
        var records: [CKRecord] = []
        
        for request in pendingRequests {
            if let record = try createCKRecord(from: request) {
                records.append(record)
            }
        }
        
        for response in pendingResponses {
            if let record = try createCKRecord(from: response) {
                records.append(record)
            }
        }
        
        for group in pendingGroups {
            if let record = try createCKRecord(from: group) {
                records.append(record)
            }
        }
        
        // Batch save to CloudKit
        if !records.isEmpty {
            let operation = CKModifyRecordsOperation(
                recordsToSave: records,
                recordIDsToDelete: nil
            )
            
            operation.savePolicy = .changedKeys
            operation.perRecordSaveBlock = { recordID, result in
                Task { @MainActor in
                    switch result {
                    case .success:
                        self.updateSyncStatus(for: recordID.recordName, status: .synced)
                    case .failure(let error):
                        self.addSyncError(.recordSave(recordID.recordName, error))
                    }
                }
            }
            
            try await privateDatabase.add(operation)
        }
    }
    
    private func fetchRemoteChanges() async throws {
        let zone = CKRecordZone(zoneName: "MyPoemZone")
        let options = CKFetchRecordZoneChangesOperation.ZoneOptions()
        options.previousServerChangeToken = serverChangeToken
        
        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zone.zoneID],
            optionsByRecordZoneID: [zone.zoneID: options]
        )
        
        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [CKRecord.ID] = []
        
        operation.recordChangedBlock = { record in
            changedRecords.append(record)
        }
        
        operation.recordWithIDWasDeletedBlock = { recordID, _ in
            deletedRecordIDs.append(recordID)
        }
        
        operation.recordZoneChangeTokensUpdatedBlock = { _, token, _ in
            self.serverChangeToken = token
        }
        
        operation.recordZoneFetchCompletionBlock = { _, token, _, _, error in
            if let error = error {
                Task { @MainActor in
                    self.addSyncError(.fetchFailed(error))
                }
            } else if let token = token {
                self.serverChangeToken = token
            }
        }
        
        try await privateDatabase.add(operation)
        
        // Process fetched records
        await processRemoteChanges(changedRecords, deletedRecordIDs)
    }
    
    private func processRemoteChanges(_ records: [CKRecord], _ deletedIDs: [CKRecord.ID]) async {
        for record in records {
            do {
                switch record.recordType {
                case "Request":
                    try await processRequestRecord(record)
                case "Response":
                    try await processResponseRecord(record)
                case "PoemGroup":
                    try await processPoemGroupRecord(record)
                default:
                    print("Unknown record type: \(record.recordType)")
                }
            } catch {
                addSyncError(.recordProcess(record.recordID.recordName, error))
            }
        }
        
        // Handle deletions
        for recordID in deletedIDs {
            try? await deleteLocalRecord(recordID)
        }
    }
    
    // MARK: - Record Conversion
    
    private func createCKRecord(from request: RequestEnhanced) throws -> CKRecord? {
        guard let id = request.id else { return nil }
        
        let recordID = CKRecord.ID(recordName: id, zoneID: defaultZoneID)
        let record = CKRecord(recordType: "Request", recordID: recordID)
        
        // Set values safely
        record["userInput"] = request.userInput as CKRecordValue?
        record["userTopic"] = request.userTopic as CKRecordValue?
        record["poemTypeData"] = request.poemTypeData as CKRecordValue?
        record["temperatureData"] = request.temperatureData as CKRecordValue?
        record["createdAt"] = request.createdAt as CKRecordValue?
        record["responseId"] = request.responseId as CKRecordValue?
        record["isOriginal"] = (request.isOriginal ?? true) as CKRecordValue
        record["lastModified"] = Date() as CKRecordValue
        
        return record
    }
    
    private func createCKRecord(from response: ResponseEnhanced) throws -> CKRecord? {
        guard let id = response.id else { return nil }
        
        let recordID = CKRecord.ID(recordName: id, zoneID: defaultZoneID)
        let record = CKRecord(recordType: "Response", recordID: recordID)
        
        record["requestId"] = response.requestId as CKRecordValue?
        record["userId"] = response.userId as CKRecordValue?
        record["content"] = response.content as CKRecordValue?
        record["role"] = response.role as CKRecordValue?
        record["isFavorite"] = (response.isFavorite ?? false) as CKRecordValue
        record["dateCreated"] = response.dateCreated as CKRecordValue?
        record["lastModified"] = Date() as CKRecordValue
        
        return record
    }
    
    private func createCKRecord(from group: PoemGroup) throws -> CKRecord? {
        guard let id = group.id else { return nil }
        
        let recordID = CKRecord.ID(recordName: id, zoneID: defaultZoneID)
        let record = CKRecord(recordType: "PoemGroup", recordID: recordID)
        
        record["originalTopic"] = group.originalTopic as CKRecordValue?
        record["createdAt"] = group.createdAt as CKRecordValue?
        record["requestIds"] = group.requestIds as CKRecordValue?
        record["lastModified"] = Date() as CKRecordValue
        
        return record
    }
    
    // MARK: - Process Remote Records
    
    private func processRequestRecord(_ record: CKRecord) async throws {
        let recordId = record.recordID.recordName
        let request = try modelContext.fetch(
            FetchDescriptor<RequestEnhanced>(
                predicate: #Predicate { $0.id == recordId }
            )
        ).first
        
        if let existingRequest = request {
            // Update existing request
            if shouldUpdateLocal(localDate: existingRequest.lastModified, remoteDate: record["lastModified"] as? Date) {
                updateRequest(existingRequest, from: record)
            }
        } else {
            // Create new request
            let newRequest = RequestEnhanced()
            newRequest.id = recordId
            updateRequest(newRequest, from: record)
            modelContext.insert(newRequest)
        }
        
        try modelContext.save()
    }
    
    private func updateRequest(_ request: RequestEnhanced, from record: CKRecord) {
        request.userInput = record["userInput"] as? String
        request.userTopic = record["userTopic"] as? String
        request.poemTypeData = record["poemTypeData"] as? Data
        request.temperatureData = record["temperatureData"] as? Data
        request.createdAt = record["createdAt"] as? Date
        request.responseId = record["responseId"] as? String
        request.isOriginal = record["isOriginal"] as? Bool
        request.lastModified = record["lastModified"] as? Date
        request.syncStatus = .synced
    }
    
    // Similar methods for Response and PoemGroup...
    
    // MARK: - Helper Methods
    
    private func fetchPendingRecords<T: PersistentModel>(_ type: T.Type) async throws -> [T] {
        let descriptor = FetchDescriptor<T>(
            predicate: #Predicate { model in
                if let enhanced = model as? RequestEnhanced {
                    return enhanced.syncStatus == .pending || enhanced.syncStatus == .error
                } else if let enhanced = model as? ResponseEnhanced {
                    return enhanced.syncStatus == .pending || enhanced.syncStatus == .error
                } else if let enhanced = model as? PoemGroup {
                    return enhanced.syncStatus == .pending || enhanced.syncStatus == .error
                }
                return false
            }
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    private func shouldUpdateLocal(localDate: Date?, remoteDate: Date?) -> Bool {
        guard let local = localDate, let remote = remoteDate else { return true }
        return remote > local
    }
    
    private func updateSyncStatus(for recordId: String, status: SyncStatus) {
        // Update sync status in the model
        Task {
            if let request = try? modelContext.fetch(
                FetchDescriptor<RequestEnhanced>(
                    predicate: #Predicate { $0.id == recordId }
                )
            ).first {
                request.syncStatus = status
            } else if let response = try? modelContext.fetch(
                FetchDescriptor<ResponseEnhanced>(
                    predicate: #Predicate { $0.id == recordId }
                )
            ).first {
                response.syncStatus = status
            } else if let group = try? modelContext.fetch(
                FetchDescriptor<PoemGroup>(
                    predicate: #Predicate { $0.id == recordId }
                )
            ).first {
                group.syncStatus = status
            }
            
            try? modelContext.save()
        }
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                
                if path.status == .satisfied {
                    // Network restored, trigger sync
                    await self?.performSync()
                }
            }
        }
        
        networkMonitor.start(queue: syncQueue)
    }
    
    // MARK: - iCloud Availability
    
    private func checkiCloudAvailability() async {
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                print("✅ iCloud is available")
            case .noAccount:
                addSyncError(.noiCloudAccount)
            case .restricted:
                addSyncError(.iCloudRestricted)
            default:
                addSyncError(.iCloudUnavailable)
            }
        } catch {
            addSyncError(.iCloudCheckFailed(error))
        }
    }
    
    // MARK: - Token Management
    
    private func saveServerChangeToken() {
        guard let token = serverChangeToken else { return }
        
        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: token,
                requiringSecureCoding: true
            )
            UserDefaults.standard.set(data, forKey: "MyPoemServerChangeToken")
        } catch {
            print("Failed to save server change token: \(error)")
        }
    }
    
    private func loadServerChangeToken() {
        guard let data = UserDefaults.standard.data(forKey: "MyPoemServerChangeToken") else { return }
        
        do {
            serverChangeToken = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: CKServerChangeToken.self,
                from: data
            )
        } catch {
            print("Failed to load server change token: \(error)")
        }
    }
    
    // MARK: - Error Handling
    
    private func addSyncError(_ error: SyncError) {
        syncErrors.append(error)
        
        // Keep only recent errors
        if syncErrors.count > 10 {
            syncErrors.removeFirst()
        }
    }
    
    private func clearSyncErrors() {
        syncErrors.removeAll()
    }
    
    // MARK: - Zone Management
    
    private var defaultZoneID: CKRecordZone.ID {
        CKRecordZone(zoneName: "MyPoemZone").zoneID
    }
    
    private func performInitialSync() async {
        // Create custom zone if needed
        let zone = CKRecordZone(zoneName: "MyPoemZone")
        
        do {
            try await privateDatabase.save(zone)
            await performSync()
        } catch {
            if (error as NSError).code != CKError.Code.zoneNotFound.rawValue {
                addSyncError(.zoneCreationFailed(error))
            }
        }
    }
    
    // MARK: - Manual Sync Triggers
    
    /// Call this when app becomes active or enters background
    func performAppLifecycleSync() async {
        guard isConnected else { return }
        
        // Only sync if there are pending changes or it's been a while
        let shouldSync = pendingChangesCount > 0 ||
                        lastSyncDate == nil ||
                        Date().timeIntervalSince(lastSyncDate ?? .distantPast) > 300 // 5 minutes
        
        if shouldSync {
            await performSync()
        }
    }
    
    private func processResponseRecord(_ record: CKRecord) async throws {
        let recordId = record.recordID.recordName
        let response = try modelContext.fetch(
            FetchDescriptor<ResponseEnhanced>(
                predicate: #Predicate { $0.id == recordId }
            )
        ).first
        
        if let existingResponse = response {
            if shouldUpdateLocal(localDate: existingResponse.lastModified, remoteDate: record["lastModified"] as? Date) {
                updateResponse(existingResponse, from: record)
            }
        } else {
            let newResponse = ResponseEnhanced()
            newResponse.id = recordId
            updateResponse(newResponse, from: record)
            modelContext.insert(newResponse)
        }
        
        try modelContext.save()
    }
    
    private func updateResponse(_ response: ResponseEnhanced, from record: CKRecord) {
        response.requestId = record["requestId"] as? String
        response.userId = record["userId"] as? String
        response.content = record["content"] as? String
        response.role = record["role"] as? String
        response.isFavorite = record["isFavorite"] as? Bool
        response.dateCreated = record["dateCreated"] as? Date
        response.lastModified = record["lastModified"] as? Date
        response.syncStatus = .synced
    }
    
    private func processPoemGroupRecord(_ record: CKRecord) async throws {
        let recordId = record.recordID.recordName
        let group = try modelContext.fetch(
            FetchDescriptor<PoemGroup>(
                predicate: #Predicate { $0.id == recordId }
            )
        ).first
        
        if let existingGroup = group {
            if shouldUpdateLocal(localDate: existingGroup.lastModified, remoteDate: record["lastModified"] as? Date) {
                updatePoemGroup(existingGroup, from: record)
            }
        } else {
            let newGroup = PoemGroup()
            newGroup.id = recordId
            updatePoemGroup(newGroup, from: record)
            modelContext.insert(newGroup)
        }
        
        try modelContext.save()
    }
    
    private func updatePoemGroup(_ group: PoemGroup, from record: CKRecord) {
        group.originalTopic = record["originalTopic"] as? String
        group.createdAt = record["createdAt"] as? Date
        group.requestIds = record["requestIds"] as? [String]
        group.lastModified = record["lastModified"] as? Date
        group.syncStatus = .synced
    }
    
    private func deleteLocalRecord(_ recordID: CKRecord.ID) async throws {
        // Find and delete the local record based on ID
        let id = recordID.recordName
        
        if let request = try modelContext.fetch(
            FetchDescriptor<RequestEnhanced>(
                predicate: #Predicate { $0.id == id }
            )
        ).first {
            modelContext.delete(request)
        } else if let response = try modelContext.fetch(
            FetchDescriptor<ResponseEnhanced>(
                predicate: #Predicate { $0.id == id }
            )
        ).first {
            modelContext.delete(response)
        } else if let group = try modelContext.fetch(
            FetchDescriptor<PoemGroup>(
                predicate: #Predicate { $0.id == id }
            )
        ).first {
            modelContext.delete(group)
        }
        
        try modelContext.save()
    }
}

// MARK: - Supporting Types

enum SyncState: String {
    case idle = "Idle"
    case syncing = "Syncing..."
    case resolvingConflicts = "Resolving Conflicts"
    case error = "Error"
}

enum SyncError: LocalizedError {
    case noNetwork
    case noiCloudAccount
    case iCloudRestricted
    case iCloudUnavailable
    case iCloudCheckFailed(Error)
    case syncFailed(Error)
    case recordSave(String, Error)
    case recordProcess(String, Error)
    case fetchFailed(Error)
    case conflictResolution(Error)
    case zoneCreationFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .noNetwork:
            return "No network connection available"
        case .noiCloudAccount:
            return "No iCloud account configured"
        case .iCloudRestricted:
            return "iCloud access is restricted"
        case .iCloudUnavailable:
            return "iCloud is currently unavailable"
        case .iCloudCheckFailed(let error):
            return "Failed to check iCloud status: \(error.localizedDescription)"
        case .syncFailed(let error):
            return "Sync failed: \(error.localizedDescription)"
        case .recordSave(let id, let error):
            return "Failed to save record \(id): \(error.localizedDescription)"
        case .recordProcess(let id, let error):
            return "Failed to process record \(id): \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch changes: \(error.localizedDescription)"
        case .conflictResolution(let error):
            return "Failed to resolve conflict: \(error.localizedDescription)"
        case .zoneCreationFailed(let error):
            return "Failed to create CloudKit zone: \(error.localizedDescription)"
        }
    }
}
