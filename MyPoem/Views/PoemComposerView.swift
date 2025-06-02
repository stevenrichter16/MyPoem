// PoemComposerView.swift - Minimalist Redesign
import SwiftUI

struct PoemComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedPoemType: PoemType
    @Binding var selectedTemperature: Temperature
    var onSubmit: (String) -> Void
    
    @State private var topicInput: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    private var isValidInput: Bool {
        !topicInput.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "666666"))
                    
                    Spacer()
                    
                    Text("New Poem")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                    
                    Spacer()
                    
                    Button("Create") {
                        onSubmit(topicInput)
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isValidInput ? Color(hex: "1A1A1A") : Color(hex: "999999"))
                    .disabled(!isValidInput)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                
                Divider()
                    .foregroundColor(Color(hex: "E0E0E0"))
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Topic Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TOPIC")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "666666"))
                                .kerning(0.5)
                            
                            TextEditor(text: $topicInput)
                                .focused($isTextFieldFocused)
                                .font(.system(size: 18))
                                .foregroundColor(Color(hex: "1A1A1A"))
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .frame(minHeight: 100)
                                .overlay(
                                    // Placeholder
                                    Group {
                                        if topicInput.isEmpty {
                                            Text("What would you like your poem to be about?")
                                                .font(.system(size: 18))
                                                .foregroundColor(Color(hex: "999999"))
                                                .allowsHitTesting(false)
                                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                                .padding(.top, 8)
                                        }
                                    }
                                )
                        }
                        
                        // Poem Type Selection
                        VStack(alignment: .leading, spacing: 16) {
                            Text("POEM TYPE")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "666666"))
                                .kerning(0.5)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(PoemType.all, id: \.self) { poemType in
                                    MinimalistTypeButton(
                                        poemType: poemType,
                                        isSelected: selectedPoemType.id == poemType.id,
                                        action: { selectedPoemType = poemType }
                                    )
                                }
                            }
                        }
                        
                        // Description of selected type
                        if let description = poemTypeDescription {
                            Text(description)
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "666666"))
                                .lineSpacing(4)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }
    
    private var poemTypeDescription: String? {
        switch selectedPoemType.name.lowercased() {
        case "haiku":
            return "A traditional Japanese poem with three lines following a 5-7-5 syllable pattern."
        case "sonnet":
            return "A 14-line poem with a specific rhyme scheme, traditionally expressing deep thoughts."
        case "free verse":
            return "Poetry without regular patterns of rhyme or rhythm, allowing for creative expression."
        case "limerick":
            return "A humorous five-line poem with an AABBA rhyme scheme."
        case "ballad":
            return "A narrative poem that tells a story, often set to music."
        default:
            return nil
        }
    }
}

// MARK: - Minimalist Type Button
struct MinimalistTypeButton: View {
    let poemType: PoemType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(poemType.name.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isSelected ? .white : Color(hex: "1A1A1A"))
                .kerning(0.5)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color(hex: "1A1A1A") : Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(hex: "E0E0E0"), lineWidth: isSelected ? 0 : 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
