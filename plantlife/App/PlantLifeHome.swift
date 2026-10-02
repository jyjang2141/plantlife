//
//  PlantLifeHome.swift
//  plantlife
//
//  The tab bar: Garden, Discover, Journal, Learn.
//

import SwiftUI
import SwiftData

struct PlantLifeHome: View {
    @State private var selectedTab = 1   // open on Discover

    var body: some View {
        TabView(selection: $selectedTab) {
            GardenView(selectedTab: $selectedTab)
                .tabItem { Label("Garden", systemImage: "leaf.fill") }
                .tag(0)
            DiscoverView(selectedTab: $selectedTab)
                .tabItem { Label("Discover", systemImage: "camera.fill") }
                .tag(1)
            JournalView(selectedTab: $selectedTab)
                .tabItem { Label("Journal", systemImage: "list.bullet.clipboard.fill") }
                .tag(2)
            LearnView()
                .tabItem { Label("Learn", systemImage: "book.fill") }
                .tag(3)
        }
        .tint(.green)
    }
}

#Preview {
    PlantLifeHome()
        .modelContainer(for: [JournalEntry.self, GardenPlant.self], inMemory: true)
}
