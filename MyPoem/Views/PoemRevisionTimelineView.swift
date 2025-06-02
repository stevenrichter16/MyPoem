// PoemRevisionTimelineView.swift - Minimalist Redesign
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
    @State private var showingDiffView = false
    @State private var compareRevisions: (from: PoemRevision?, to: PoemRevision?) = (nil, nil)
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Minimalist background
                Color(hex: "FAFAFA")
                    .ignoresSafeArea()
                
                if isLoading {
                    MinimalistLoadingView()
                } else if revisions.isEmpty {
                    MinimalistEmptyRevisionState()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Header
                            MinimalistRevisionHeader(revisionCount: revisions.count)
                                .padding(.top, 60)
                                .padding(.bottom, 40)
                            
                            // Revisions
                            LazyVStack(spacing: 24) {
                                ForEach(Array(revisions.enumerated()), id: \.element.id) { index, revision in
                                    MinimalistRevisionCard(
                                        revision: revision,
                                        previousRevision: index < revisions.count - 1 ? revisions[index + 1] : nil,
                                        index: index,
                                        totalCount: revisions.count,
                                        onRestore: {
                                            selectedRevision = revision
                                            showingRestoreConfirmation = true
                                        },
                                        onEdit: {
                                            if revision.isCurrentVersion ?? false,
                                               let content = revision.content {
                                                editingContent = content
                                                showingEditView = true
                                            }
                                        },
                                        onCompare: { fromRevision in
                                            compareRevisions = (fromRevision, revision)
                                            showingDiffView = true
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .overlay(alignment: .top) {
                // Custom navigation bar
                MinimalistNavBar(
                    title: "Revision History",
                    onDismiss: { dismiss() }
                )
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
                    Text("This will create a new revision with the content from version \(revision.revisionNumber ?? 0)")
                }
            }
            .sheet(isPresented: $showingEditView) {
                MinimalistEditPoemView(
                    content: $editingContent,
                    onSave: { newContent, changeNote in
                        Task {
                            await saveEditedContent(newContent, changeNote: changeNote)
                        }
                    }
                )
            }
            .sheet(isPresented: $showingDiffView) {
                if let from = compareRevisions.from,
                   let to = compareRevisions.to {
                    MinimalistDiffView(
                        fromRevision: from,
                        toRevision: to
                    )
                }
            }
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
            await loadRevisions()
        } catch {
            appState.showCloudKitError("Failed to save edit: \(error.localizedDescription)")
        }
    }
}

// MARK: - Minimalist Navigation Bar
struct MinimalistNavBar: View {
    let title: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "1A1A1A"))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
                    )
            }
            
            Spacer()
            
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "1A1A1A"))
            
            Spacer()
            
            // Placeholder for balance
            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 50)
        .padding(.bottom, 20)
        .background(
            Color(hex: "FAFAFA")
                .ignoresSafeArea(edges: .top)
        )
    }
}

// MARK: - Minimalist Revision Header
struct MinimalistRevisionHeader: View {
    let revisionCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(revisionCount)")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(Color(hex: "1A1A1A"))
            
            Text("REVISIONS")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "666666"))
                .kerning(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }
}

// MARK: - Minimalist Revision Card
struct MinimalistRevisionCard: View {
    let revision: PoemRevision
    let previousRevision: PoemRevision?
    let index: Int
    let totalCount: Int
    let onRestore: () -> Void
    let onEdit: () -> Void
    let onCompare: (PoemRevision?) -> Void
    
    @State private var isExpanded = false
    @State private var showingContent = false
    
