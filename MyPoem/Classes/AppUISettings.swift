//
//  AppUISettings.swift
//  MyPoem
//
//  Created by Steven Richter on 5/22/25.
//
import SwiftUI // Or import Combine if you only need ObservableObject and @Published

class AppUiSettings: ObservableObject {
    @Published var hasPerformedInitialHistoryScroll: Bool = false // nil means "All"
    @Published var historyViewTopRequestId: String? = nil
    @Published var activeFilter: PoemType? = nil // nil means "All"
    @Published var cardDisplayContext: CardDisplayContext = CardDisplayContext.fullInteractive

    func setFilter(_ poemType: PoemType?) {
        activeFilter = poemType
    }

    func resetFilter() {
        activeFilter = nil
        print("Filter reset to All via PoemFilterSettings")
    }

    func markInitialHistoryScrollPerformed() {
        if hasPerformedInitialHistoryScroll == false {
            hasPerformedInitialHistoryScroll = true
            print("Initial history scroll marked as performed.")
        }
    }
    
    func setHistoryViewScrollPosition(topId: String?) {
        historyViewTopRequestId = topId
    }
    
    func setCardDisplayContext(displayContext: CardDisplayContext) {
        cardDisplayContext = displayContext
    }
}
