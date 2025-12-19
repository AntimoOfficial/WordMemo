//
//  WordMemoApp.swift
//  WordMemo
//
//  Created by antimo on 2025/12/19.
//

import SwiftUI
import SwiftData

@main
struct WordMemoApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WordList.self,
            WordEntry.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.antimo.WordMemo")
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
