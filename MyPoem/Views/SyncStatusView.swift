//
//  SyncStatusView.swift
//  MyPoem
//
//  Created by Steven Richter on 5/31/25.
//


// SyncStatusView.swift
import SwiftUI

struct SyncStatusView: View {
    @Environment(CloudKitSyncManager.self) private var syncManager
    @Environment(DataManager.self) private var dataManager
    @State private var showingDetails = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Sync icon with animation
            syncIcon
            
            // Sync text
            syncText
            
            // Sync button
            if syncManager.syncState == .idle && dataManager.hasUnsyncedChanges {
                Button(action: {
                    Task {
                        await dataManager.triggerSync()
                    }
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(backgroundStyle)
        .clipShape(Capsule())
        .onTapGesture {
            showingDetails = true
        }
        .sheet(isPresented: $showingDetails) {
            SyncDetailsView()
        }
    }
    
    @ViewBuilder
    private var syncIcon: some View {
        switch syncManager.syncState {
        case .idle:
            if dataManager.hasUnsyncedChanges {
                Image(systemName: "exclamationmark.icloud")
                    .foregroundColor(.orange)
                    .font(.caption)
            } else {
                Image(systemName: "checkmark.icloud")
                    .foregroundColor(.green)
                    .font(.caption)
            }
            
        case .syncing:
            ProgressView()
                .scaleEffect(0.7)
                .frame(width: 14, height: 14)
            
        case .resolvingConflicts:
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.yellow)
                .font(.caption)
            
        case .error:
            Image(systemName: "xmark.icloud")
                .foregroundColor(.red)
                .font(.caption)
        }
    }
    
    @ViewBuilder
    private var syncText: some View {
        switch syncManager.syncState {
        case .idle:
            if dataManager.hasUnsyncedChanges {
                Text("\(dataManager.unsyncedRequestsCount + dataManager.unsyncedResponsesCount) pending")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let lastSync = syncManager.lastSyncDate {
                Text(lastSync.relativeTimeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Not synced")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
        case .syncing:
            Text("Syncing...")
                .font(.caption)
                .foregroundColor(.secondary)
            
        case .resolvingConflicts:
            Text("Resolving...")
                .font(.caption)
                .foregroundColor(.secondary)
            
        case .error:
            Text("Sync error")
                .font(.caption)
                .foregroundColor(.red)
        }
    }
    
    private var backgroundStyle: some View {
        Group {
            if syncManager.syncState == .error {
                Color.red.opacity(0.1)
            } else if dataManager.hasUnsyncedChanges {
                Color.orange.opacity(0.1)
            } else {
                Color(.secondarySystemBackground)
            }
        }
    }
}

// MARK: - Sync Details View

struct SyncDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CloudKitSyncManager.self) private var syncManager
    @Environment(DataManager.self) private var dataManager
    
    var body: some View {
        NavigationView {
            List {
                // Sync Status Section
                Section("Sync Status") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(syncManager.syncState.rawValue)
                            .foregroundColor(statusColor)
                    }
                    
                    if let lastSync = syncManager.lastSyncDate {
                        HStack {
                            Text("Last Sync")
                            Spacer()
                            Text(lastSync.formatted())
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Connection")
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(syncManager.isConnected ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(syncManager.isConnected ? "Online" : "Offline")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Pending Changes Section
                if dataManager.hasUnsyncedChanges {
                    Section("Pending Changes") {
                        if dataManager.unsyncedRequestsCount > 0 {
                            HStack {
                                Label("Requests", systemImage: "doc.text")
                                Spacer()
                                Text("\(dataManager.unsyncedRequestsCount)")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if dataManager.unsyncedResponsesCount > 0 {
                            HStack {
                                Label("Responses", systemImage: "text.bubble")
                                Spacer()
                                Text("\(dataManager.unsyncedResponsesCount)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Errors Section
                if !syncManager.syncErrors.isEmpty {
                    Section("Recent Errors") {
                        ForEach(syncManager.syncErrors.reversed(), id: \.localizedDescription) { error in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(error.localizedDescription ?? "Unknown error")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                // Actions Section
                Section {
                    Button(action: {
                        Task {
                            await dataManager.triggerSync()
                        }
                    }) {
                        Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(syncManager.syncState == .syncing)
                    
                    Button(action: {
                        Task {
                            try? await dataManager.markAllForSync()
                            await dataManager.triggerSync()
                        }
                    }) {
                        Label("Force Full Sync", systemImage: "arrow.clockwise.icloud")
                            .foregroundColor(.orange)
                    }
                    .disabled(syncManager.syncState == .syncing)
                }
            }
            .navigationTitle("Sync Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var statusColor: Color {
        switch syncManager.syncState {
        case .idle:
            return dataManager.hasUnsyncedChanges ? .orange : .green
        case .syncing:
            return .blue
        case .resolvingConflicts:
            return .yellow
        case .error:
            return .red
        }
    }
}

// MARK: - Conflict Resolution View

struct ConflictResolutionView: View {
    let conflictedItems: [(local: Any, remote: Any, recordId: String)]
    @Environment(\.dismiss) private var dismiss
    @Environment(DataManager.self) private var dataManager
    
    var body: some View {
        NavigationView {
            List {
                ForEach(conflictedItems.indices, id: \.self) { index in
                    ConflictItemView(
                        local: conflictedItems[index].local,
                        remote: conflictedItems[index].remote,
                        recordId: conflictedItems[index].recordId
                    )
                }
            }
            .navigationTitle("Resolve Conflicts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Keep All Local") {
                        Task {
                            for item in conflictedItems {
                                await dataManager.resolveConflict(
                                    for: item.recordId,
                                    strategy: .keepLocal
                                )
                            }
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

struct ConflictItemView: View {
    let local: Any
    let remote: Any
    let recordId: String
    @Environment(DataManager.self) private var dataManager
    @State private var selectedStrategy: ConflictStrategy = .keepLocal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Conflict in: \(itemType)")
                .font(.headline)
            
            // Show local vs remote differences
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Local")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(itemDescription(local))
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                VStack(alignment: .leading) {
                    Text("iCloud")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(itemDescription(remote))
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Resolution options
            Picker("Resolution", selection: $selectedStrategy) {
                Text("Keep Local").tag(ConflictStrategy.keepLocal)
                Text("Keep iCloud").tag(ConflictStrategy.keepRemote)
                Text("Merge").tag(ConflictStrategy.merge)
            }
            .pickerStyle(.segmented)
            
            Button("Apply") {
                Task {
                    await dataManager.resolveConflict(
                        for: recordId,
                        strategy: selectedStrategy
                    )
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var itemType: String {
        if local is RequestEnhanced { return "Poem Request" }
        if local is ResponseEnhanced { return "Poem Response" }
        if local is PoemGroup { return "Poem Group" }
        return "Unknown"
    }
    
    private func itemDescription(_ item: Any) -> String {
        if let request = item as? RequestEnhanced {
            return request.userInput ?? "No input"
        }
        if let response = item as? ResponseEnhanced {
            return String(response.content?.prefix(50) ?? "No content") + "..."
        }
        if let group = item as? PoemGroup {
            return group.originalTopic ?? "No topic"
        }
        return "Unknown item"
    }
}

// MARK: - Helper Extensions

extension Date {
    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
