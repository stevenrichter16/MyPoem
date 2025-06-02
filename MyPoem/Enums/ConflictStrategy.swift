//
//  ConflictStrategy.swift
//  MyPoem
//
//  Created by Steven Richter on 5/31/25.
//

enum ConflictStrategy: String, Codable {
    case keepLocal = "keepLocal"
    case keepRemote = "keepRemote"
    case merge = "merge"
    case manual = "manual"
}
