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
    /// The Journal list's "favorites only" filter. Kept here so its heart can sit in the top strip.
    @State private var journalFavoritesOnly = false
    @Query private var journalEntries: [JournalEntry]
    /// Which garden clearing is centered (index into `GardenView.areas`). Starts on the Sunny Bed.
    @State private var gardenArea: Int? = 1

    var body: some View {
        ZStack {
            GardenView(selectedTab: $selectedTab, currentArea: $gardenArea)
                .opacity(selectedTab == 0 ? 1 : 0)
                .allowsHitTesting(selectedTab == 0)
                .accessibilityHidden(selectedTab != 0)
            if selectedTab != 0 {
                // The back strip sits above the screen (not as a safe-area inset over it), so each
                // screen's navigation bar, with its title, back button and toolbar buttons, stays visible.
                VStack(spacing: 0) {
                    // Hidden on a plant's Journal page, which has its own back button to the list.
                    if !(selectedTab == 2 && !journalPath.isEmpty) {
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
                            // On the Journal list, the favorites filter sits on this line.
                            if selectedTab == 2 && !journalEntries.isEmpty {
                                Button {
                                    withAnimation { journalFavoritesOnly.toggle() }
                                } label: {
                                    Image(systemName: journalFavoritesOnly ? "heart.fill" : "heart")
                                        .font(.title3)
                                        .foregroundStyle(journalFavoritesOnly ? .pink : .primary)
                                        .padding(12)
                                }
                                .accessibilityLabel(journalFavoritesOnly ? "Show all plants" : "Show favorites only")
                            }
                        }
                        .background(Theme.background)
                    }

                    Group {
                        switch selectedTab {
                        case 1: DiscoverView(selectedTab: $selectedTab, journalPath: $journalPath)
                        case 2: JournalView(selectedTab: $selectedTab, path: $journalPath, favoritesOnly: $journalFavoritesOnly)
                        default: LearnView()
                        }
                    }
                }
            }
        }
        .tint(.green)
        .environment(\.goToGarden, GoToGardenAction { bed in
            journalPath = []
            selectedTab = 0
            if let bed, let index = GardenView.areas.firstIndex(of: bed) {
                gardenArea = index
            }
        })
    }
}

/// Closes Discover/Journal/Learn and returns to the garden, optionally scrolled to one bed.
/// Used after planting so the kid lands right where their new plant is growing.
struct GoToGardenAction {
    let action: (GardenPlot?) -> Void
    func callAsFunction(_ bed: GardenPlot? = nil) { action(bed) }
}

extension EnvironmentValues {
    @Entry var goToGarden = GoToGardenAction { _ in }
}

#Preview {
    PlantLifeHome()
        .modelContainer(for: [JournalEntry.self, GardenPlant.self], inMemory: true)
}