    private var changeStats: (added: Int, removed: Int, modified: Int) {
        (
            added: revision.linesAdded ?? 0,
            removed: revision.linesRemoved ?? 0,
            modified: revision.linesModified ?? 0
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Revision header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Text("v\(revision.revisionNumber ?? 0)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(hex: "1A1A1A"))
                        
                        if revision.isCurrentVersion ?? false {
                            Text("CURRENT")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .kerning(0.5)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "34C759"))
                                )
                        }
                    }
                    
                    if let date = revision.createdAt {
                        Text(formatDate(date))
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "666666"))
                    }
                }
                
                Spacer()
                
                // Change type indicator
                if let changeType = revision.changeType {
                    ChangeTypeIndicator(type: changeType)
                }
            }
            
            // Change note
            if let note = revision.changeNote {
                Text(note)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "666666"))
                    .italic()
                    .padding(.top, 12)
            }
            
            // Change statistics
            if previousRevision != nil && (changeStats.added > 0 || changeStats.removed > 0 || changeStats.modified > 0) {
                HStack(spacing: 16) {
                    if changeStats.added > 0 {
                        ChangeStatChip(value: changeStats.added, type: .added)
                    }
                    if changeStats.removed > 0 {
                        ChangeStatChip(value: changeStats.removed, type: .removed)
                    }
                    if changeStats.modified > 0 {
                        ChangeStatChip(value: changeStats.modified, type: .modified)
                    }
                }
                .padding(.top, 16)
            }
            
            // Actions
            HStack(spacing: 12) {
                // View content button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showingContent.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: showingContent ? "eye.slash" : "eye")
                            .font(.system(size: 14))
                        Text(showingContent ? "Hide" : "View")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(Color(hex: "666666"))
                }
                
                if previousRevision != nil {
                    // Compare button
                    Button(action: {
                        onCompare(previousRevision)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 14))
                            Text("Compare")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(Color(hex: "666666"))
                    }
                }
                
                Spacer()
                
                if revision.isCurrentVersion ?? false {
                    // Edit button
                    Button(action: onEdit) {
                        Text("EDIT")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "FF9500"))
                            .kerning(0.5)
                    }
                } else {
                    // Restore button
                    Button(action: onRestore) {
                        Text("RESTORE")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "007AFF"))
                            .kerning(0.5)
                    }
                }
            }
            .padding(.top, 20)
            
            // Content preview (expandable)
            if showingContent, let content = revision.content {
                Text(content)
                    .font(.custom("Georgia", size: 16))
                    .lineSpacing(6)
                    .foregroundColor(Color(hex: "2A2A2A"))
                    .padding(.top, 20)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 20, x: 0, y: 2)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Change Type Indicator
struct ChangeTypeIndicator: View {
    let type: ChangeType
    
    private var config: (icon: String, color: Color) {
        switch type {
        case .initial:
            return ("sparkles", Color(hex: "007AFF"))
        case .minor:
            return ("pencil", Color(hex: "666666"))
        case .major:
            return ("pencil.and.outline", Color(hex: "8E8E93"))
        case .regeneration:
            return ("arrow.clockwise", Color(hex: "34C759"))
        case .manual:
            return ("hand.draw", Color(hex: "FF9500"))
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: config.icon)
                .font(.system(size: 12))
            Text(type.rawValue.capitalized)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(config.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(config.color.opacity(0.1))
        )
    }
}

// MARK: - Change Stat Chip
struct ChangeStatChip: View {
    let value: Int
    let type: ChangeType
    
    enum ChangeType {
        case added, removed, modified
        
        var color: Color {
            switch self {
            case .added: return Color(hex: "34C759")
            case .removed: return Color(hex: "FF3B30")
            case .modified: return Color(hex: "FF9500")
            }
        }
        
        var symbol: String {
            switch self {
            case .added: return "+"
            case .removed: return "-"
            case .modified: return "~"
            }
        }
    }
    
    var body: some View {
        Text("\(type.symbol)\(value)")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(type.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(type.color.opacity(0.1))
            )
    }
}

