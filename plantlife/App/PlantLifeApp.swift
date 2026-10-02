//
//  PlantLifeApp.swift
//  plantlife
//
//  App entry point: opens PlantLifeHome and sets up saved data.
//

import SwiftUI
import SwiftData

@main
struct PlantLifeApp: App {
    var body: some Scene {
        WindowGroup {
            PlantLifeHome()
        }
        // Saves the Journal and Garden on the device so they survive app restarts.
        .modelContainer(for: [JournalEntry.self, GardenPlant.self])
    }
}