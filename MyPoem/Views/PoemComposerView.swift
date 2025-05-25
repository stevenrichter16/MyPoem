import SwiftUI

struct PoemComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedPoemType: PoemType
    @Binding var selectedTemperature: Temperature
    var onSubmit: (String) -> Void
    
    @State private var topicInput: String = ""
    @State private var showingPoemTypeDetails = false
    @FocusState private var isTextFieldFocused: Bool
    
    private var isValidInput: Bool {
        !topicInput.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private var poemTypeColor: Color {
        switch selectedPoemType.name.lowercased() {
        case "haiku": return .blue
        case "sonnet": return .purple
        case "free verse": return .green
        case "limerick": return .orange
        case "ballad": return .red
        default: return .gray
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with poem type selection
                headerSection
                
                // Main input area
                inputSection
                
                // Poem type info
                infoSection
                
                Spacer()
                
                // Submit button
                submitSection
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Poem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Auto-focus on text field when composer appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }
    
    // MARK: - Header Section
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Poem type selector
            HStack {
                Text("Poem Type")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Menu {
                    ForEach(PoemType.all, id: \.self) { poemType in
                        Button(poemType.name) {
                            selectedPoemType = poemType
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(poemTypeColor)
                            .frame(width: 10, height: 10)
                        
                        Text(selectedPoemType.name)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())
                }
            }
            
            // Temperature selector (creativity)
//            HStack {
//                Text("Creativity")
//                    .font(.headline)
//                    .foregroundColor(.primary)
//                
//                Spacer()
//                
//                Menu {
//                    ForEach(Temperature.all, id: \.self) { temperature in
//                        Button(temperature.description) {
//                            selectedTemperature = temperature
//                        }
//                    }
//                } label: {
//                    HStack(spacing: 8) {
//                        Text(selectedTemperature.description)
//                            .font(.body)
//                            .fontWeight(.medium)
//                            .foregroundColor(.primary)
//                        
//                        Image(systemName: "chevron.up.chevron.down")
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                    }
//                    .padding(.horizontal, 16)
//                    .padding(.vertical, 10)
//                    .background(Color(.secondarySystemBackground))
//                    .clipShape(Capsule())
//                }
//            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Input Section
    @ViewBuilder
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Topic")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !topicInput.isEmpty {
                    Text("\(topicInput.count) characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Multi-line text input
            TextEditor(text: $topicInput)
                .focused($isTextFieldFocused)
                .font(.body)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(minHeight: 120)
                .overlay(
                    // Placeholder when empty
                    topicInput.isEmpty ?
                    VStack {
                        HStack {
                            Text("What would you like your \(selectedPoemType.name.lowercased()) to be about?")
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.top, 20)
                            Spacer()
                        }
                        Spacer()
                    }
                    : nil
                )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Info Section
    @ViewBuilder
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(poemTypeColor)
                
                Text("About \(selectedPoemType.name)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text(poemTypeDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(poemTypeColor.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(poemTypeColor.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Submit Section
    @ViewBuilder
    private var submitSection: some View {
        Button(action: {
            onSubmit(topicInput)
        }) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .font(.body)
                
                Text("Create \(selectedPoemType.name)")
                    .font(.headline)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isValidInput ?
                        LinearGradient(
                            colors: [poemTypeColor, poemTypeColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.gray, Color.gray.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: isValidInput ? poemTypeColor.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
        }
        .disabled(!isValidInput)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    // MARK: - Helper Properties
    private var poemTypeDescription: String {
        switch selectedPoemType.name.lowercased() {
        case "haiku":
            return "A traditional Japanese poem with three lines following a 5-7-5 syllable pattern, often capturing nature or emotions."
        case "sonnet":
            return "A 14-line poem with a specific rhyme scheme, traditionally expressing deep thoughts about love, beauty, or mortality."
        case "free verse":
            return "Poetry without regular patterns of rhyme or rhythm, allowing for creative expression and natural speech patterns."
        case "limerick":
            return "A humorous five-line poem with an AABBA rhyme scheme, often featuring witty or nonsensical content."
        case "ballad":
            return "A narrative poem that tells a story, often set to music, with a rhyme scheme and meter that creates rhythm."
        default:
            return "Express your creativity through the art of poetry."
        }
    }
}

// MARK: - Preview
#Preview {
    PoemComposerView(
        selectedPoemType: .constant(PoemType.all[0]),
        selectedTemperature: .constant(Temperature.all[0])
    ) { topic in
        print("Creating poem about: \(topic)")
    }
}
