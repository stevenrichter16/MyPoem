////
////  SwiftDataRequestStore.swift
////  MyPoem
////
////  Created by Steven Richter on 5/14/25.
////
//import Foundation
//import SwiftData
//
//final class SwiftDataRequestStore: RequestStoring {
//    private let context: ModelContext
//    
//    init(context: ModelContext) {
//        self.context = context
//    }
//    
//    func save(_ request: Request) throws {
//        context.insert(request)
//        try context.save()
//    }
//    
//    func delete(_ request: Request) throws {
//        context.delete(request)
//        try context.save()
//    }
//    
//    func fetchAll() throws -> [Request] {
//        try context.fetch(FetchDescriptor<Request>())
//    }
//    
//    func fetch(byId id: String) throws -> Request? {
//        try context.fetch(FetchDescriptor<Request>(predicate: #Predicate { $0.id == id})).first
//    }
//}
