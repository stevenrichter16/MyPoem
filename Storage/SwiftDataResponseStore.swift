import Foundation
import SwiftData

final class SwiftDataResponseStore: ResponseStoring {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func save(_ response: Response) throws {
        context.insert(response)
        try context.save()
    }

    func delete(_ response: Response) throws {
        context.delete(response)
        try context.save()
    }

    func fetchAll() throws -> [Response] {
        try context.fetch(FetchDescriptor<Response>())
    }

    func fetch(byId id: String) throws -> Response? {
        try context.fetch(FetchDescriptor<Response>(
            predicate: #Predicate { $0.id == id }
        )).first
    }
}
