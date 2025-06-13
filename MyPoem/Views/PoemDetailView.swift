import SwiftUI
import AVFoundation
import SwiftData
import Speech

struct PoemDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(DataManager.self) var dataManager
    
    let request: RequestEnhanced
    let response: ResponseEnhanced
    
    @State private var showingNotes = true
    @State private var selectedLineIndex: Int? = nil
    @State private var showingLineActions = false
    @State private var showingNoteEditor = false
    @State private var editingNoteForLine: Int? = nil
    @State private var poemNotes: [PoemNote] = []
    @State private var noteContent = ""
    @State private var selectedColorHex = "#F5F5F5"
    @State private var isLoadingNotes = false
    @State private var showingRevisionHistory = false
    @State private var showAllOverallNotes = false
    @State private var editingOverallNote: PoemNote? = nil
    @State private var noteToDelete: PoemNote? = nil
    @State private var showingDeleteConfirmation = false
    @State private var previewingNote: PoemNote? = nil
    @State private var pressingNoteId: String? = nil
    
    // Audio components
    @State private var audioRecorder: PoemAudioRecorder?
    @State private var audioPlayer: PoemAudioPlayer?
    @State private var speechTranscriber: PoemSpeechTranscriber?
    
    // Computed properties for overall notes
    private var overallNotes: [PoemNote] {
        poemNotes
            .filter { $0.lineNumber == nil }
            .sorted { ($0.modifiedAt ?? $0.createdAt ?? Date()) > ($1.modifiedAt ?? $1.createdAt ?? Date()) }
    }
    
    private var displayedOverallNotes: [PoemNote] {
        showAllOverallNotes ? overallNotes : Array(overallNotes.prefix(3))
    }
    
    private var canAddMoreOverallNotes: Bool {
        overallNotes.count < 10
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    poemHeader
                    
                    Divider()
                        .background(Color(hex: "#E0E0E0"))
                    
                    poemContentWithLineNumbers
                    
                    if showingNotes {
                        notesSection
                        audioNotesSection
                    }
                }
                .padding(10)
            }
            .background(Color(hex: "#FAFAFA"))
            .navigationBarHidden(true)
            .overlay(alignment: .top) {
                customNavigationBar
            }
        }
        .task {
            await loadNotes()
            await loadAudioNote()
        }
        .onAppear {
            setupAudioComponents()
        }
        .onDisappear {
            audioPlayer?.cleanup()
            audioRecorder?.cleanup()
            pressingNoteId = nil
        }
        .sheet(isPresented: $showingNoteEditor) {
            noteEditorSheet
        }
        .sheet(isPresented: $showingRevisionHistory) {
            PoemRevisionTimelineView(request: request)
        }
        .alert("Delete Note", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let noteToDelete = noteToDelete {
                    Task {
                        await deleteNote(noteToDelete)
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this note? This action cannot be undone.")
        }
        .overlay(
            notePreviewOverlay
        )
    }
    
    // MARK: - Setup Functions
    
    private func setupAudioComponents() {
        audioRecorder = PoemAudioRecorder(
            response: response,
            dataManager: dataManager
        ) { url, audioNote in
            // Start transcription after recording
            Task { @MainActor [weak speechTranscriber] in
                await speechTranscriber?.transcribeAudio(from: url, for: audioNote)
            }
        }
        
        audioPlayer = PoemAudioPlayer()
        speechTranscriber = PoemSpeechTranscriber(dataManager: dataManager)
    }
    
    private var customNavigationBar: some View {
        HStack {
            Text("Poem Details")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color(hex: "#1A1A1A"))
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(Color(hex: "#666666"))
                    .frame(width: 30, height: 30)
                    .background(Color(hex: "#F0F0F0"))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(hex: "#FAFAFA"))
    }
    
    private var poemHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(request.userTopic ?? request.userInput ?? "Untitled")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "#1A1A1A"))
            
            HStack(spacing: 16) {
                if let poemType = request.poemType {
                    Label {
                        Text(poemType.name)
                            .font(.subheadline)
                    } icon: {
                        Image(systemName: "text.alignleft")
                    }
                    .foregroundColor(Color(hex: "#666666"))
                }
                
                if let variationId = request.poemVariationId,
                   let poemType = request.poemType,
                   let variation = poemType.variations.first(where: { $0.id == variationId }) {
                    Label {
                        Text(variation.name)
                            .font(.subheadline)
                    } icon: {
                        Image(systemName: "sparkles")
                    }
                    .foregroundColor(Color(hex: "#666666"))
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: { showingRevisionHistory = true }) {
                        Label {
                            Text("View History")
                                .font(.subheadline)
                        } icon: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                    }
                    .foregroundColor(Color(hex: "#007AFF"))
                    
                    Button(action: { showingNotes.toggle() }) {
                        Label {
                            Text(showingNotes ? "Hide Notes" : "Show Notes")
                                .font(.subheadline)
                        } icon: {
                            Image(systemName: showingNotes ? "note.text" : "note.text.badge.plus")
                        }
                    }
                    .foregroundColor(Color(hex: "#007AFF"))
                }
            }
        }
        .padding(.top, 60)
    }
    
    private var poemContentWithLineNumbers: some View {
        let lines = (response.content ?? "").components(separatedBy: .newlines)
        
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                poemLineRow(index: index, line: line)
            }
        }
        .padding(.vertical, 8)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onTapGesture {
            // Tap outside to deselect
            if selectedLineIndex != nil {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    print("in poemContentWithLineNumbers")
                    selectedLineIndex = nil
                    showingLineActions = false
                }
            }
        }
    }
    
    @ViewBuilder
    private func poemLineRow(index: Int, line: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            lineNumberView(index: index)
            lineContentView(index: index, line: line)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
        .padding(.trailing, 8)
        .background(lineBackground(index: index))
        .onTapGesture {
            handleLineTap(index: index)
        }
    }
    
    @ViewBuilder
    private func lineNumberView(index: Int) -> some View {
        HStack(spacing: 2) {
            // Color dot indicator
            if let note = noteForLine(lineNumber: index, in: poemNotes) {
                Circle()
                    .fill(Color(hex: note.colorHex ?? "#F5F5F5"))
                    .frame(width: 6, height: 6)
                    .overlay(
                        Circle()
                            .stroke(Color(hex: "#E0E0E0"), lineWidth: 0.5)
                    )
            }
            
            Text("\(index + 1)")
                .font(.custom("Georgia", size: 16))
                .foregroundColor(selectedLineIndex == index ? Color(hex: "#007AFF") : Color(hex: "#999999"))
        }
        .frame(minWidth: 28, alignment: .trailing)
    }
    
    @ViewBuilder
    private func lineContentView(index: Int, line: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(line)
                    .font(.custom("Georgia", size: 18))
                    .foregroundColor(Color(hex: "#1A1A1A"))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Note indicator
                if lineHasNote(lineNumber: index, in: poemNotes) {
                    Image(systemName: "note.text")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#666666"))
                }
            }
            
            // Show existing note if any
            if let note = noteForLine(lineNumber: index, in: poemNotes) {
                noteView(note: note)
            }
            
            // Show action buttons only for selected line
            if selectedLineIndex == index && showingLineActions {
                lineActionButtons(index: index)
            }
        }
    }
    
    @ViewBuilder
    private func noteView(note: PoemNote) -> some View {
        Text(note.noteContent ?? "")
            .font(.caption)
            .foregroundColor(Color(hex: "#333333"))
            .italic()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: note.colorHex ?? "#F5F5F5"))
            .cornerRadius(4)
    }
    
    @ViewBuilder
    private func lineActionButtons(index: Int) -> some View {
        HStack(spacing: 12) {
            Button(action: {
                editingNoteForLine = index
                let existingNote = noteForLine(lineNumber: index, in: poemNotes)
                noteContent = existingNote?.noteContent ?? ""
                selectedColorHex = existingNote?.colorHex ?? "#F5F5F5"
                showingNoteEditor = true
            }) {
                Label(lineHasNote(lineNumber: index, in: poemNotes) ? "Edit Note" : "Add Note",
                      systemImage: lineHasNote(lineNumber: index, in: poemNotes) ? "note.text" : "note.text.badge.plus")
                    .font(.caption)
                    .foregroundColor(Color(hex: "#007AFF"))
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.top, 4)
        .transition(.scale.combined(with: .opacity))
    }
    
    private func lineBackground(index: Int) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(selectedLineIndex == index ? Color(hex: "#007AFF").opacity(0.05) : Color.clear)
    }
    
    private func handleLineTap(index: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if selectedLineIndex == index {
                showingLineActions.toggle()
            } else {
                selectedLineIndex = index
                showingLineActions = true
            }
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with count
            HStack {
                Text("Overall Notes")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#1A1A1A"))
                
                if !overallNotes.isEmpty {
                    Text("(\(overallNotes.count)/10)")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#666666"))
                }
                
                Spacer()
                
                // Add button only if under limit
                if canAddMoreOverallNotes {
                    Button(action: {
                        editingNoteForLine = nil // nil indicates overall poem note
                        editingOverallNote = nil // Creating new note
                        noteContent = ""
                        selectedColorHex = "#F5F5F5"
                        showingNoteEditor = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                            if overallNotes.count >= 8 {
                                Text("(\(10 - overallNotes.count) left)")
                                    .font(.caption)
                            }
                        }
                        .foregroundColor(Color(hex: "#007AFF"))
                    }
                } else {
                    Text("Limit reached")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#999999"))
                }
            }
            
            // Display notes or empty state
            if overallNotes.isEmpty {
                Text("Add notes about the overall poem, themes, or revision plans")
                    .font(.caption)
                    .foregroundColor(Color(hex: "#999999"))
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color(hex: "#F5F5F5"))
                    .cornerRadius(8)
            } else {
                VStack(spacing: 12) {
                    // Display notes
                    ForEach(displayedOverallNotes) { note in
                        overallNoteCard(for: note)
                    }
                    
                    // Show more/less button
                    if overallNotes.count > 3 {
                        Button(action: {
                            showAllOverallNotes.toggle()
                        }) {
                            HStack {
                                Text(showAllOverallNotes ? "Show less" : "Show \(overallNotes.count - 3) more note\(overallNotes.count - 3 == 1 ? "" : "s")")
                                    .font(.subheadline)
                                Image(systemName: showAllOverallNotes ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                            }
                            .foregroundColor(Color(hex: "#007AFF"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Note Preview Overlay
    
    @ViewBuilder
    private var notePreviewOverlay: some View {
        if previewingNote != nil {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture {
                    dismissPreview()
                }
                .overlay(
                    Group {
                        if let note = previewingNote {
                            NotePreviewCard(
                                note: note,
                                onEdit: {
                                    dismissPreview()
                                    editingNoteForLine = nil
                                    editingOverallNote = note
                                    noteContent = note.noteContent ?? ""
                                    selectedColorHex = note.colorHex ?? "#F5F5F5"
                                    showingNoteEditor = true
                                },
                                onCopy: {
                                    UIPasteboard.general.string = note.noteContent
                                    dismissPreview()
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                },
                                onDelete: {
                                    dismissPreview()
                                    noteToDelete = note
                                    showingDeleteConfirmation = true
                                },
                                onDismiss: dismissPreview
                            )
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9, anchor: .center).combined(with: .opacity),
                                removal: .scale(scale: 0.95, anchor: .center).combined(with: .opacity)
                            ))
                        }
                    }
                )
                .animation(.easeOut(duration: 0.1), value: previewingNote)
        }
    }
    
    private func dismissPreview() {
        withAnimation(.easeOut(duration: 0.15)) {
            previewingNote = nil
        }
        pressingNoteId = nil
    }
    
    // MARK: - Overall Note Card
    
    private func overallNoteCard(for note: PoemNote) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Use markdown rendering for overall notes
            Text(renderMarkdown(note.noteContent ?? ""))
                .font(.body)
                .foregroundColor(Color(hex: "#333333"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(showAllOverallNotes ? nil : 3)
            
            HStack {
                Text(formatDate(note.modifiedAt ?? note.createdAt ?? Date()))
                    .font(.caption2)
                    .foregroundColor(Color(hex: "#999999"))
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        editingNoteForLine = nil
                        editingOverallNote = note
                        noteContent = note.noteContent ?? ""
                        selectedColorHex = note.colorHex ?? "#F5F5F5"
                        showingNoteEditor = true
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#007AFF"))
                    }
                    
                    Button(action: {
                        noteToDelete = note
                        showingDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#FF3B30"))
                    }
                }
            }
        }
        .padding(12)
        .background(Color(hex: note.colorHex ?? "#F5F5F5"))
        .cornerRadius(8)
        .scaleEffect(pressingNoteId == note.id ? 0.95 : 1.0)
        .animation(.easeOut(duration: 0.35), value: pressingNoteId)
        .contentShape(Rectangle())
        .onTapGesture { } // This prevents tap from interfering
        .onLongPressGesture(
            minimumDuration: 0.15,
            maximumDistance: .infinity // Allow finger movement during long press
        ) {
            // Long press completed
            print("LONG PRESS COMPLETED")
            previewingNote = note
            // Delay resetting the scale until preview is visible
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                pressingNoteId = nil
            }
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        } onPressingChanged: { pressing in
            if pressing {
                pressingNoteId = note.id
            } else {
                pressingNoteId = nil
            }
        }
    }
    
    // MARK: - Audio Notes Section
    
    private var audioNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Audio Note")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#1A1A1A"))
                
                Spacer()
            }
            
            VStack(spacing: 16) {
                // Recording/Playback controls
                HStack(spacing: 20) {
                    // Record button
                    Button(action: {
                        if audioRecorder?.isRecording ?? false {
                            audioRecorder?.stopRecording()
                        } else {
                            audioRecorder?.startRecording()
                        }
                    }) {
                        Image(systemName: (audioRecorder?.isRecording ?? false) ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor((audioRecorder?.isRecording ?? false) ? Color(hex: "#FF3B30") : Color(hex: "#007AFF"))
                    }
                    .disabled(audioPlayer?.isPlaying ?? false)
                    
                    if audioRecorder?.audioNoteURL != nil {
                        // Rewind button
                        Button(action: {
                            audioPlayer?.seekAudio(by: -10)
                        }) {
                            Image(systemName: "gobackward.10")
                                .font(.system(size: 32))
                                .foregroundColor(Color(hex: "#007AFF"))
                        }
                        .disabled(audioRecorder?.isRecording ?? false)
                        
                        // Play button
                        Button(action: {
                            if audioPlayer?.isPlaying ?? false {
                                audioPlayer?.stopPlaying()
                            } else if let url = audioRecorder?.audioNoteURL {
                                audioPlayer?.playRecording(from: url)
                            }
                        }) {
                            Image(systemName: (audioPlayer?.isPlaying ?? false) ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(Color(hex: "#34C759"))
                        }
                        .disabled(audioRecorder?.isRecording ?? false)
                        
                        // Fast forward button
                        Button(action: {
                            audioPlayer?.seekAudio(by: 10)
                        }) {
                            Image(systemName: "goforward.10")
                                .font(.system(size: 32))
                                .foregroundColor(Color(hex: "#007AFF"))
                        }
                        .disabled(audioRecorder?.isRecording ?? false)
                        
                        // Delete button
                        Button(action: {
                            Task {
                                await audioRecorder?.deleteRecording()
                                speechTranscriber?.clearTranscription()
                            }
                        }) {
                            Image(systemName: "trash.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Color(hex: "#FF3B30"))
                        }
                        .disabled((audioRecorder?.isRecording ?? false) || (audioPlayer?.isPlaying ?? false))
                    }
                }
                
                // Recording time or status
                if audioRecorder?.isRecording ?? false {
                    Text("Recording... \(formatTime(audioRecorder?.recordingTime ?? 0))")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#FF3B30"))
                } else if audioPlayer?.isPlaying ?? false {
                    VStack(spacing: 8) {
                        // Progress bar with scrubbing
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background track
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(hex: "#E0E0E0"))
                                    .frame(height: 4)
                                
                                // Progress fill
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(hex: "#34C759"))
                                    .frame(width: geometry.size.width * (audioPlayer?.playbackProgress ?? 0), height: 4)
                                    .animation((audioPlayer?.isDraggingScrubber ?? false) ? nil : .linear(duration: 0.03), value: audioPlayer?.playbackProgress ?? 0)
                                
                                // Scrubber handle
                                Circle()
                                    .fill(Color(hex: "#34C759"))
                                    .frame(width: 12, height: 12)
                                    .offset(x: geometry.size.width * (audioPlayer?.playbackProgress ?? 0) - 6)
                                    .animation((audioPlayer?.isDraggingScrubber ?? false) ? nil : .linear(duration: 0.03), value: audioPlayer?.playbackProgress ?? 0)
                            }
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        audioPlayer?.isDraggingScrubber = true
                                        let progress = min(max(0, value.location.x / geometry.size.width), 1)
                                        audioPlayer?.playbackProgress = progress
                                    }
                                    .onEnded { _ in
                                        audioPlayer?.scrubToPosition(audioPlayer?.playbackProgress ?? 0)
                                        audioPlayer?.isDraggingScrubber = false
                                    }
                            )
                        }
                        .frame(height: 12)
                        
                        HStack {
                            Text(formatTime((audioRecorder?.recordingTime ?? 0) * (audioPlayer?.playbackProgress ?? 0)))
                                .font(.caption2)
                                .foregroundColor(Color(hex: "#999999"))
                            
                            Spacer()
                            
                            Text(formatTime(audioRecorder?.recordingTime ?? 0))
                                .font(.caption2)
                                .foregroundColor(Color(hex: "#999999"))
                        }
                    }
                    .padding(.horizontal, 40)
                } else if audioRecorder?.audioNoteURL != nil {
                    VStack(spacing: 4) {
                        Text("Audio note saved")
                            .font(.caption)
                            .foregroundColor(Color(hex: "#666666"))
                        Text("Duration: \(formatTime(audioRecorder?.recordingTime ?? 0))")
                            .font(.caption2)
                            .foregroundColor(Color(hex: "#999999"))
                    }
                } else {
                    Text("Tap to record your thoughts about this poem")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#999999"))
                        .italic()
                }
                
                // Transcription display
                if speechTranscriber?.isTranscribing ?? false {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Transcribing...")
                            .font(.caption)
                            .foregroundColor(Color(hex: "#007AFF"))
                    }
                    .padding(.top, 12)
                }
                
                if !(speechTranscriber?.transcriptionText ?? "").isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "text.quote")
                                .font(.caption)
                                .foregroundColor(Color(hex: "#666666"))
                            Text("Transcription")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(Color(hex: "#666666"))
                            Spacer()
                        }
                        
                        Text(speechTranscriber?.transcriptionText ?? "")
                            .font(.body)
                            .foregroundColor(Color(hex: "#333333"))
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(hex: "#E0E0E0"), lineWidth: 1)
                            )
                    }
                    .padding(.top, 12)
                }
                
                if let error = speechTranscriber?.transcriptionError {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption)
                        Text(error)
                            .font(.caption)
                    }
                    .foregroundColor(Color(hex: "#FF3B30"))
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(Color(hex: "#F5F5F5"))
            .cornerRadius(8)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Note Editor Sheet
    
    private var noteEditorSheet: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                if let lineIndex = editingNoteForLine {
                    let lines = (response.content ?? "").components(separatedBy: .newlines)
                    if lineIndex < lines.count {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Line \(lineIndex + 1)")
                                .font(.caption)
                                .foregroundColor(Color(hex: "#666666"))
                            
                            Text(lines[lineIndex])
                                .font(.custom("Georgia", size: 16))
                                .foregroundColor(Color(hex: "#1A1A1A"))
                                .padding(12)
                                .background(Color(hex: "#F5F5F5"))
                                .cornerRadius(8)
                        }
                    }
                } else {
                    // Overall poem note
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Overall Poem Note")
                            .font(.caption)
                            .foregroundColor(Color(hex: "#666666"))
                        
                        Text("Supports markdown: **bold**, *italic*, ~~strikethrough~~")
                            .font(.caption2)
                            .foregroundColor(Color(hex: "#999999"))
                            .italic()
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Color")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#666666"))
                    
                    ColorPaletteView(selectedColorHex: $selectedColorHex)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Note")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#666666"))
                    
                    TextEditor(text: $noteContent)
                        .font(.body)
                        .padding(8)
                        .background(Color(hex: selectedColorHex))
                        .cornerRadius(8)
                        .frame(minHeight: 100)
                }
                
                Spacer()
            }
            .padding(20)
            .navigationTitle(editingNoteForLine != nil ? "Line Note" : (editingOverallNote != nil ? "Edit Overall Note" : "New Overall Note"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        noteContent = ""
                        selectedColorHex = "#F5F5F5"
                        editingOverallNote = nil
                        showingNoteEditor = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveNote()
                        }
                    }
                    .disabled(noteContent.isEmpty)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func loadNotes() async {
        isLoadingNotes = true
        do {
            poemNotes = try await dataManager.fetchNotes(for: response)
        } catch {
            print("Failed to load notes: \(error)")
        }
        isLoadingNotes = false
    }
    
    private func saveNote() async {
        if editingNoteForLine != nil {
            await saveLineNote()
        } else {
            await saveOverallNote()
        }
    }
    
    private func saveLineNote() async {
        guard let lineIndex = editingNoteForLine,
              !noteContent.isEmpty else { return }
        
        let lines = (response.content ?? "").components(separatedBy: .newlines)
        let lineContent = lineIndex < lines.count ? lines[lineIndex] : nil
        
        do {
            if let existingNote = noteForLine(lineNumber: lineIndex, in: poemNotes) {
                // Update existing note with color
                existingNote.colorHex = selectedColorHex
                try await dataManager.updateNote(existingNote, content: noteContent)
            } else {
                // Create new note with color
                _ = try await dataManager.createNote(
                    for: response,
                    lineNumber: lineIndex,
                    lineContent: lineContent,
                    noteContent: noteContent,
                    colorHex: selectedColorHex
                )
            }
            
            // Reload notes
            await loadNotes()
            
            // Clear and dismiss
            noteContent = ""
            selectedColorHex = "#F5F5F5"
            showingNoteEditor = false
        } catch {
            print("Failed to save line note: \(error)")
        }
    }
    
    private func saveOverallNote() async {
        guard !noteContent.isEmpty else { return }
        
        do {
            // Check if we're editing an existing note
            if let existingNote = editingOverallNote {
                // Update existing overall note
                existingNote.colorHex = selectedColorHex
                try await dataManager.updateNote(existingNote, content: noteContent)
            } else {
                // Check if we've hit the limit
                guard canAddMoreOverallNotes else {
                    print("Cannot add more notes - limit of 10 reached")
                    return
                }
                
                // Create new overall note
                _ = try await dataManager.createNote(
                    for: response,
                    lineNumber: nil,
                    lineContent: nil,
                    noteContent: noteContent,
                    colorHex: selectedColorHex
                )
            }
            
            // Reload notes
            await loadNotes()
            
            // Clear and dismiss
            noteContent = ""
            selectedColorHex = "#F5F5F5"
            editingOverallNote = nil
            showingNoteEditor = false
        } catch {
            print("Failed to save overall note: \(error)")
        }
    }
    
    
    private func deleteNote(_ note: PoemNote) async {
        do {
            try await dataManager.deleteNote(note)
            await loadNotes()
            noteToDelete = nil
        } catch {
            print("Failed to delete note: \(error)")
        }
    }
    
    private func loadAudioNote() async {
        do {
            if let audioNote = try await dataManager.fetchAudioNote(for: response) {
                audioRecorder?.audioNoteURL = audioNote.audioFileURL
                audioRecorder?.recordingTime = audioNote.duration ?? 0
                speechTranscriber?.transcriptionText = audioNote.transcription ?? ""
            }
        } catch {
            print("Failed to load audio note: \(error)")
        }
    }
    
}

