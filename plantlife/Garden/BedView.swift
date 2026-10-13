//
//  BedView.swift
//  plantlife
//
//  One garden bed, full screen: a 3 x 3 grid of plots.
//  Tap a plant for its details. Drag the watering can onto a thirsty plant to water it.
//

import SwiftUI
import SwiftData

struct BedView: View {
    let bed: GardenPlot
    /// Called when an empty plot is tapped, to go find a new plant on Discover.
    var onFindPlant: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \GardenPlant.datePlanted) private var allPlants: [GardenPlant]

    @State private var now = Date.now
    @State private var selectedPlant: GardenPlant?
    @State private var message: String?
    @State private var celebrations = 0

    // Watering can
    @State private var canPosition: CGPoint?            // nil = resting in its tray
    @State private var plantUnderCan: PersistentIdentifier?
    @State private var plotFrames: [PersistentIdentifier: CGRect] = [:]
    @State private var progress: [PersistentIdentifier: Double] = [:]

    /// Seconds of watering to fill one plant = 1 / this. 0.5 ≈ 2 seconds.
    private let waterSpeed = 0.5

    private var plants: [GardenPlant] { allPlants.filter { $0.plot == bed } }
    private var thirstyCount: Int { plants.filter { $0.isThirsty(at: now) }.count }
    private var emptyPlots: Int { max(0, GardenPlot.plotCount - plants.count) }

    private var isPouring: Bool {
        guard let id = plantUnderCan else { return false }
        return plants.first { $0.persistentModelID == id }?.isThirsty() ?? false
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    conditions
                    Text(statusLine)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    bedGrid
                }
                .padding(.horizontal)
                .padding(.bottom, 150)   // room for the watering tray
            }
            .scrollDisabled(canPosition != nil)

            VStack(spacing: 10) {
                if let message { messageCard(message) }
                wateringTray
            }
            .padding()
        }
        .coordinateSpace(.named("bed"))
        .overlay { canCursor }
        .background {
            ZStack {
                Theme.background
                LinearGradient(colors: [Color.cyan.opacity(0.28), Color.green.opacity(0.16)],
                               startPoint: .top, endPoint: .bottom)
            }
            .ignoresSafeArea()
        }
        // Re-checks every few seconds so plants get thirsty on their own.
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                now = .now
            }
        }
        // Fills the bar while the can is held over a thirsty plant, even if the finger stops moving.
        .task(id: plantUnderCan) {
            guard let id = plantUnderCan else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard let plant = plants.first(where: { $0.persistentModelID == id }),
                      plant.isThirsty() else { return }
                progress[id] = min(1, (progress[id] ?? 0) + 0.05 * waterSpeed)
                if (progress[id] ?? 0) >= 1 {
                    water(plant)
                    return
                }
            }
        }
        .task(id: message) {
            guard message != nil else { return }
            try? await Task.sleep(for: .seconds(4))
            withAnimation { message = nil }
        }
        .sensoryFeedback(.success, trigger: celebrations)
        .sheet(item: $selectedPlant) { plant in
            GardenPlantDetailView(plant: plant) {
                // Close the sheet first, then delete, so the sheet never shows a deleted plant.
                selectedPlant = nil
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    context.delete(plant)
                }
            }
        }
    }

    // MARK: Top of the screen

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(Theme.card, in: Circle())
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                }
                .accessibilityLabel("Back to garden")
                Spacer()
                Image(systemName: bed.symbol)
                    .font(.system(size: 42))
                    .foregroundStyle(bed.tint)
                    .accessibilityHidden(true)
            }
            Text(bed.title)
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.top, 8)
    }

    private var conditions: some View {
        HStack(spacing: 8) {
            chip(bed.sunlight, systemImage: "sun.max.fill", tint: .yellow)
            chip(bed.climate, systemImage: "thermometer.medium", tint: .orange)
            chip(bed.wateringLabel, systemImage: "drop.fill", tint: .blue)
        }
    }

    private func chip(_ text: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage).foregroundStyle(tint)
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.card, in: Capsule())
    }

    private var statusLine: String {
        if plants.isEmpty { return bed.emptyHint }
        switch thirstyCount {
        case 0:  return "Everyone here is happy!"
        case 1:  return "1 plant is thirsty."
        default: return "\(thirstyCount) of \(plants.count) plants are thirsty."
        }
    }

    // MARK: The bed

    private var bedGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(plants) { plant in
                PlotTile(
                    plant: plant,
                    bed: bed,
                    thirsty: plant.isThirsty(at: now),
                    isUnderCan: plantUnderCan == plant.persistentModelID,
                    progress: progress[plant.persistentModelID] ?? 0,
                    onSelect: { selectedPlant = plant },
                    onWater: { water(plant) },
                    onRemove: { context.delete(plant) }
                )
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .named("bed"))
                } action: { frame in
                    plotFrames[plant.persistentModelID] = frame
                }
            }
            ForEach(0..<emptyPlots, id: \.self) { _ in
                EmptyPlot(bed: bed, onTap: onFindPlant)
            }
        }
        .padding(12)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(bed.wetSoil).brightness(-0.12)
                if bed == .shady {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(LinearGradient(colors: [.black.opacity(0.25), .clear],
                                             startPoint: .topTrailing, endPoint: .bottomLeading))
                }
            }
        }
        // Wooden frame around the bed
        .padding(8)
        .background(Color(red: 0.55, green: 0.37, blue: 0.22), in: RoundedRectangle(cornerRadius: 26))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .animation(.easeInOut(duration: 0.5), value: thirstyCount)
    }

    // MARK: Watering

    private var wateringTray: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.blue.opacity(0.15))
                if canPosition == nil {
                    WateringCan().frame(width: 42, height: 42)
                } else {
                    Circle().strokeBorder(Color.blue.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                }
            }
            .frame(width: 64, height: 64)
            .contentShape(Circle())
            .gesture(canDrag)

            VStack(alignment: .leading, spacing: 2) {
                Text("Drag the can onto a thirsty plant")
                    .font(.headline)
                Text("Hold it there until the bar fills up.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
        // VoiceOver users get a "Water" action on each plant instead.
        .accessibilityHidden(true)
    }

    /// The can follows your finger. Water lands right where your finger is.
    @ViewBuilder private var canCursor: some View {
        if let point = canPosition {
            ZStack {
                if isPouring {
                    WaterDrops()
                        .frame(width: 30, height: 46)
                        .position(x: point.x, y: point.y - 24)
                }
                WateringCan()
                    .frame(width: 76, height: 76)
                    .rotationEffect(.degrees(isPouring ? -28 : -8))
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 4)
                    .position(x: point.x + 34, y: point.y - 62)
                    .animation(.easeInOut(duration: 0.2), value: isPouring)
            }
            .allowsHitTesting(false)
        }
    }

    private var canDrag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("bed"))
            .onChanged { value in
                canPosition = value.location
                let target = plants.first { plotFrames[$0.persistentModelID]?.contains(value.location) == true }
                let id = target?.persistentModelID
                guard id != plantUnderCan else { return }
                plantUnderCan = id
                if let target, !target.isThirsty() {
                    let tip = notThirstyTip(for: target)
                    if message != tip { withAnimation { message = tip } }
                }
            }
            .onEnded { _ in
                plantUnderCan = nil
                withAnimation(.spring(duration: 0.3)) { canPosition = nil }
            }
    }

    private func water(_ plant: GardenPlant) {
        guard plant.isThirsty() else {
            withAnimation { message = notThirstyTip(for: plant) }
            return
        }
        let willGrow = plant.growth < GardenPlant.maxGrowth
        withAnimation(.spring(duration: 0.6)) {
            plant.water()
            progress[plant.persistentModelID] = 0
            now = .now
            message = willGrow ? "\(plant.name) drank it all up and grew!" : "\(plant.name) is happy again!"
        }
        celebrations += 1
    }

    private func notThirstyTip(for plant: GardenPlant) -> String {
        // Desert plants get a lesson about overwatering; everyone else a gentle note.
        bed == .desert ? bed.notThirstyTip : "\(plant.name) has enough water right now."
    }

    private func messageCard(_ text: String) -> some View {
        Label(text, systemImage: "info.circle.fill")
            .font(.headline)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.07), radius: 8, y: 3)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

