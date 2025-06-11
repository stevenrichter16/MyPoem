import SwiftUI
import AVFoundation
import SwiftData

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
    
    // Audio recording states
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isRecording = false
    @State private var isPlaying = false
    @State private var audioNoteURL: URL?
    @State private var recordingTime: TimeInterval = 0
    @State private var recordingTimer: Timer?
    @State private var playbackProgress: Double = 0
    @State private var playbackTimer: Timer?
    @State private var isDraggingScrubber = false
    
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
        .sheet(isPresented: $showingNoteEditor) {
            noteEditorSheet
        }
        .sheet(isPresented: $showingRevisionHistory) {
            PoemRevisionTimelineView(request: request)
        }
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
                HStack(alignment: .top, spacing: 16) {
                    HStack(spacing: 2) {
                        // Color dot indicator
                        if let note = noteForLine(lineNumber: index) {
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
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Text(line)
                                .font(.custom("Georgia", size: 18))
                                .foregroundColor(Color(hex: "#1A1A1A"))
                                .lineSpacing(4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Note indicator
                            if lineHasNote(lineNumber: index) {
                                Image(systemName: "note.text")
                                    .font(.caption)
                                    .foregroundColor(Color(hex: "#666666"))
                            }
                        }
                        
                        // Show existing note if any
                        if let note = noteForLine(lineNumber: index) {
                            Text(note.noteContent ?? "")
                                .font(.caption)
                                .foregroundColor(Color(hex: "#333333"))
                                .italic()
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: note.colorHex ?? "#F5F5F5"))
                                .cornerRadius(4)
                        }
                        
                        // Show action buttons only for selected line
                        if selectedLineIndex == index && showingLineActions {
                            HStack(spacing: 12) {
                                Button(action: {
                                    editingNoteForLine = index
                                    let existingNote = noteForLine(lineNumber: index)
                                    noteContent = existingNote?.noteContent ?? ""
                                    selectedColorHex = existingNote?.colorHex ?? "#F5F5F5"
                                    showingNoteEditor = true
                                }) {
                                    Label(lineHasNote(lineNumber: index) ? "Edit Note" : "Add Note", 
                                          systemImage: lineHasNote(lineNumber: index) ? "note.text" : "note.text.badge.plus")
                                        .font(.caption)
                                        .foregroundColor(Color(hex: "#007AFF"))
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                // Disabled Get Suggestion button
//                                Button(action: {
//                                    // Future: AI suggestions
//                                }) {
//                                    Label("Get Suggestions", systemImage: "sparkles")
//                                        .font(.caption)
//                                        .foregroundColor(Color(hex: "#9C27B0"))
//                                }
//                                .buttonStyle(BorderlessButtonStyle())
                            }
                            .padding(.top, 4)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 2)
                .padding(.trailing, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selectedLineIndex == index ? Color(hex: "#007AFF").opacity(0.05) : Color.clear)
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if selectedLineIndex == index {
                            showingLineActions.toggle()
                        } else {
                            selectedLineIndex = index
                            showingLineActions = true
                        }
                    }
                }
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
                    selectedLineIndex = nil
                    showingLineActions = false
                }
            }
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Overall Notes")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#1A1A1A"))
                
                Spacer()
                
                Button(action: {
                    editingNoteForLine = nil // nil indicates overall poem note
                    let existingNote = poemNotes.first { $0.lineNumber == nil }
                    noteContent = existingNote?.noteContent ?? ""
                    selectedColorHex = existingNote?.colorHex ?? "#F5F5F5"
                    showingNoteEditor = true
                }) {
                    Image(systemName: overallPoemHasNote() ? "square.and.pencil" : "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "#007AFF"))
                }
            }
            
            // Display overall poem note (single note)
            if let overallNote = poemNotes.first(where: { $0.lineNumber == nil }) {
                VStack(alignment: .leading, spacing: 8) {
                    // Use markdown rendering for overall notes
                    Text(renderMarkdown(overallNote.noteContent ?? ""))
                        .font(.body)
                        .foregroundColor(Color(hex: "#333333"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack {
                        Text(formatDate(overallNote.modifiedAt ?? overallNote.createdAt ?? Date()))
                            .font(.caption2)
                            .foregroundColor(Color(hex: "#999999"))
                        
                        Spacer()
                        
                        Button(action: {
                            editingNoteForLine = nil
                            noteContent = overallNote.noteContent ?? ""
                            selectedColorHex = overallNote.colorHex ?? "#F5F5F5"
                            showingNoteEditor = true
                        }) {
                            Text("Edit")
                                .font(.caption)
                                .foregroundColor(Color(hex: "#007AFF"))
                        }
                    }
                }
                .padding(12)
                .background(Color(hex: overallNote.colorHex ?? "#F5F5F5"))
                .cornerRadius(8)
            } else {
                Text("Add notes about the overall poem, themes, or revision plans")
                    .font(.caption)
                    .foregroundColor(Color(hex: "#999999"))
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color(hex: "#F5F5F5"))
                    .cornerRadius(8)
            }
        }
        .padding(.top, 20)
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
                        if isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    }) {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(isRecording ? Color(hex: "#FF3B30") : Color(hex: "#007AFF"))
                    }
                    .disabled(isPlaying)
                    
                    if audioNoteURL != nil {
                        // Rewind button
                        Button(action: {
                            seekAudio(by: -10)
                        }) {
                            Image(systemName: "gobackward.10")
                                .font(.system(size: 32))
                                .foregroundColor(Color(hex: "#007AFF"))
                        }
                        .disabled(isRecording)
                        
                        // Play button
                        Button(action: {
                            if isPlaying {
                                stopPlaying()
                            } else {
                                playRecording()
                            }
                        }) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(Color(hex: "#34C759"))
                        }
                        .disabled(isRecording)
                        
                        // Fast forward button
                        Button(action: {
                            seekAudio(by: 10)
                        }) {
                            Image(systemName: "goforward.10")
                                .font(.system(size: 32))
                                .foregroundColor(Color(hex: "#007AFF"))
                        }
                        .disabled(isRecording)
                        
                        // Delete button
                        Button(action: {
                            deleteRecording()
                        }) {
                            Image(systemName: "trash.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Color(hex: "#FF3B30"))
                        }
                        .disabled(isRecording || isPlaying)
                    }
                }
                
                // Recording time or status
                if isRecording {
                    Text("Recording... \(formatTime(recordingTime))")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#FF3B30"))
                } else if isPlaying {
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
                                    .frame(width: geometry.size.width * playbackProgress, height: 4)
                                    .animation(isDraggingScrubber ? nil : .linear(duration: 0.03), value: playbackProgress)
                                
                                // Scrubber handle
                                Circle()
                                    .fill(Color(hex: "#34C759"))
                                    .frame(width: 12, height: 12)
                                    .offset(x: geometry.size.width * playbackProgress - 6)
                                    .animation(isDraggingScrubber ? nil : .linear(duration: 0.03), value: playbackProgress)
                            }
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        isDraggingScrubber = true
                                        let progress = min(max(0, value.location.x / geometry.size.width), 1)
                                        playbackProgress = progress
                                    }
                                    .onEnded { _ in
                                        scrubToPosition(playbackProgress)
                                        isDraggingScrubber = false
                                    }
                            )
                        }
                        .frame(height: 12)
                        
                        HStack {
                            Text(formatTime(recordingTime * playbackProgress))
                                .font(.caption2)
                                .foregroundColor(Color(hex: "#999999"))
                            
                            Spacer()
                            
                            Text(formatTime(recordingTime))
                                .font(.caption2)
                                .foregroundColor(Color(hex: "#999999"))
                        }
                    }
                    .padding(.horizontal, 40)
                } else if audioNoteURL != nil {
                    VStack(spacing: 4) {
                        Text("Audio note saved")
                            .font(.caption)
                            .foregroundColor(Color(hex: "#666666"))
                        Text("Duration: \(formatTime(recordingTime))")
                            .font(.caption2)
                            .foregroundColor(Color(hex: "#999999"))
                    }
                } else {
                    Text("Tap to record your thoughts about this poem")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#999999"))
                        .italic()
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
            .navigationTitle(editingNoteForLine != nil ? "Line Note" : "Overall Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        noteContent = ""
                        selectedColorHex = "#F5F5F5"
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
    
    private func lineHasNote(lineNumber: Int) -> Bool {
        poemNotes.contains { $0.lineNumber == lineNumber }
    }
    
    private func noteForLine(lineNumber: Int) -> PoemNote? {
        poemNotes.first { $0.lineNumber == lineNumber }
    }
    
    private func overallPoemHasNote() -> Bool {
        poemNotes.contains { $0.lineNumber == nil }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func renderMarkdown(_ text: String) -> AttributedString {
        do {
            var options = AttributedString.MarkdownParsingOptions()
            options.interpretedSyntax = .inlineOnlyPreservingWhitespace
            return try AttributedString(markdown: text, options: options)
        } catch {
            // If markdown parsing fails, return plain text
            return AttributedString(text)
        }
    }
    
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
            if let existingNote = noteForLine(lineNumber: lineIndex) {
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
            // Check if overall note exists (lineNumber = nil)
            if let existingNote = poemNotes.first(where: { $0.lineNumber == nil }) {
                // Update existing overall note
                existingNote.colorHex = selectedColorHex
                try await dataManager.updateNote(existingNote, content: noteContent)
            } else {
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
            showingNoteEditor = false
        } catch {
            print("Failed to save overall note: \(error)")
        }
    }
    
    // MARK: - Audio Recording Functions
    
    private func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            let fileName = "\(response.id ?? UUID().uuidString)_audio.m4a"
            let audioURL = AudioNote.documentsDirectory.appendingPathComponent(fileName)
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.record()
            
            isRecording = true
            recordingTime = 0
            audioNoteURL = audioURL
            
            // Start timer to track recording time
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                recordingTime += 1
            }
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    private func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Save audio note to database
        if let url = audioNoteURL {
            Task {
                do {
                    _ = try await dataManager.createAudioNote(
                        for: response,
                        audioFileName: url.lastPathComponent,
                        duration: recordingTime
                    )
                } catch {
                    print("Failed to save audio note: \(error)")
                }
            }
        }
    }
    
    private func playRecording() {
        guard let url = audioNoteURL else { return }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = AVAudioPlayerDelegateWrapper {
                Task { @MainActor in
                    self.isPlaying = false
                    self.playbackProgress = 0
                    self.playbackTimer?.invalidate()
                    self.playbackTimer = nil
                }
            }
            audioPlayer?.play()
            isPlaying = true
            playbackProgress = 0
            
            // Start timer to update progress with higher frequency for smooth animation
            playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
                if !self.isDraggingScrubber, let player = self.audioPlayer, player.duration > 0 {
                    withAnimation(.linear(duration: 0.03)) {
                        self.playbackProgress = player.currentTime / player.duration
                    }
                }
            }
        } catch {
            print("Failed to play recording: \(error)")
        }
    }
    
    private func stopPlaying() {
        audioPlayer?.stop()
        isPlaying = false
        playbackProgress = 0
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func deleteRecording() {
        if let url = audioNoteURL {
            try? FileManager.default.removeItem(at: url)
            audioNoteURL = nil
            
            // Delete from database
            Task {
                if let audioNote = try? await dataManager.fetchAudioNote(for: response) {
                    try? await dataManager.deleteAudioNote(audioNote)
                }
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func loadAudioNote() async {
        do {
            if let audioNote = try await dataManager.fetchAudioNote(for: response) {
                audioNoteURL = audioNote.audioFileURL
                recordingTime = audioNote.duration ?? 0
            }
        } catch {
            print("Failed to load audio note: \(error)")
        }
    }
    
    private func seekAudio(by seconds: TimeInterval) {
        guard let player = audioPlayer else { return }
        
        let newTime = player.currentTime + seconds
        let clampedTime = min(max(0, newTime), player.duration)
        player.currentTime = clampedTime
        
        // Update progress immediately
        if player.duration > 0 {
            playbackProgress = clampedTime / player.duration
        }
    }
    
    private func scrubToPosition(_ progress: Double) {
        guard let player = audioPlayer else { return }
        
        let newTime = player.duration * progress
        player.currentTime = newTime
        // Don't update playbackProgress here - let the timer do it or it's already set by drag
    }
}

// Helper class for AVAudioPlayerDelegate
class AVAudioPlayerDelegateWrapper: NSObject, AVAudioPlayerDelegate {
    let completion: () -> Void
    
    init(completion: @escaping () -> Void) {
        self.completion = completion
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        completion()
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
            return container
        } catch {
            fatalError("Failed to create preview container")
        }
    }()
    
    PoemDetailView(
        request: RequestEnhanced(
            userTopic: "Autumn Morning", 
            poemType: PoemType.all[0],
            temperature: Temperature.all[0]
        ),
        response: ResponseEnhanced(
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