// MARK: - Note Preview Card

struct NotePreviewCard: View {
    let note: PoemNote
    let onEdit: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onDismiss: () -> Void
    
    @State private var isContentLoaded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Circle()
                    .fill(Color(hex: note.colorHex ?? "#F5F5F5"))
                    .frame(width: 12, height: 12)
                
                Text(formatDateCompact(note.modifiedAt ?? note.createdAt ?? Date()))
                    .font(.caption)
                    .foregroundColor(Color(hex: "#666666"))
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#999999"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            Divider()
                .background(Color(hex: "#E0E0E0"))
            
            // Content with performance optimization
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if isContentLoaded {
                        // Use the existing renderMarkdown function from helpers
                        Text(PoemDetailView.renderMarkdown(note.noteContent ?? ""))
                            .font(.body)
                            .foregroundColor(Color(hex: "#1A1A1A"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .transition(.opacity)
                    } else {
                        // Skeleton loader for better perceived performance
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(0..<3) { _ in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: "#F0F0F0"))
                                    .frame(height: 20)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.5)
            
            Divider()
                .background(Color(hex: "#E0E0E0"))
            
            // Action buttons
            HStack(spacing: 0) {
                actionButton(title: "Edit", icon: "pencil", color: "#007AFF", action: onEdit)
                
                Divider()
                    .frame(width: 1, height: 44)
                    .background(Color(hex: "#E0E0E0"))
                
                actionButton(title: "Copy", icon: "doc.on.clipboard", color: "#007AFF", action: onCopy)
                
                Divider()
                    .frame(width: 1, height: 44)
                    .background(Color(hex: "#E0E0E0"))
                
                actionButton(title: "Delete", icon: "trash", color: "#FF3B30", action: onDelete)
            }
            .frame(height: 50)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(20)
        .onAppear {
            // Load content immediately for faster preview
            withAnimation(.easeIn(duration: 0.1)) {
                isContentLoaded = true
            }
        }
    }
    
