// FavoritesView.swift - Minimalist Redesign
import SwiftUI

struct FavoritesView: View {
    @Environment(DataManager.self) private var dataManager
    @Environment(AppState.self) private var appState
    
    private var filteredFavorites: [RequestEnhanced] {
        let favorites = dataManager.favoriteRequests
        
        if let filter = appState.activeFilter {
            return favorites.filter { $0.poemType?.id == filter.id }
        } else {
            return favorites
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                Text("Favorites")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A1A"))
                    .kerning(-0.5)
                    .padding(.horizontal, 20)
                    .padding(.top, 50)
                    .padding(.bottom, 30)
                
                // Content
                if filteredFavorites.isEmpty {
                    MinimalistFavoritesEmptyState()
                        .frame(minHeight: 400)
                        .padding(.top, 100)
                } else {
                    LazyVStack(spacing: 60) {
                        ForEach(filteredFavorites, id: \.id) { request in
                            if let id = request.id {
                                PoemCardView(request: request)
                                    .id(id)
                            }
                        }
                    }
                    .padding(.vertical, 20)
                    .padding(.bottom, 100)
                }
            }
        }
        .background(Color(hex: "FAFAFA"))
        .navigationBarHidden(true)
    }
}

// MARK: - Minimalist Empty State for Favorites
struct MinimalistFavoritesEmptyState: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.slash")
                .font(.system(size: 64))
                .foregroundColor(Color(hex: "1A1A1A").opacity(0.1))
            
            Text(appState.activeFilter == nil ?
                 "No favorites yet" :
                 "No \(appState.activeFilter!.name.lowercased()) favorites yet")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(Color(hex: "666666"))
            
            Text("Tap the heart icon on any poem to add it to your favorites")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "999999"))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)
        }
    }
}
