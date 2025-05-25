////
////  RequestStoring.swift
////  MyPoem
////
////  Created by Steven Richter on 5/14/25.
////
//
//import Foundation
//
//protocol RequestStoring {
//    // Takes in a Request as argument - able to throw exceptions
//    func save(_ request: Request) throws
//    
//    // Takes in a Request as argument - able to throw exceptions
//    func delete(_ request: Request) throws
//    
//    // No argument, returns array of Requests - able to throw exceptions
//    func fetchAll() throws -> [Request]
//    
//    // Takes in string as argument, returns Request? (nillable) - able to throw exceptions
//    func fetch(byId id: String) throws -> Request?
//}
