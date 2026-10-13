//
//  GardenView.swift
//  plantlife
//
//  The Garden tab: one card per bed. Tap a bed to open it full screen.
//

import SwiftUI
import SwiftData

// MARK: - One garden, split into beds by what plants need

struct GardenView: View {
    @Binding var selectedTab: Int

    @Query(sort: \GardenPlant.datePlanted) private var plants: [GardenPlant]

    @State private var now = Date.now
    @State private var openBed: GardenPlot?

    var body: some View {
        NavigationStack {
            Group {
                if plants.isEmpty {
                    ContentUnavailableView {
                        Label("Your garden is empty", systemImage: "leaf")
                    } description: {
                        Text("Scan a plant on Discover and it will grow here.")
                    } actions: {
                        Button("Go to Discover") { selectedTab = 1 }
                            .buttonStyle(.borderedProminent).tint(.green)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(statusLine)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            beds
                        }
                        .padding()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.green.opacity(0.07))
            .navigationTitle("My Garden")
            // Re-checks every few seconds so plants get thirsty on their own.
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(5))
                    now = .now
                }
            }
            .fullScreenCover(item: $openBed) { bed in
                BedView(bed: bed) {
                    // "Open plot" was tapped: close the bed and go find a plant.
                    openBed = nil
                    selectedTab = 1
                }
            }
        }
    }

    private var beds: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Tap a bed to visit it")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)
            }

            ForEach(GardenPlot.allCases) { bed in
                Button {
                    openBed = bed
                } label: {
                    BedCard(bed: bed, plants: plants.filter { $0.plot == bed }, now: now)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens this bed")
            }
        }
        .padding(14)
        .background(
            LinearGradient(colors: [Color.cyan.opacity(0.28), Color.green.opacity(0.16)],
                           startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 28)
        )
    }

    private var statusLine: String {
        let thirsty = plants.filter { $0.isThirsty(at: now) }.count
        switch thirsty {
        case 0:  return "Everyone is happy! Check back soon."
        case 1:  return "1 plant is thirsty. Open its bed to water it!"
        default: return "\(thirsty) plants are thirsty. Open their beds to water them!"
        }
    }
}

// MARK: - One bed's card

private struct BedCard: View {
    let bed: GardenPlot
    let plants: [GardenPlant]
    let now: Date

    private var thirstyCount: Int { plants.filter { $0.isThirsty(at: now) }.count }
    private static let previewLimit = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: bed.symbol)
                    .font(.title2)
                    .foregroundStyle(bed.tint)
                    .frame(width: 44, height: 44)
                    .background(bed.tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(bed.title).font(.headline)
                    Text("\(plants.count) of \(GardenPlot.plotCount) plots")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if thirstyCount > 0 {
                    Label("\(thirstyCount) thirsty", systemImage: "drop")
                        .font(.caption.bold()).foregroundStyle(.orange)
                } else if !plants.isEmpty {
                    Label("Happy", systemImage: "drop.fill")
                        .font(.caption.bold()).foregroundStyle(.blue)
                }
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 12) {
                Label(bed.sunlight, systemImage: "sun.max.fill")
                Label(bed.climate, systemImage: "thermometer.medium")
                Label(bed.wateringLabel, systemImage: "drop.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            soilStrip
        }
        .padding(12)
        .background(Theme.card.opacity(0.75), in: RoundedRectangle(cornerRadius: 22))
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(bed.title). \(plants.count) of \(GardenPlot.plotCount) plots used, \(thirstyCount) thirsty. \(bed.sunlight), \(bed.climate).")
    }

    /// A little peek at the soil and the plants growing in it.
    private var soilStrip: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(thirstyCount > 0 ? bed.drySoil : bed.wetSoil)
            if bed == .shady {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: [.black.opacity(0.25), .clear],
                                         startPoint: .topTrailing, endPoint: .bottomLeading))
            }

            if plants.isEmpty {
                Text(bed.emptyHint)
                    .font(.footnote)
                    .foregroundStyle(bed.textOnSoil.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(Array(plants.prefix(Self.previewLimit))) { plant in
                        PlantSprite(kind: plant.kind, growth: plant.growth,
                                    droopy: plant.isThirsty(at: now), size: 44)
                    }
                    Spacer(minLength: 4)
                    Text(extraText)
                        .font(.caption)
                        .foregroundStyle(bed.textOnSoil.opacity(0.85))
                        .padding(.bottom, 6)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 4)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .frame(height: 72)
        .animation(.easeInOut(duration: 0.5), value: thirstyCount > 0)
    }

    private var extraText: String {
        if plants.count > Self.previewLimit { return "+\(plants.count - Self.previewLimit) more" }
        let open = max(0, GardenPlot.plotCount - plants.count)
        return open == 1 ? "1 open plot" : "\(open) open plots"
    }
}

#Preview {
    let container = try! ModelContainer(
        for: JournalEntry.self, GardenPlant.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(GardenPlant(name: "Sunflower", kind: .sunflower, plot: .sunny))
    container.mainContext.insert(GardenPlant(name: "Barrel Cactus", kind: .cactus, plot: .desert))
    container.mainContext.insert(GardenPlant(name: "Ice Plant", kind: .standard, plot: .desert))
    container.mainContext.insert(GardenPlant(name: "Fern", kind: .standard, plot: .shady))
    return GardenView(selectedTab: .constant(0)).modelContainer(container)
}
