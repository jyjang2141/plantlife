//
//  PlantLifeHome.swift
//  plantlife
//
//  Garden home with full-page Discover, Journal, and Learn destinations.
//

import SwiftUI
import SwiftData

struct PlantLifeHome: View {
    @State private var selectedTab = 0   // the garden is home
    @State private var journalPath: [JournalEntry] = []

    var body: some View {
        ZStack {
            GardenView(selectedTab: $selectedTab)
                .opacity(selectedTab == 0 ? 1 : 0)
                .allowsHitTesting(selectedTab == 0)
                .accessibilityHidden(selectedTab != 0)
            if selectedTab != 0 {
                Group {
                    switch selectedTab {
                    case 1: DiscoverView(selectedTab: $selectedTab, journalPath: $journalPath)
                    case 2: JournalView(selectedTab: $selectedTab, path: $journalPath)
                    default: LearnView()
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    HStack {
                        Button {
                            journalPath = []
                            selectedTab = 0
                        } label: {
                            Label("Back to garden", systemImage: "arrow.left")
                                .font(.system(.headline, design: .rounded))
                                .padding(12)
                        }
                        Spacer()
                    }
                    .background(Theme.background)
                }
            }
        }
        .tint(.green)
    }
}

#Preview {
    PlantLifeHome()
        .modelContainer(for: [JournalEntry.self, GardenPlant.self], inMemory: true)
}
