//
//  PlantLifeHome.swift
//  plantlife
//
//


import SwiftUI

struct PlantLifeHome: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GardenRescueView()
                .tabItem { Label("Garden", systemImage: "leaf.fill") }
                .tag(0)
            DiscoverView(selectedTab: $selectedTab)
                .tabItem { Label("Discover", systemImage: "camera.fill") }
                .tag(1)
            LearnView()
                .tabItem { Label("Learn", systemImage: "book.fill") }
                .tag(2)
        }
        .tint(.green)
    }
}

#Preview {
    PlantLifeHome()
}