// MARK: - One plot with a plant in it

private struct PlotTile: View {
    let plant: GardenPlant
    let bed: GardenPlot
    let thirsty: Bool
    let isUnderCan: Bool
    let progress: Double
    let onSelect: () -> Void
    let onWater: () -> Void
    let onRemove: () -> Void

    private static let alertOrange = Color(red: 0.75, green: 0.33, blue: 0.0)

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 2) {
                PlantSprite(kind: plant.kind, growth: plant.growth, droopy: thirsty, size: 64)
                    .frame(height: 70, alignment: .bottom)
                Text(plant.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                // Always laid out so the tile doesn't jump when the bar appears.
                ZStack {
                    Text(plant.stageName)
                        .font(.caption2)
                        .opacity(isUnderCan && thirsty ? 0 : 0.85)
                    ProgressView(value: progress)
                        .tint(.blue)
                        .frame(width: 56)
                        .opacity(isUnderCan && thirsty ? 1 : 0)
                }
                .frame(height: 14)
            }
            .foregroundStyle(bed.textOnSoil)
            .padding(.horizontal, 4)
            .padding(.top, 14)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .background(thirsty ? bed.drySoil : bed.wetSoil, in: RoundedRectangle(cornerRadius: 16))
            .overlay(alignment: .topLeading) {
                if thirsty {
                    Text("Thirsty")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Self.alertOrange, in: Capsule())
                        .padding(6)
                }
            }
            .overlay(alignment: .topTrailing) {
                if !thirsty {
                    Image(systemName: "drop.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .padding(8)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isUnderCan ? Color.blue : Color.white.opacity(0.15),
                                  lineWidth: isUnderCan ? 3 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Remove from garden", systemImage: "trash", role: .destructive, action: onRemove)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(plant.name), \(plant.stageName), \(thirsty ? "thirsty" : "happy")")
        .accessibilityHint("Shows this plant's details")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Water", onWater)
    }
}

// MARK: - An empty plot

private struct EmptyPlot: View {
    let bed: GardenPlot
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                Text("Open plot")
                    .font(.caption)
            }
            .foregroundStyle(bed.textOnSoil.opacity(0.8))
            .frame(maxWidth: .infinity, minHeight: 116)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(bed.textOnSoil.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open plot")
        .accessibilityHint("Find a new plant on Discover")
    }
}

#Preview {
    let container = try! ModelContainer(
        for: JournalEntry.self, GardenPlant.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(GardenPlant(name: "Sunflower", kind: .sunflower, plot: .sunny))
    container.mainContext.insert(GardenPlant(name: "Marigold", kind: .standard, plot: .sunny))
    container.mainContext.insert(GardenPlant(name: "Basil", kind: .standard, plot: .sunny))
    return BedView(bed: .sunny).modelContainer(container)
}
