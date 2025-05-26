//
//  MyPoemApp.swift
//  MyPoem
//
//  Created by Steven Richter on 5/14/25.
//

import SwiftUI
import SwiftData

@main
struct MyPoemApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            RequestEnhanced.self,
            ResponseEnhanced.self,
            PoemGroup.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            let context = sharedModelContainer.mainContext
            let dataManager = DataManager(context: context)
            let chatService = ChatService(dataManager: dataManager)
            
            MainTabView()
                .environmentObject(dataManager)
                .environmentObject(chatService)
        }
        .modelContainer(sharedModelContainer)
    }
}
