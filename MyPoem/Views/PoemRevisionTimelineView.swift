// MyPoem/Views/PoemRevisionTimelineView.swift
import SwiftUI

struct PoemRevisionTimelineView: View {
    let request: RequestEnhanced
    @Environment(\.dismiss) private var dismiss
    @Environment(DataManager.self) private var dataManager
    @Environment(AppState.self) private var appState
    
    @State private var revisions: [PoemRevision] = []
    @State private var isLoading = true
    @State private var selectedRevision: PoemRevision?
    @State private var showingRestoreConfirmation = false
    @State private var showingEditView = false
    @State private var editingContent: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Loading revisions...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if revisions.isEmpty {
                    emptyStateView
                } else {
                    timelineContent
                }
            }
            .navigationTitle("Revision History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadRevisions()
            }
            .confirmationDialog(
                "Restore this version?",
                isPresented: $showingRestoreConfirmation,
                titleVisibility: .visible
            ) {
                if let revision = selectedRevision {
                    Button("Restore") {
                        Task {
                            await restoreRevision(revision)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }
            } message: {
                if let revision = selectedRevision {
                    Text("This will create a new revision with the content from revision #\(revision.revisionNumber ?? 0)")
                }
            }
            .sheet(isPresented: $showingEditView) {
                EditPoemView(
                    content: $editingContent,
                    onSave: { newContent, changeNote in
                        Task {
                            await saveEditedContent(newContent, changeNote: changeNote)
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Timeline Content
    
    private var timelineContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(revisions.enumerated()), id: \.element.id) { index, revision in
                    VStack(spacing: 0) {
                        // Timeline node and line
                        HStack(alignment: .top, spacing: 12) {
                            // Timeline visualization (more compact)
                            VStack(spacing: 0) {
                                // Smaller node
                                ZStack {
                                    Circle()
                                        .fill(revision.isCurrentVersion ?? false ? Color.green : Color.blue.opacity(0.3))
                                        .frame(width: 12, height: 12)
                                    
                                    if revision.isCurrentVersion ?? false {
                                        Circle()
                                            .stroke(Color.green, lineWidth: 2)
                                            .frame(width: 18, height: 18)
                                    }
                                }
                                
                                // Connecting line (not for last item)
                                if index < revisions.count - 1 {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 1.5)
                                        .frame(maxHeight: .infinity)
                                }
                            }
                            .frame(width: 18)
                            
                            // Revision card with better spacing
                            RevisionCard(
                                revision: revision,
                                previousRevision: index < revisions.count - 1 ? revisions[index + 1] : nil,
                                isFirst: index == 0,
                                isLast: index == revisions.count - 1,
                                onTap: { selectedRevision = revision },
                                onRestore: {
                                    selectedRevision = revision
                                    showingRestoreConfirmation = true
                                },
                                onEdit: {
                                    // Handle edit action
                                    if revision.isCurrentVersion ?? false,
                                       let content = revision.content {
                                        editingContent = content
                                        showingEditView = true
                                    }
                                }
                            )
                            .padding(.bottom, index < revisions.count - 1 ? 24 : 0)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No revision history")
                .font(.title3)
                .foregroundColor(.primary)
            
            Text("Revisions will appear here when you edit your poem")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Methods
    
    private func loadRevisions() async {
        isLoading = true
        do {
            revisions = try await dataManager.fetchRevisions(for: request)
        } catch {
            print("Failed to load revisions: \(error)")
        }
        isLoading = false
    }
    
    private func restoreRevision(_ revision: PoemRevision) async {
        do {
            try await dataManager.restoreRevision(revision, for: request)
            dismiss()
        } catch {
            appState.showCloudKitError("Failed to restore revision: \(error.localizedDescription)")
        }
    }
    
    private func saveEditedContent(_ newContent: String, changeNote: String?) async {
        do {
            try await dataManager.updatePoemContent(
                for: request,
                newContent: newContent,
                changeNote: changeNote
            )
            showingEditView = false
            // Reload revisions to show the new edit
            await loadRevisions()
        } catch {
            appState.showCloudKitError("Failed to save edit: \(error.localizedDescription)")
        }
    }
}

// MARK: - Revision Card Component

struct RevisionCard: View {
    let revision: PoemRevision
    let previousRevision: PoemRevision?
    let isFirst: Bool
    let isLast: Bool
    let onTap: () -> Void
    let onRestore: () -> Void
    let onEdit: () -> Void
    
    @State private var isExpanded = false
    @State private var showAdditions = false
    @State private var showDeletions = false
    @State private var diffSegments: [PoemDiff.DiffSegment] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Revision #\(revision.revisionNumber ?? 0)")
                            .font(.headline)
                        
                        if revision.isCurrentVersion ?? false {
                            Text("CURRENT")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                        }
                    }
                    
                    if let date = revision.createdAt {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Change indicator
                if let changeType = revision.changeType {
                    changeTypeIndicator(changeType)
                }
            }
            

            // Change metrics (now interactive)
            if !diffSegments.isEmpty {  // Changed from: if previousRevision != nil && !isFirst
                HStack(spacing: 16) {
                    // Calculate actual word changes
                    let addedWords = diffSegments.filter { $0.type == .added }.reduce(0) { $0 + $1.wordCount }
                    let deletedWords = diffSegments.filter { $0.type == .deleted }.reduce(0) { $0 + $1.wordCount }
                    
                    if addedWords > 0 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showAdditions.toggle()
                                if showAdditions {
                                    showDeletions = false
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: showAdditions ? "checkmark.circle.fill" : "plus.circle.fill")
                                Text("+\(addedWords)")
                            }
                            .font(.caption)
                            .foregroundColor(showAdditions ? .white : .green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(showAdditions ? Color.green : Color.green.opacity(0.2))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if deletedWords > 0 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showDeletions.toggle()
                                if showDeletions {
                                    showAdditions = false
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: showDeletions ? "checkmark.circle.fill" : "minus.circle.fill")
                                Text("-\(deletedWords)")
                            }
                            .font(.caption)
                            .foregroundColor(showDeletions ? .white : .red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(showDeletions ? Color.red : Color.red.opacity(0.2))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Reset button if any highlighting is active
                    if showAdditions || showDeletions {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showAdditions = false
                                showDeletions = false
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Change note
            if let note = revision.changeNote {
                Text(note)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Content preview with diff highlighting
            if let content = revision.content {
                VStack(alignment: .leading, spacing: 8) {
                    if !diffSegments.isEmpty && (showAdditions || showDeletions) {
                        // Show diff view
                        PoemDiffView(
                            segments: diffSegments,
                            showAdditions: $showAdditions,
                            showDeletions: $showDeletions
                        )
                        .lineLimit(isExpanded ? nil : 6)
                    } else {
                        // Show normal content
                        Text(content)
                            .font(.body)
                            .lineSpacing(2)
                            .lineLimit(isExpanded ? nil : 3)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Button(action: { withAnimation { isExpanded.toggle() } }) {
                        Text(isExpanded ? "Show less" : "Show more")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Actions
            HStack {
                if revision.isCurrentVersion ?? false {
                    // Edit button for current version
                    Button(action: onEdit) {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 16))
                            Text("Edit Poem")
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                } else {
                    // Restore button for previous versions
                    Spacer()
                    
                    Button(action: onRestore) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(.system(size: 16))
                            Text("Use This Version")
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: .blue.opacity(0.3), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
        .onTapGesture(perform: onTap)
        .onAppear {
            calculateDiff()
        }
    }
    
    // In RevisionCard, update the calculateDiff method:

    private func calculateDiff() {
        // For diff calculation, we need to compare:
        // - If this is the current version (newest), compare with the previous version
        // - Otherwise, compare this version with its previous version
        
        let fromContent: String
        let toContent: String
        
        if let currentContent = revision.content {
            if revision.isCurrentVersion ?? false {
                // This is the current version - compare with previous if it exists
                if let prevContent = previousRevision?.content {
                    fromContent = prevContent
                    toContent = currentContent
                } else {
                    // No previous version to compare with
                    return
                }
            } else {
                // This is a historical version - compare with the one before it
                if let prevContent = previousRevision?.content {
                    fromContent = prevContent
                    toContent = currentContent
                } else {
                    // This is the oldest version, no diff to show
                    return
                }
            }
            
            diffSegments = PoemDiff.calculateDiff(from: fromContent, to: toContent)
        }
    }
    
    @ViewBuilder
    private func changeTypeIndicator(_ type: ChangeType) -> some View {
        let config = changeTypeConfig(type)
        Label(config.label, systemImage: config.icon)
            .font(.caption)
            .foregroundColor(config.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(config.color.opacity(0.1))
            .clipShape(Capsule())
    }
    
    private func changeTypeConfig(_ type: ChangeType) -> (label: String, icon: String, color: Color) {
        switch type {
        case .initial:
            return ("Initial", "sparkles", .blue)
        case .minor:
            return ("Minor", "pencil", .gray)
        case .major:
            return ("Major", "pencil.and.outline", .purple)
        case .regeneration:
            return ("AI", "arrow.clockwise", .green)
        case .manual:
            return ("Edit", "hand.draw", .orange)
        }
    }
}

// MARK: - Edit Poem View

struct EditPoemView: View {
    @Binding var content: String
    let onSave: (String, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var editedContent: String = ""
    @State private var changeNote: String = ""
    @FocusState private var isTextEditorFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Text editor
                TextEditor(text: $editedContent)
                    .font(.body)
                    .padding()
                    .focused($isTextEditorFocused)
                
                Divider()
                
                // Change note section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Change Note (optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("What did you change?", text: $changeNote)
                        .textFieldStyle(.roundedBorder)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
            }
            .navigationTitle("Edit Poem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(editedContent, changeNote.isEmpty ? nil : changeNote)
                    }
                    .fontWeight(.semibold)
                    .disabled(editedContent.isEmpty || editedContent == content)
                }
            }
        }
        .onAppear {
            editedContent = content
            isTextEditorFocused = true
        }
    }
}
