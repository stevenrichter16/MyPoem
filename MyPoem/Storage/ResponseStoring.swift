import Foundation

protocol ResponseStoring {
    // Takes in a Response as argument - able to throw exceptions
    func save(_ response: Response) throws
    
    // Takes in a Response as argument - able to throw exceptions
    func delete(_ response: Response) throws
    
    // No argument, returns array of Responses - able to throw exceptions
    func fetchAll() throws -> [Response]
    
    // Takes in string as argument, returns Response? (nillable) - able to throw exceptions
    func fetch(byId id: String) throws -> Response?
    
    func fetchFavorites() throws -> [Response]
    
    func fetchRequest(requestId: String) throws -> Request?
}