    @ViewBuilder
    private func actionButton(title: String, icon: String, color: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundColor(Color(hex: color))
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDateCompact(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview("With Notes") {
    @Previewable @State var mockContainer = {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(
                for: RequestEnhanced.self, ResponseEnhanced.self, PoemGroup.self, PoemRevision.self, PoemNote.self,
                configurations: config
            )
            
            // Create sample response
            let context = container.mainContext
            let response = ResponseEnhanced(
                content: """
                Crisp leaves underfoot
                Steam rises from coffee cup
                Dawn breaks through the mist
                
                Golden light cascades
                Through branches bare and reaching
                Nature's quiet song
                
                Morning frost sparkles
                On grass blades bent with dew drops
                Autumn's gentle kiss
                """,
                isFavorite: true
            )
            context.insert(response)
            
            // Create two overall notes
            let note1 = PoemNote(
                responseId: response.id,
                lineNumber: nil,
                noteContent: "This haiku beautifully captures the essence of autumn mornings. The imagery of **crisp leaves** and **steam rising** creates a multisensory experience that immediately places the reader in the scene.",
                colorHex: "#E3F2FD",
                createdAt: Date().addingTimeInterval(-3600) // 1 hour ago
            )
            context.insert(note1)
            
            let note2 = PoemNote(
                responseId: response.id,
                lineNumber: nil,
                noteContent: "Consider exploring the contrast between warmth and cold more deeply. The *coffee cup* provides warmth against the *frost*, which could be emphasized further in future revisions.",
                colorHex: "#FFF3E0",
                createdAt: Date().addingTimeInterval(-7200) // 2 hours ago
            )
            context.insert(note2)
            
            try context.save()
            
            return container
        } catch {
            fatalError("Failed to create preview container")
        }
    }()
    
    let response = ResponseEnhanced(
        content: """
        Crisp leaves underfoot
        Steam rises from coffee cup
        Dawn breaks through the mist
        
        Golden light cascades
        Through branches bare and reaching
        Nature's quiet song
        
        Morning frost sparkles
        On grass blades bent with dew drops
        Autumn's gentle kiss
        """,
        isFavorite: true
    )
    
    PoemDetailView(
        request: RequestEnhanced(
            userTopic: "Autumn Morning", 
            poemType: PoemType.all[0],
            temperature: Temperature.all[0]
        ),
        response: response
    )
    .modelContainer(mockContainer)
    .environment(DataManager(
        modelContext: mockContainer.mainContext,
        syncManager: CloudKitSyncManager(
            modelContext: mockContainer.mainContext,
            configuration: DefaultConfiguration()
        )
    ))
}

#Preview("Long Poem") {
    @Previewable @State var mockContainer = {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(
                for: RequestEnhanced.self, ResponseEnhanced.self, PoemGroup.self, PoemRevision.self, PoemNote.self,
                configurations: config
            )
            return container
        } catch {
            fatalError("Failed to create preview container")
        }
    }()
    
