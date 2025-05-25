//
//  FavoritesView.swift
//  MyPoem
//
//  Created by Steven Richter on 5/18/25.
//
import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Environment(\.modelContext) private var context: ModelContext
    
    // Add filter parameter
    @EnvironmentObject private var poemFilterSettings: PoemFilterSettings
    
    // Query all favorite requests
    @Query private var allFavoriteRequests: [Request]
    
    // Computed property for filtered favorites
    private var filteredFavorites: [Request] {
        let favorites = allFavoriteRequests.filter { $0.response?.isFavorite == true }
        
        if let filter = poemFilterSettings.activeFilter {
            return favorites.filter { $0.poemType.id == filter.id }
        } else {
            return favorites
        }
    }
    
    init(poemTypeFilter: PoemType? = nil) {
        // Initialize query with predicate for favorites and sorting
        self._allFavoriteRequests = Query(
            filter: #Predicate<Request> { request in
                request.response?.isFavorite == true
            },
            sort: \Request.createdAt,
            order: .reverse
        )
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
    @ObservedObject var request: Request
    @Environment(\.modelContext) private var context: ModelContext

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
                    Image(systemName: request.response?.isFavorite == true ? "heart.fill" : "heart")
                        .foregroundColor(request.response?.isFavorite == true ? Color.purple.opacity(0.6) : .gray)
                }
            }

            Text(request.userInput)
                .font(.headline)
                .foregroundColor(.primary)

            if let resp = request.response {
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
        guard let resp = request.response else { return }
        resp.isFavorite.toggle()
        try? context.save()
    }

    private func deleteRequest() {
        context.delete(request)
        try? context.save()
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Request.self, Response.self,
        configurations: ModelConfiguration(
            schema: Schema([Request.self, Response.self]),
            isStoredInMemoryOnly: true
        )
    )
    let context = container.mainContext

    // Create mock PoemType and Temperature
    let mockPoemType = PoemType.all[0]
    let mockTemp = Temperature.all[0]

    // Create first favorite request + response
    let req1 = Request(
        userInput: "whispers in the trees",
        userTopic: "Nature",
        poemType: mockPoemType,
        temperature: mockTemp
    )
    let resp1 = Response(
        userId: "user123",
        content: "Whispers in the trees\nSoftly speak of ancient winds\nEchoes in the leaves.",
        role: "assistant",
        isFavorite: true,
        request: req1
    )
    req1.response = resp1

    // Create second favorite request + response
    let req2 = Request(
        userInput: "ocean lullaby",
        userTopic: "Sea",
        poemType: mockPoemType,
        temperature: mockTemp
    )
    let resp2 = Response(
        userId: "user456",
        content: "Waves hum through the night\nCradling moonlight in rhythm\nOcean's lullaby.",
        role: "assistant",
        isFavorite: true,
        request: req2
    )
    req2.response = resp2

    // Insert into context
    context.insert(req1)
    context.insert(resp1)
    context.insert(req2)
    context.insert(resp2)

    try! context.save()

    return FavoritesView()
        .modelContainer(container)
}
