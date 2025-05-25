//
//  PoemFilterSettings.swift
//  MyPoem
//
//  Created by Steven Richter on 5/22/25.
//

import SwiftUI // Or import Combine if you only need ObservableObject and @Published

class PoemFilterSettings: ObservableObject {
    @Published var activeFilter: PoemType? = nil // nil means "All"

    func setFilter(_ poemType: PoemType?) {
        activeFilter = poemType
    }

    func resetFilter() {
        activeFilter = nil
        print("Filter reset to All via PoemFilterSettings")
    }
}
