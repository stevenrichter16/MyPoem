// CreateView.swift - Minimalist Redesign
import SwiftUI

struct CreateView: View {
    @Environment(AppState.self) private var appState
    @Environment(DataManager.self) private var dataManager
    @Environment(ChatService.self) private var chatService
    
    @State private var selectedPoemType: PoemType = PoemType.all[0]
    @State private var selectedTemperature: Temperature = Temperature.all[0]
    @State private var showingComposer = false
    
    private var displayedRequests: [RequestEnhanced] {
        if let filter = appState.activeFilter {
            return dataManager.requests(for: filter)
        } else {
            return dataManager.sortedRequests // also dataManager.requests
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Minimalist background
                Color(hex: "FAFAFA")
                    .ignoresSafeArea()
                
                // Message history with new styling
                MessageHistoryView(requests: displayedRequests) // also dataManager.requests
                    .padding(.bottom, 80) // Space for tab bar
                
                // Minimalist Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        MinimalistFAB(
                            isGenerating: chatService.isGenerating,
                            action: { showingComposer = true }
                        )
                        .padding(.trailing, 20)
                        .padding(.bottom, 110)
                    }
                }
                
                // Poem creation status overlay with minimalist styling
                if appState.shouldShowCreationModal {
                    VStack {
                        MinimalistCreationStatus()
                            .padding(.top, 50)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingComposer) {
                PoemComposerView(
                    selectedPoemType: $selectedPoemType,
                    selectedTemperature: $selectedTemperature,
                    onSubmit: { topic, variationId, suggestions, mood in
                        appState.startPoemCreation(
                            type: selectedPoemType,
                            topic: topic,
                            variationId: variationId,
                            suggestions: suggestions,
                            mood: mood
                        )
                        showingComposer = false
                    }
                )
            }
        }
    }
}

// MARK: - Minimalist Floating Action Button
struct MinimalistFAB: View {
    let isGenerating: Bool
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(hex: "1A1A1A"))
                    .frame(width: 60, height: 60)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 4)
                
                if isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text("+")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(.white)
                }
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .rotationEffect(.degrees(isPressed ? 90 : 0))
        }
        .disabled(isGenerating)
        .buttonStyle(MinimalistButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Minimalist Creation Status
struct MinimalistCreationStatus: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        HStack(spacing: 16) {
            if appState.isCreatingPoem {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "1A1A1A")))
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(hex: "34C759"))
                    .font(.system(size: 20))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                if let poemType = appState.currentCreationType {
                    Text(appState.isCreatingPoem ? "Creating \(poemType.name)..." : "\(poemType.name) Created")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                    
                    if appState.isCreatingPoem,
                       let creation = appState.poemCreation {
                        Text(creation.topic)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "666666"))
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 20, x: 0, y: 2)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Button Style
struct MinimalistButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
