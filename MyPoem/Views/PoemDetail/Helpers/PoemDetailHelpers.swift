import SwiftUI

// MARK: - Helper Functions
extension PoemDetailView {
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    static func renderMarkdown(_ text: String) -> AttributedString {
        do {
            var options = AttributedString.MarkdownParsingOptions()
            options.interpretedSyntax = .inlineOnlyPreservingWhitespace
            return try AttributedString(markdown: text, options: options)
        } catch {
            // If markdown parsing fails, return plain text
            return AttributedString(text)
        }
    }
    
    func renderMarkdown(_ text: String) -> AttributedString {
        PoemDetailView.renderMarkdown(text)
    }
    
    // Note helper functions
    func lineHasNote(lineNumber: Int, in notes: [PoemNote]) -> Bool {
        notes.contains { $0.lineNumber == lineNumber }
    }
    
    func noteForLine(lineNumber: Int, in notes: [PoemNote]) -> PoemNote? {
        notes.first { $0.lineNumber == lineNumber }
    }
    
    func overallPoemHasNote(in notes: [PoemNote]) -> Bool {
        notes.contains { $0.lineNumber == nil }
    }
}
