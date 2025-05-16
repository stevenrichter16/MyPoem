//
//  TestHarnessViewModel.swift
//  MyPoem
//
//  Created by Steven Richter on 5/15/25.
//

import SwiftData
import Combine

final class TestHarnessViewModels: ObservableObject {
    private let requestStore: RequestStoring
    private let responseStore: ResponseStoring

    @Published var requests: [Request] = []
    @Published var responses: [Response] = []

    private var context: ModelContext

    init(context: ModelContext) {
        self.context = context
        self.requestStore  = SwiftDataRequestStore(context: context)
        self.responseStore = SwiftDataResponseStore(context: context)
        reloadAll()
    }

    func reloadAll() {
        requests  = (try? requestStore.fetchAll())  ?? []
        responses = (try? responseStore.fetchAll()) ?? []
    }

    func addMockRequest() {
        let dummyType = PoemType(id: "mock", name: "Haiku", prompt: "dummy", maxLength: 1)
        let dummyTemp = Temperature(id: "mock", value: 0.5, textDescription: "Test")
        let r = Request(
            userInput: "Hello SwiftData",
            userTopic: "Testing",
            poemType: dummyType,
            temperature: dummyTemp
            //isFavorite: Bool.random()
        )
        try? requestStore.save(r)
        reloadAll()
    }

    func addMockResponse() {
        let linkedID = requests.first?.id
        let resp = Response(
            userId: "tester",
            content: "📝 Mock at",
            role: "system",
            isFavorite: Bool.random(),
            requestId: linkedID
        )
        try? responseStore.save(resp)
        reloadAll()
    }

    func delete(_ request: Request) {
        try? requestStore.delete(request)
        reloadAll()
    }
    func delete(_ response: Response) {
        try? responseStore.delete(response)
        reloadAll()
    }
    func clearAll() {
        requests.forEach { try? requestStore.delete($0) }
        responses.forEach { try? responseStore.delete($0) }
        reloadAll()
    }
}
