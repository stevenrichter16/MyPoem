//
//  SyncStatus.swift
//  MyPoem
//
//  Created by Steven Richter on 5/31/25.
//


// SyncMetadata.swift
enum SyncStatus: String, Codable {
    case pending = "pending"
    case syncing = "syncing"
    case synced = "synced"
    case conflict = "conflict"
    case error = "error"
}
