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
            Request.self,
            Response.self
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
            let requestStore = SwiftDataRequestStore(context: context)
            let responseStore = SwiftDataResponseStore(context: context)
            
            TestHarnessView()
                //.environment(\.requestStore, requestStore)
                //.environment(\.responseStore, responseStore)
        }
        .modelContainer(sharedModelContainer)
    }
}
