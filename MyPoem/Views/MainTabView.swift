// MainTabView.swift - Updated for CloudKit
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
            
            // Custom tab bar
            VStack {
                Spacer()
                CustomTabBar()
            }
        }
        .ignoresSafeArea(.keyboard)
        .overlay(alignment: .topTrailing) {
            // Sync status indicator
            SyncStatusView()
                .padding(.trailing, 16)
                .padding(.top, 8)
        }
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

struct CustomTabBar: View {
    @Environment(AppState.self) private var appState
    @Environment(DataManager.self) private var dataManager
    
    private let tabs: [(icon: String, selectedIcon: String, label: String, color: Color)] = [
        ("plus.circle", "plus.circle.fill", "Create", .blue),
        ("square.grid.2x2", "square.grid.2x2.fill", "Browse", .purple),
        ("heart", "heart.fill", "Favorites", .red)
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                TabBarButton(
                    icon: tabs[index].icon,
                    selectedIcon: tabs[index].selectedIcon,
                    label: tabs[index].label,
                    color: tabs[index].color,
                    isSelected: appState.selectedTab == index,
                    hasUnsyncedChanges: index == 0 && dataManager.hasUnsyncedChanges // Show indicator on Create tab
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        appState.navigateToTab(index)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(height: 65)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }
}

struct TabBarButton: View {
    let icon: String
    let selectedIcon: String
    let label: String
    let color: Color
    let isSelected: Bool
    let hasUnsyncedChanges: Bool
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
                    
                    // Icon with sync indicator
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: isSelected ? selectedIcon : icon)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(isSelected ? color : Color(.systemGray))
                            .scaleEffect(isSelected ? 1.1 : 1.0)
                            .scaleEffect(isPressed ? 0.9 : 1.0)
                        
                        // Unsynced changes indicator
                        if hasUnsyncedChanges {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                                .offset(x: 8, y: -8)
                        }
                    }
                }
                
                Text(label)
                    .font(.caption2)
                    .fontWeight(isSelected ? .medium : .regular)
                    .foregroundColor(isSelected ? color : Color(.systemGray))
            }
            .frame(width: 80, height: 60)
            .contentShape(Rectangle())
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
