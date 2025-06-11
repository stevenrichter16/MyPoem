import SwiftUI

struct ColorPaletteView: View {
    @Binding var selectedColorHex: String
    
    let colors: [(name: String, hex: String)] = [
        ("Neutral", "#F5F5F5"),
        ("Red", "#FFCDD2"),
        ("Green", "#C8E6C9"),
        ("Blue", "#BBDEFB"),
        ("Yellow", "#FFF9C4"),
        ("Purple", "#E1BEE7"),
        ("Orange", "#FFCCBC"),
        ("Teal", "#B2DFDB")
    ]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(colors, id: \.hex) { color in
                    ColorCircle(
                        colorHex: color.hex,
                        isSelected: selectedColorHex == color.hex,
                        action: {
                            selectedColorHex = color.hex
                        }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 40)
    }
}

struct ColorCircle: View {
    let colorHex: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(Color(hex: "#E0E0E0"), lineWidth: 1)
                    )
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(colorHex == "#F5F5F5" ? Color(hex: "#666666") : Color(hex: "#333333"))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    VStack {
        ColorPaletteView(selectedColorHex: .constant("#FFE5E5"))
            .padding()
        
        ColorPaletteView(selectedColorHex: .constant("#F5F5F5"))
            .padding()
    }
}