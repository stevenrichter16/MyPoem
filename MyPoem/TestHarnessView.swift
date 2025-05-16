//
//  TestHarnessView.swift
//  MyPoem
//
//  A simple UI for manually adding, listing, and deleting
//  Requests and Responses in your SwiftData store.
//

import SwiftUI
import SwiftData

struct TestHarnessView: View {
    // Grab the ModelContext that you set up in MyPoemApp.swift
    @Environment(\.modelContext) private var context

    // Convenience accessors to your stores
    private var requestStore: RequestStoring { SwiftDataRequestStore(context: context) }
    private var responseStore: ResponseStoring { SwiftDataResponseStore(context: context) }
    private var chatService: ChatService {
        ChatService(responseStore: responseStore)
    }

    // Reactive queries: auto-refresh when you save/delete
    @Query(sort: \Request.createdAt, order: .forward) private var requests: [Request]
    @Query(sort: \Response.dateCreated, order: .forward) private var responses: [Response]
    
    @State private var input: String = ""
    @State private var selectedPoemType: PoemType = PoemType.all[0]
    @State private var selectedTemperature: Temperature = Temperature.all[0]

    var body: some View {
        // Lift counts into simple constants
        let reqCount = requests.count
        let respCount = responses.count
        
        VStack(spacing: 0) {
            // 1) Scrollable message area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(requests, id: \.id) { req in
                            RequestResponseCardView(
                                request: req,
                                requestStore: requestStore,
                                responseStore: responseStore
                            )
                            .id(req.id) // tag for scrolling
                        }
                    }
                    .padding(.vertical)
                }
                .onChange(of: requests.count) { _ in
                    // scroll to last when new arrives
                    if let last = requests.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: responses.count) { _ in
                    // find the requestId of the latest response
                    if let lastResp = responses.last,
                       let reqID = lastResp.requestId {
                        withAnimation { proxy.scrollTo(reqID, anchor: .bottom) }
                    }
                }
            }

            Divider()

            // 2) Fixed bottom input area
            VStack(spacing: 12) {
                // ─ Poem Type + Temperature ─
                HStack(spacing: 16) {
                    Menu {
                        ForEach(PoemType.all, id: \.id) { type in
                            Button(type.name) {
                                selectedPoemType = type
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedPoemType.name)
                            Image(systemName: "chevron.down")
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }

                    Picker("", selection: $selectedTemperature) {
                        ForEach(Temperature.all, id: \.id) { temp in
                            Text(temp.textDescription).tag(temp)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)

                // ─ TextField + Send Button ─
                HStack(spacing: 8) {
                    TextField("Enter a topic…", text: $input)
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    Button {
                        Task {
                            guard !input.isEmpty else { return }
                            // 1) create & save request
                            let req = Request(
                              userInput:   input,
                              userTopic:   input,
                              poemType:    selectedPoemType,
                              temperature: selectedTemperature,
                              createdAt:   Date()
                            )
                            try? requestStore.save(req)

                            // 2) actually call OpenAI & save the response
                            await chatService.send(request: req)

                            input = ""
                        }
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.blue)
                            .cornerRadius(8)
                            .shadow(color: .black.opacity(0.2),
                                    radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.borderedProminent)
                
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            .background(Color(.systemBackground))
        }
        .edgesIgnoringSafeArea(.bottom)
    }

    // MARK: – Sections

    @ViewBuilder
    private func requestSection(count: Int) -> some View {
        Section(header: Text("📨 Requests (\(count))")) {
            ForEach(requests) { req in
                RequestRow(request: req)
            }
            .onDelete(perform: deleteRequests)
        }
    }

    @ViewBuilder
    private func responseSection(count: Int) -> some View {
        Section(header: Text("💬 Responses (\(count))")) {
            ForEach(responses) { resp in
                ResponseRow(response: resp)
            }
            .onDelete(perform: deleteResponses)
        }
    }

    // MARK: – Toolbar Buttons

    private var addRequestButton: some View {
        Button("➕ Add Request", action: addMockRequest)
    }

//    private var addResponseButton: some View {
//        Button("➕ Add Response", action: addMockResponse(r))
//    }

    private var clearAllButton: some View {
        Button("🧹 Clear All", action: clearAll)
    }

    // MARK: – Actions

    private func addMockRequest() {
        guard !input.isEmpty else { return }

        let r = Request(
            userInput: input,
            userTopic: input,
            poemType: selectedPoemType,
            temperature: selectedTemperature,
            createdAt: Date()
        )
        try? requestStore.save(r)
        
        addMockResponse(requestId: r.id)
        input = ""
    }

    private func addMockResponse(requestId: String) {
        // Link to first Request if present
        let linkedID = requestId
        let resp = Response(
            userId: "tester",
            content: "📝 To Be or Not To Be Heheh and the dog went woof, and the cow went moo, wow big cow wow wow bow wow yippee yo yippeee yay",
            role: "system",
            isFavorite: Bool.random(),
            requestId: linkedID
            
        )
        try? responseStore.save(resp)
    }

    private func clearAll() {
        requests.forEach { try? requestStore.delete($0) }
        responses.forEach { try? responseStore.delete($0) }
    }

    private func deleteRequests(at offsets: IndexSet) {
        offsets.forEach { idx in
            try? requestStore.delete(requests[idx])
        }
    }

    private func deleteResponses(at offsets: IndexSet) {
        offsets.forEach { idx in
            try? responseStore.delete(responses[idx])
        }
    }
}

// MARK: – Row Subviews

struct RequestRow: View {
    let request: Request

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(request.userInput)
                .font(.body)
            Text("Topic: \(request.userTopic)")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("ID: \(request.id)")
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
}

struct ResponseRow: View {
    let response: Response

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(response.content)
                .font(.body)
            Text("ReqID: \(response.requestId ?? "none") • Fav: \(response.isFavorite.description)")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("ID: \(response.id)")
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
}

// MARK: – Preview

#Preview {
    TestHarnessView()
        .modelContainer(
            try! ModelContainer(
                for: Request.self, Response.self,
                configurations:
                    ModelConfiguration(
                        schema: Schema([Request.self, Response.self]),
                        isStoredInMemoryOnly: true
                    )
                
            )
        )
}
