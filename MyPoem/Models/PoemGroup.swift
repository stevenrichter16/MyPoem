//
//  PoemGroup.swift
//  MyPoem
//
//  Created by Steven Richter on 5/31/25.
//

import Foundation
import SwiftData

@Model
final class PoemGroup: Identifiable {
    @Attribute(.unique) var id: String?
    var originalTopic: String?
    var createdAt: Date?
    var requestIds: [String]?
    
    // CloudKit sync metadata
    var lastModified: Date?
    var syncStatus: SyncStatus?
    
    init(
        id: String? = UUID().uuidString,
        originalTopic: String? = nil,
        createdAt: Date? = Date()
    ) {
        self.id = id
        self.originalTopic = originalTopic
        self.createdAt = createdAt
        self.requestIds = []
        self.lastModified = Date()
        self.syncStatus = .pending
    }
}
