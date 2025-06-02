// MainTabView.swift - Minimalist Redesign
import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(DataManager.self) private var dataManager
    @Environment(CloudKitSyncManager.self) private var syncManager
    
    var body: some View {
        @Bindable var appState = appState
        
        ZStack(alignment: .bottom) {
            // Main content area
            Group {
                switch appState.selectedTab {
                case 0:
                    CreateView()
                case 1:
                    BrowseView()
                case 2:
                    FavoritesView()
                default:
                    CreateView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Minimalist tab bar
            MinimalistTabBar()
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: Binding(
            get: { appState.showingSyncConflicts },
            set: { _ in appState.dismissSyncConflicts() }
        )) {
            ConflictResolutionView(conflictedItems: appState.conflictedItems)
        }
        .alert("Sync Error", isPresented: Binding(
            get: { appState.showingCloudKitError },
            set: { _ in appState.dismissCloudKitError() }
        )) {
            Button("OK") {
                appState.dismissCloudKitError()
            }
            Button("Retry") {
                Task {
                    await dataManager.triggerSync()
                }
                appState.dismissCloudKitError()
            }
        } message: {
            Text(appState.cloudKitErrorMessage ?? "An error occurred while syncing")
        }
    }
}

// MARK: - Minimalist Tab Bar
struct MinimalistTabBar: View {
    @Environment(AppState.self) private var appState
    @Environment(DataManager.self) private var dataManager
    
    private let tabs: [(icon: String, label: String)] = [
        ("plus.circle.fill", "Create"),
        ("square.grid.2x2", "Browse"),
        ("heart", "Favorites")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                MinimalistTabItem(
                    icon: tabs[index].icon,
                    label: tabs[index].label,
                    isActive: appState.selectedTab == index,
                    hasUnsyncedChanges: index == 0 && dataManager.hasUnsyncedChanges
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        appState.navigateToTab(index)
                    }
                    
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .frame(height: 80)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .background(Color.white.opacity(0.95))
                .ignoresSafeArea()
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.black.opacity(0.05)),
                    alignment: .top
                )
        )
    }
}

// MARK: - Minimalist Tab Item
struct MinimalistTabItem: View {
    let icon: String
    let label: String
    let isActive: Bool
    let hasUnsyncedChanges: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(isActive ? Color(hex: "1A1A1A") : Color(hex: "666666"))
                        .scaleEffect(isActive ? 1.15 : 1.0)
                    
                    // Sync indicator
                    if hasUnsyncedChanges {
                        Circle()
                            .fill(Color(hex: "FF9500"))
                            .frame(width: 6, height: 6)
                            .offset(x: 8, y: -2)
                    }
                }
                .frame(height: 28)
                
                Text(label)
                    .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? Color(hex: "1A1A1A") : Color(hex: "666666"))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive ? Color.black.opacity(0.05) : Color.clear)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}