// MARK: - Minimalist Edit Poem View
struct MinimalistEditPoemView: View {
    @Binding var content: String
    let onSave: (String, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var editedContent: String = ""
    @State private var changeNote: String = ""
    @FocusState private var isTextEditorFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "666666"))
                    
                    Spacer()
                    
                    Text("Edit Poem")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                    
                    Spacer()
                    
                    Button("Save") {
                        onSave(editedContent, changeNote.isEmpty ? nil : changeNote)
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(editedContent.isEmpty || editedContent == content ? Color(hex: "999999") : Color(hex: "007AFF"))
                    .disabled(editedContent.isEmpty || editedContent == content)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                
                Divider()
                    .foregroundColor(Color(hex: "E0E0E0"))
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Text editor
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CONTENT")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "666666"))
                                .kerning(0.5)
                            
                            TextEditor(text: $editedContent)
                                .font(.custom("Georgia", size: 18))
                                .foregroundColor(Color(hex: "1A1A1A"))
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .frame(minHeight: 300)
                                .focused($isTextEditorFocused)
                        }
                        
                        // Change note
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CHANGE NOTE (OPTIONAL)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "666666"))
                                .kerning(0.5)
                            
                            TextField("What did you change?", text: $changeNote)
                                .textFieldStyle(.plain)
                                .font(.system(size: 16))
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(hex: "F5F5F5"))
                                )
                        }
                    }
                    .padding(20)
                }
            }
            .background(Color.white)
            .navigationBarHidden(true)
        }
        .onAppear {
            editedContent = content
            isTextEditorFocused = true
        }
    }
}

// MARK: - Minimalist Diff View
struct MinimalistDiffView: View {
    let fromRevision: PoemRevision
    let toRevision: PoemRevision
    @Environment(\.dismiss) private var dismiss
    
    @State private var diffSegments: [PoemDiff.DiffSegment] = []
    @State private var showAdditions = true
    @State private var showDeletions = true
    @State private var viewMode: DiffViewMode = .unified
    
    enum DiffViewMode: String, CaseIterable {
        case unified = "Unified"
        case sideBySide = "Side by Side"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FAFAFA")
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    MinimalistNavBar(
                        title: "Compare v\(fromRevision.revisionNumber ?? 0) → v\(toRevision.revisionNumber ?? 0)",
                        onDismiss: { dismiss() }
                    )
                    
                    // Controls
                    VStack(spacing: 16) {
                        // View mode selector
                        Picker("View Mode", selection: $viewMode) {
                            ForEach(DiffViewMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue)
                                    .tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 20)
                        
                        // Toggle controls
                        HStack(spacing: 16) {
                            DiffToggle(
                                label: "Additions",
                                isOn: $showAdditions,
                                color: Color(hex: "34C759")
                            )
                            
                            DiffToggle(
                                label: "Deletions",
                                isOn: $showDeletions,
                                color: Color(hex: "FF3B30")
                            )
                            
                            Spacer()
                            
                            // Stats
                            if !diffSegments.isEmpty {
                                HStack(spacing: 12) {
                                    let stats = calculateStats()
                                    ChangeStatChip(value: stats.added, type: .added)
                                    ChangeStatChip(value: stats.removed, type: .removed)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 16)
                    .background(Color.white)
                    
                    Divider()
                        .foregroundColor(Color(hex: "E0E0E0"))
                    
                    // Diff content
                    ScrollView {
                        if diffSegments.isEmpty {
                            // No changes
                            VStack(spacing: 16) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 48))
                                    .foregroundColor(Color(hex: "34C759").opacity(0.3))
                                
                                Text("No changes")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(Color(hex: "666666"))
                                
                                Text("These versions are identical")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "999999"))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 100)
                        } else {
                            if viewMode == .unified {
                                MinimalistPoemDiffView(
                                    segments: diffSegments,
                                    showAdditions: $showAdditions,
                                    showDeletions: $showDeletions
                                )
                                .padding(20)
                            } else {
                                SideBySideDiffView(
                                    fromContent: fromRevision.content ?? "",
                                    toContent: toRevision.content ?? "",
                                    segments: diffSegments
                                )
                                .padding(20)
                            }
                        }
                    }
                    .background(Color(hex: "FAFAFA"))
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                calculateDiff()
            }
        }
    }
    
    private func calculateDiff() {
        guard let fromContent = fromRevision.content,
              let toContent = toRevision.content else {
            diffSegments = []
            return
        }
        
        // Debug print
        print("Calculating diff from v\(fromRevision.revisionNumber ?? 0) to v\(toRevision.revisionNumber ?? 0)")
        print("From content length: \(fromContent.count)")
        print("To content length: \(toContent.count)")
        
        diffSegments = PoemDiff.calculateDiff(from: fromContent, to: toContent)
        
        print("Generated \(diffSegments.count) diff segments")
    }
    
    private func calculateStats() -> (added: Int, removed: Int) {
        var added = 0
        var removed = 0
        
        for segment in diffSegments {
            switch segment.type {
            case .added:
                added += segment.wordCount
            case .deleted:
                removed += segment.wordCount
            case .unchanged:
                break
            }
        }
        
        return (added, removed)
    }
}

