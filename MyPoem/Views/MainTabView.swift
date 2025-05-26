//
//  MainTabView.swift
//  MyPoem
//
//  Created by Steven Richter on 5/18/25.
//
import SwiftUI
import SwiftData

struct MainTabView: View {
    @EnvironmentObject private var dataManager: DataManager
    @EnvironmentObject private var chatService: ChatService
    @State private var selectedTab = 0
    @StateObject private var poemFilterSettings = PoemFilterSettings()
    @StateObject private var appUiSettings = AppUiSettings()
    @StateObject private var navigationManager = NavigationManager()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content area
            Group {
                switch selectedTab {
                case 0:
                    TestHarnessView()
                case 1:
                    BrowseView()
                        .environmentObject(navigationManager)
                case 2:
                    FavoritesView()
                default:
                    TestHarnessView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environmentObject(appUiSettings)
            .environmentObject(poemFilterSettings)
            .environmentObject(dataManager)
            .environmentObject(chatService)
            .environmentObject(navigationManager)
            
            // Custom tab bar
            VStack {
                Spacer()
                CustomTabBar(selectedTab: $selectedTab)
            }
        }
        .ignoresSafeArea(.keyboard) // Prevent tab bar from moving with keyboard
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    private let tabs: [(icon: String, selectedIcon: String, color: Color)] = [
        ("plus.circle", "plus.circle.fill", .blue),
        ("square.grid.2x2", "square.grid.2x2.fill", .purple),
        ("heart", "heart.fill", .red)
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                TabBarButton(
                    icon: tabs[index].icon,
                    selectedIcon: tabs[index].selectedIcon,
                    color: tabs[index].color,
                    isSelected: selectedTab == index
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        print("Current tab: \(index)")
                        print("Tab selected: \(selectedTab)")
                        if selectedTab == index {
                            switch index {
                            case 0:
                                // Create tab - scroll to bottom
                                NotificationCenter.default.post(name: .scrollToBottom, object: nil)
                                
                            case 1:
                                // Browse tab - pop to root
                                NotificationCenter.default.post(name: .popToBrowseRoot, object: nil)
                            default:
                                break
                            }
                        
                        } else {
                            selectedTab = index
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxHeight: 55)
        .ignoresSafeArea(edges: .bottom) // Extend to bottom edge
    }
}

struct TabBarButton: View {
    let icon: String
    let selectedIcon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            action()
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }) {
            VStack(spacing: 4) {
                ZStack {
                    // Background circle when selected
                    if isSelected {
                        Circle()
                            .fill(color.opacity(0.15))
                            .frame(width: 48, height: 48)
                            .scaleEffect(isPressed ? 0.95 : 1.0)
                    }
                    
                    // Icon
                    Image(systemName: isSelected ? selectedIcon : icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isSelected ? color : Color(.systemGray))
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                }
            }
            .frame(width: 80, height: 60) // Set visual frame size
            .contentShape(Rectangle()) // Make entire rectangular area tappable
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
}

// Add this extension
extension Notification.Name {
    static let popToBrowseRoot = Notification.Name("popToBrowseRoot")
    static let scrollToBottom = Notification.Name("scrollToBottom")
}

// MARK: - Preview
#Preview {
    let container = try! ModelContainer(
        for: RequestEnhanced.self, ResponseEnhanced.self, PoemGroup.self,
        configurations: ModelConfiguration(
            schema: Schema([RequestEnhanced.self, ResponseEnhanced.self, PoemGroup.self]),
            isStoredInMemoryOnly: true
        )
    )
    let context = container.mainContext
    let dataManager = DataManager(context: context)
    let chatService = ChatService(dataManager: dataManager)

    // Sample data for preview
    let mockPoemType = PoemType.all[0]
    let mockTemp = Temperature.all[0]

    let favoriteReq = RequestEnhanced(
        userInput: "a silent lake",
        userTopic: "Nature",
        poemType: mockPoemType,
        temperature: mockTemp
    )
    let favoriteResp = ResponseEnhanced(
        requestId: favoriteReq.id,
        userId: "previewer",
        content: "Still water reflects\nWhispers of wind and moonlight\nTime sleeps on the shore.",
        role: "assistant",
        isFavorite: true,
        hasAnimated: true
    )
    favoriteReq.responseId = favoriteResp.id

    let recentReq = RequestEnhanced(
        userInput: "a rainy night",
        userTopic: "Weather",
        poemType: mockPoemType,
        temperature: mockTemp
    )
    let recentResp = ResponseEnhanced(
        requestId: recentReq.id,
        userId: "previewer",
        content: "Raindrops tap the glass\nMidnight murmurs in the dark\nDreams bloom in the hush.",
        role: "assistant",
        isFavorite: false,
        hasAnimated: true
    )
    recentReq.responseId = recentResp.id

    try! dataManager.save(request: favoriteReq)
    try! dataManager.save(response: favoriteResp)
    try! dataManager.save(request: recentReq)
    try! dataManager.save(response: recentResp)

    return MainTabView()
        .environmentObject(dataManager)
        .environmentObject(chatService)
}

#Preview("Tab Bar Only") {
    ZStack {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            CustomTabBar(selectedTab: .constant(0))
        }
    }
}