    PoemDetailView(
        request: RequestEnhanced(
            userTopic: "The Ocean",
            poemType: PoemType.all[0],
            temperature: Temperature.all[0]
        ),
        response: ResponseEnhanced(
            content: """
            The waves crash endlessly against the shore
            Each one unique in its fury and grace
            Salt spray kisses the weathered rocks
            As seagulls dance overhead in the morning light
            
            I stand here, small against the vast horizon
            Feeling the pull of tides within my chest
            The ocean speaks in languages older than words
            Telling stories of ships and storms and silence
            
            Beneath the surface, worlds unknown persist
            Creatures of the deep move in ancient rhythms
            Coral gardens sway in underwater winds
            While sunlight filters down in cathedral rays
            
            Time loses meaning at the water's edge
            Past and future merge in the eternal now
            The ocean remembers everything and nothing
            Its memory written in shells upon the sand
            
            I gather smooth stones, each one a meditation
            Worn perfect by the patient work of waves
            In my pocket they click like worry beads
            Reminders of this moment by the sea
            """,
            isFavorite: false
        )
    )
    .modelContainer(mockContainer)
    .environment(DataManager(
        modelContext: mockContainer.mainContext,
        syncManager: CloudKitSyncManager(
            modelContext: mockContainer.mainContext,
            configuration: DefaultConfiguration()
        )
    ))
}