// MARK: - Diff Toggle
struct DiffToggle: View {
    let label: String
    @Binding var isOn: Bool
    let color: Color
    
    var body: some View {
        Button(action: { isOn.toggle() }) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isOn ? color : Color(hex: "E0E0E0"))
                    .frame(width: 16, height: 16)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(isOn ? 1 : 0)
                    )
                
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isOn ? Color(hex: "1A1A1A") : Color(hex: "999999"))
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Minimalist Poem Diff View
struct MinimalistPoemDiffView: View {
    let segments: [PoemDiff.DiffSegment]
    @Binding var showAdditions: Bool
    @Binding var showDeletions: Bool
    
    var body: some View {
        if segments.isEmpty {
            Text("No differences found")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "999999"))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 40)
        } else {
            Text(attributedContent)
                .font(.custom("Georgia", size: 18))
                .lineSpacing(8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var attributedContent: AttributedString {
        var result = AttributedString()
        
        for segment in segments {
            var segmentString = AttributedString(segment.text)
            
            switch segment.type {
            case .unchanged:
                segmentString.foregroundColor = Color(hex: "2A2A2A")
                
            case .added:
                if showAdditions {
                    segmentString.backgroundColor = Color(hex: "34C759").opacity(0.2)
                    segmentString.foregroundColor = Color(hex: "1A1A1A")
                } else {
                    segmentString.foregroundColor = Color(hex: "2A2A2A")
                }
                
            case .deleted:
                if showDeletions {
                    segmentString.backgroundColor = Color(hex: "FF3B30").opacity(0.2)
                    segmentString.foregroundColor = Color(hex: "1A1A1A")
                    segmentString.strikethroughStyle = Text.LineStyle(
                        pattern: .solid,
                        color: Color(hex: "FF3B30").opacity(0.5)
                    )
                } else {
                    // Hide deleted segments when toggle is off
                    continue
                }
            }
            
            result.append(segmentString)
        }
        
        return result
    }
}

// MARK: - Side by Side Diff View
struct SideBySideDiffView: View {
    let fromContent: String
    let toContent: String
    let segments: [PoemDiff.DiffSegment]
    
    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            // From (Old) version
            VStack(alignment: .leading, spacing: 8) {
                Text("FROM")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "666666"))
                    .kerning(0.5)
                
                Text(fromContent)
                    .font(.custom("Georgia", size: 16))
                    .lineSpacing(6)
                    .foregroundColor(Color(hex: "2A2A2A"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "F5F5F5"))
                    )
            }
            
            // To (New) version
            VStack(alignment: .leading, spacing: 8) {
                Text("TO")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "666666"))
                    .kerning(0.5)
                
                Text(attributedToContent)
                    .font(.custom("Georgia", size: 16))
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "F5F5F5"))
                    )
            }
        }
    }
    
    private var attributedToContent: AttributedString {
        var result = AttributedString(toContent)
        
        // Apply highlighting based on diff segments
        var currentIndex = toContent.startIndex
        
        for segment in segments {
            if segment.type == .added {
                // Find this segment in the content and highlight it
                if let range = toContent.range(of: segment.text, range: currentIndex..<toContent.endIndex) {
                    let attrRange = AttributedString.Index(range.lowerBound, within: result)!..<AttributedString.Index(range.upperBound, within: result)!
                    result[attrRange].backgroundColor = Color(hex: "34C759").opacity(0.2)
                }
            }
        }
        
        return result
    }
}

// MARK: - Loading and Empty States
struct MinimalistLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color(hex: "666666"))
            
            Text("Loading revisions...")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "666666"))
        }
    }
}

struct MinimalistEmptyRevisionState: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 64))
                .foregroundColor(Color(hex: "1A1A1A").opacity(0.1))
            
            Text("No revision history")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(Color(hex: "666666"))
            
            Text("Revisions will appear here when you edit your poem")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "999999"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
