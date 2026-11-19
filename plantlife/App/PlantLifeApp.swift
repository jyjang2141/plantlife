//
//  PlantLifeApp.swift
//  plantlife
//
//  App entry point: opens PlantLifeHome, sets up saved data and Firebase.
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct PlantLifeApp: App {
    @StateObject private var classService: ClassService

    init() {
        FirebaseApp.configure()
        _classService = StateObject(wrappedValue: ClassService())
    }

    var body: some Scene {
        WindowGroup {
            PlantLifeHome()
                .environmentObject(classService)
                .task { await classService.restore() }
        }
        // Saves the Journal and Garden on the device so they survive app restarts.
        .modelContainer(for: [JournalEntry.self, GardenPlant.self])
    }
}
