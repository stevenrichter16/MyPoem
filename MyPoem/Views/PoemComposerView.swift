// PoemComposerView.swift - Minimalist Redesign
import SwiftUI

struct PoemComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedPoemType: PoemType
    @Binding var selectedTemperature: Temperature
    var onSubmit: (String, String?, String?) -> Void // Updated to include variationId and suggestions
    
    @State private var topicInput: String = ""
    @State private var selectedVariationId: String? = nil
    @State private var suggestionsInput: String = ""
    @State private var showSuggestions: Bool = false
    @FocusState private var isTextFieldFocused: Bool
    @FocusState private var isSuggestionsFocused: Bool
    
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
                        let suggestions = suggestionsInput.isEmpty ? nil : suggestionsInput
                        onSubmit(topicInput, selectedVariationId, suggestions)
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
                        
                        // Suggestions Section
                        VStack(alignment: .leading, spacing: 8) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showSuggestions.toggle()
                                    if showSuggestions {
                                        isSuggestionsFocused = true
                                    }
                                }
                            }) {
                                HStack {
                                    Text("SUGGESTIONS")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color(hex: "666666"))
                                        .kerning(0.5)
                                    
                                    Spacer()
                                    
                                    Image(systemName: showSuggestions ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color(hex: "666666"))
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if showSuggestions {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Guide the AI with specific instructions")
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(hex: "999999"))
                                    
                                    TextEditor(text: $suggestionsInput)
                                        .focused($isSuggestionsFocused)
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hex: "1A1A1A"))
                                        .scrollContentBackground(.hidden)
                                        .background(Color(hex: "F5F5F5"))
                                        .cornerRadius(8)
                                        .frame(minHeight: 80)
                                        .overlay(
                                            Group {
                                                if suggestionsInput.isEmpty {
                                                    Text("e.g., \"Avoid mentioning the sea\" or \"Focus on tactile sensations\" or \"Use archaic language\"")
                                                        .font(.system(size: 16))
                                                        .foregroundColor(Color(hex: "999999"))
                                                        .allowsHitTesting(false)
                                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                                        .padding(8)
                                                }
                                            }
                                        )
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
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
                                        action: { 
                                            selectedPoemType = poemType
                                            selectedVariationId = poemType.defaultVariation.id
                                        }
                                    )
                                }
                            }
                        }
                        
                        // Variation Selection
                        if !selectedPoemType.variations.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("STYLE")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(hex: "666666"))
                                    .kerning(0.5)
                                
                                ForEach(selectedPoemType.variations) { variation in
                                    MinimalistVariationButton(
                                        variation: variation,
                                        isSelected: selectedVariationId == variation.id || (selectedVariationId == nil && variation.id == selectedPoemType.defaultVariation.id),
                                        action: { selectedVariationId = variation.id }
                                    )
                                }
                            }
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
            // Set default variation when appearing
            selectedVariationId = selectedPoemType.defaultVariation.id
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

// MARK: - Minimalist Variation Button
struct MinimalistVariationButton: View {
    let variation: PoemTypeVariation
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: variation.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? Color(hex: "1A1A1A") : Color(hex: "666666"))
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(variation.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "1A1A1A"))
                    
                    Text(variation.summary)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "666666"))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "1A1A1A"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(hex: "F5F5F5") : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color(hex: "1A1A1A") : Color(hex: "E0E0E0"), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
