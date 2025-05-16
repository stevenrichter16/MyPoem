import Foundation

protocol ResponseStoring {
    func save(_ response: Response) throws
    func delete(_ response: Response) throws
    func fetchAll() throws -> [Response]
    func fetch(byId id: String) throws -> Response?
}
