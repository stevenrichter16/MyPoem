//
//  FavoritesView.swift
//  MyPoem
//
//  Created by Steven Richter on 5/18/25.
//
import SwiftUI
import SwiftData

struct FavoritesView: View {
    @EnvironmentObject private var dataManager: DataManager
    @EnvironmentObject private var poemFilterSettings: PoemFilterSettings
    
    // Computed property for filtered favorites
    private var filteredFavorites: [RequestEnhanced] {
        let favorites = dataManager.favoriteRequests()
        
        if let filter = poemFilterSettings.activeFilter {
            return favorites.filter { $0.poemType.id == filter.id }
        } else {
            return favorites
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if filteredFavorites.isEmpty {
                Text(poemFilterSettings.activeFilter == nil ? "No favorites yet." : "No \(poemFilterSettings.activeFilter!.name.lowercased()) favorites yet.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredFavorites, id: \.id) { req in
                            FavoriteCardView(request: req)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("Favorites")
        .padding(.horizontal)
    }
}

// A simplified card view for Favorites, no resend options
struct FavoriteCardView: View {
    @ObservedObject var request: RequestEnhanced
    @EnvironmentObject private var dataManager: DataManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(request.poemType.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                
                Button {
                    toggleFavorite()
                } label: {
                    if let response = dataManager.response(for: request) {
                        Image(systemName: response.isFavorite ? "heart.fill" : "heart")
                            .foregroundColor(response.isFavorite ? Color.purple.opacity(0.6) : .gray)
                    } else {
                        Image(systemName: "heart")
                            .foregroundColor(.gray)
                    }
                }
            }

            Text(request.userInput)
                .font(.headline)
                .foregroundColor(.primary)

            if let resp = dataManager.response(for: request) {
                Text(resp.content)
                    .font(.body)
                    .foregroundColor(.secondary)

                HStack {
                    Spacer()
                    Text(Self.timeFmt.string(from: resp.dateCreated))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 3)
    }

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mma"
        f.amSymbol = "am"
        f.pmSymbol = "pm"
        return f
    }()

    private func toggleFavorite() {
        guard let resp = dataManager.response(for: request) else { return }
        resp.isFavorite.toggle()
        
        do {
            try dataManager.save(response: resp)
        } catch {
            print("Failed to save favorite status: \(error)")
        }
    }
}

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

    // Create mock PoemType and Temperature
    let mockPoemType = PoemType.all[0]
    let mockTemp = Temperature.all[0]

    // Create first favorite request + response
    let req1 = RequestEnhanced(
        userInput: "whispers in the trees",
        userTopic: "Nature",
        poemType: mockPoemType,
        temperature: mockTemp
    )
    let resp1 = ResponseEnhanced(
        requestId: req1.id,
        userId: "user123",
        content: "Whispers in the trees\nSoftly speak of ancient winds\nEchoes in the leaves.",
        role: "assistant",
        isFavorite: true,
        hasAnimated: true
    )
    req1.responseId = resp1.id

    // Create second favorite request + response
    let req2 = RequestEnhanced(
        userInput: "ocean lullaby",
        userTopic: "Sea",
        poemType: mockPoemType,
        temperature: mockTemp
    )
    let resp2 = ResponseEnhanced(
        requestId: req2.id,
        userId: "user456",
        content: "Waves hum through the night\nCradling moonlight in rhythm\nOcean's lullaby.",
        role: "assistant",
        isFavorite: true,
        hasAnimated: true
    )
    req2.responseId = resp2.id

    // Save to DataManager
    try! dataManager.save(request: req1)
    try! dataManager.save(response: resp1)
    try! dataManager.save(request: req2)
    try! dataManager.save(response: resp2)

    return FavoritesView()
        .environmentObject(dataManager)
        .environmentObject(PoemFilterSettings())
}
