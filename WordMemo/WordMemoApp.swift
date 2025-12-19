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
    private static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WordList.self,
            WordEntry.self,
        ])
        let modelConfiguration: ModelConfiguration
        if WordMemoApp.isPreview {
            modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.antimo.WordMemo")
            )
        }

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
