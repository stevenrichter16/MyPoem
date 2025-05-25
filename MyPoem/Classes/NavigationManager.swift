// NavigationManager.swift
import SwiftUI

class NavigationManager: ObservableObject {
    @Published var selectedTab: Int = 0
    @Published var browseNavigationPath = NavigationPath()
    
    func navigateToTab(_ tab: Int) {
        selectedTab = tab
    }
    
    func popToBrowseRoot() {
        browseNavigationPath = NavigationPath()
    }
}
