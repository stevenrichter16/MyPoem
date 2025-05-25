import SwiftUI
struct InputBarView: View {
    @Binding var inputText: String
    @Binding var selectedPoemType: PoemType
    var onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Combined input field with poem type
            HStack(spacing: 8) {
                // Poem type pill
                Menu {
                    ForEach(PoemType.all, id: \.self) { poemType in
                        Button(poemType.name) {
                            selectedPoemType = poemType
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedPoemType.name)
                            .font(.footnote)
                            .foregroundColor(.white)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.7)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                }
                
                // Divider
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 1, height: 24)
                
                // Text input field
                TextField("Enter a topic…", text: $inputText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.tertiarySystemBackground))
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            )
            
            // Send button
            Button {
                onSend()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .offset(x: 1, y: 0)
                }
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

#Preview {
    ZStack {
        // Background to show the floating effect
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
        
        // Preview with state
        InputBarPreview()
    }
}

// A wrapper to handle the @Binding properties for preview
struct InputBarPreview: View {
    @State private var inputText: String = ""
    @State private var selectedPoemType: PoemType = PoemType.all[0]
    
    var body: some View {
        VStack {
            Spacer()
            
            InputBarView(
                inputText: $inputText,
                selectedPoemType: $selectedPoemType
            ) {
                // Dummy action for preview
                print("Send button tapped")
            }
        }
    }
}
