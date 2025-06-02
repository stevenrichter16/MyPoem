//
//  FavoritesView.swift
//  MyPoem
//
//  Created by Steven Richter on 5/18/25.
//
import SwiftUI
import SwiftData

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
        NavigationStack {
            VStack(spacing: 0) {
                if filteredFavorites.isEmpty {
                    EmptyFavoritesView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredFavorites, id: \.id) { request in
                                if let id = request.id {
                                    FavoriteCardView(request: request)
                                        .id(id)
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
            .padding(.horizontal)
        }
    }
}

struct EmptyFavoritesView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(appState.activeFilter == nil ?
                 "No favorites yet" :
                 "No \(appState.activeFilter!.name.lowercased()) favorites yet")
                .font(.title3)
                .foregroundColor(.secondary)
            
            Text("Tap the heart icon on any poem to add it to your favorites")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FavoriteCardView: View {
    let request: RequestEnhanced
    @Environment(DataManager.self) private var dataManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let poemType = request.poemType {
                    Text(poemType.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    toggleFavorite()
                } label: {
                    if let response = dataManager.response(for: request) {
                        Image(systemName: (response.isFavorite ?? false) ? "heart.fill" : "heart")
                            .foregroundColor((response.isFavorite ?? false) ? Color.purple.opacity(0.6) : .gray)
                    }
                }
            }

            Text(request.userInput ?? "")
                .font(.headline)
                .foregroundColor(.primary)

            if let resp = dataManager.response(for: request) {
                Text(resp.content ?? "")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(5)

                HStack {
                    if resp.syncStatus != .synced {
                        Image(systemName: "icloud.and.arrow.up")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                    
                    if let date = resp.dateCreated {
                        Text(timeFmt.string(from: date))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 3)
    }

    private let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mma"
        f.amSymbol = "am"
        f.pmSymbol = "pm"
        return f
    }()

    private func toggleFavorite() {
        Task {
            do {
                try await dataManager.toggleFavorite(for: request)
            } catch {
                print("Failed to toggle favorite: \(error)")
            }
        }
    }
}
