//
//  GardenView.swift
//  plantlife
//
//  The Garden tab: every plant in its bed, plus the 🚿 watering game.
//

import SwiftUI
import SwiftData

// MARK: - One garden, split into beds by what plants need

struct GardenView: View {
    @Binding var selectedTab: Int

    @Environment(\.modelContext) private var context
    @Query(sort: \GardenPlant.datePlanted) private var plants: [GardenPlant]

    @State private var now = Date.now
    @State private var bedFrames: [GardenPlot: CGRect] = [:]
    @State private var progress: [GardenPlot: Double] = [:]
    @State private var bedUnderHose: GardenPlot?
    @State private var message: String?
    @State private var celebrations = 0
    @State private var selectedPlant: GardenPlant?

    // Hose dragging (same feel as your original Garden Rescue)
    @State private var hosePosition = CGPoint(x: 70, y: 60)
    @State private var hoseStart: CGPoint?
    @State private var lastWateringTime: Date?

    /// Seconds of watering to fill a bed = 1 / this. 0.2 ≈ 5 seconds.
    private let waterSpeed = 0.2

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
                            gardenScene
                            if let message { messageCard(message) }
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
    }

    // MARK: The garden

    private var gardenScene: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Drag the 🚿 onto a bed")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 120)   // leaves room for the hose's starting spot
                Spacer()
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.yellow)
            }
            .frame(height: 70)

            ForEach(GardenPlot.allCases) { bed in
                GardenBed(
                    bed: bed,
                    plants: plants.filter { $0.plot == bed },
                    now: now,
                    progress: progress[bed] ?? 0,
                    isUnderHose: bedUnderHose == bed,
                    onWater: { water(bed) },
                    onSelect: { selectedPlant = $0 },
                    onRemove: { context.delete($0) }
                )
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .named("garden"))
                } action: { frame in
                    bedFrames[bed] = frame
                }
            }
        }
        .padding(14)
        .background(
            LinearGradient(colors: [Color.cyan.opacity(0.28), Color.green.opacity(0.16)],
                           startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 28)
        )
        .coordinateSpace(.named("garden"))
        .overlay {
            GeometryReader { proxy in
                ZStack {
                    Text("🚿")
                        .font(.system(size: 76))
                        .offset(y: -43)
                    if bedUnderHose != nil {
                        WaterDrips()
                            .offset(x: 4, y: 43)
                    }
                }
                .frame(width: 112, height: 175)
                .position(hosePosition)
                .gesture(hoseDrag(in: proxy.size))
                .accessibilityHidden(true)   // VoiceOver users get a "Water" action on each bed instead
            }
        }
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

    private var statusLine: String {
        let thirsty = plants.filter { $0.isThirsty(at: now) }.count
        switch thirsty {
        case 0:  return "Everyone is happy! Check back soon."
        case 1:  return "1 plant is thirsty. Water its bed!"
        default: return "\(thirsty) plants are thirsty. Water their beds!"
        }
    }

    // MARK: Watering

    private func hoseDrag(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let origin = hoseStart ?? hosePosition
                if hoseStart == nil { hoseStart = origin }
                hosePosition = clamped(origin.moved(by: value.translation), in: size)

                // Where the water drops land, just below the shower head.
                let dropPoint = CGPoint(x: hosePosition.x + 4, y: hosePosition.y + 80)
                let bed = bedFrames.first { $0.value.contains(dropPoint) }?.key
                bedUnderHose = bed

                guard let bed else { lastWateringTime = nil; return }

                let thirsty = plants.filter { $0.plot == bed && $0.isThirsty() }
                guard !thirsty.isEmpty else {
                    lastWateringTime = nil
                    if !plants.filter({ $0.plot == bed }).isEmpty, message != bed.notThirstyTip {
                        withAnimation { message = bed.notThirstyTip }
                    }
                    return
                }

                let time = Date()
                if let lastWateringTime {
                    let elapsed = min(time.timeIntervalSince(lastWateringTime), 0.15)
                    progress[bed] = min(1, (progress[bed] ?? 0) + elapsed * waterSpeed)
                }
                lastWateringTime = time

                if (progress[bed] ?? 0) >= 1 { water(bed) }
            }
            .onEnded { _ in
                hoseStart = nil
                lastWateringTime = nil
                bedUnderHose = nil
            }
    }

    private func water(_ bed: GardenPlot) {
        let thirsty = plants.filter { $0.plot == bed && $0.isThirsty() }
        guard !thirsty.isEmpty else {
            withAnimation { message = bed.notThirstyTip }
            return
        }
        let grew = thirsty.filter { $0.growth < GardenPlant.maxGrowth }.count
        withAnimation(.spring(duration: 0.6)) {
            thirsty.forEach { $0.water() }
            progress[bed] = 0
            now = .now
            message = grew > 0
                ? "The \(bed.title) is all better, and \(grew == 1 ? "a plant" : "\(grew) plants") grew!"
                : "The \(bed.title) is all better!"
        }
        celebrations += 1
    }

    private func clamped(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: min(max(point.x, 30), size.width - 30), y: min(max(point.y, 30), size.height - 30))
    }
}

// MARK: - One garden bed

private struct GardenBed: View {
    let bed: GardenPlot
    let plants: [GardenPlant]
    let now: Date
    let progress: Double
    let isUnderHose: Bool
    let onWater: () -> Void
    let onSelect: (GardenPlant) -> Void
    let onRemove: (GardenPlant) -> Void

    private var thirstyCount: Int { plants.filter { $0.isThirsty(at: now) }.count }
    private var isDry: Bool { thirstyCount > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(bed.emoji) \(bed.title)").font(.headline)
                Spacer()
                if isDry {
                    Label("\(thirstyCount) thirsty", systemImage: "drop")
                        .font(.caption.bold()).foregroundStyle(.orange)
                } else if !plants.isEmpty {
                    Label("Happy", systemImage: "drop.fill")
                        .font(.caption.bold()).foregroundStyle(.blue)
                }
            }
            Text(bed.needs)
                .font(.caption)
                .foregroundStyle(.secondary)

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(isDry ? bed.drySoil : bed.wetSoil)
                if bed == .shady {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(colors: [.black.opacity(0.25), .clear],
                                             startPoint: .topTrailing, endPoint: .bottomLeading))
                }

                if plants.isEmpty {
                    Text(bed.emptyHint)
                        .font(.footnote)
                        .foregroundStyle(bed.textOnSoil.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 6)], spacing: 6) {
                        ForEach(plants) { plant in
                            let thirsty = plant.isThirsty(at: now)
                            VStack(spacing: 6) {
                                Button {
                                    onSelect(plant)
                                } label: {
                                    PlantInBed(plant: plant, thirsty: thirsty, textColor: bed.textOnSoil)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Remove from garden", systemImage: "trash", role: .destructive) {
                                        onRemove(plant)
                                    }
                                }

                                // Always laid out so tiles don't jump when it appears.
                                ProgressView(value: progress)
                                    .tint(.blue)
                                    .frame(width: 56)
                                    .opacity(isUnderHose && thirsty ? 1 : 0)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .padding(10)
                }
            }
            .frame(minHeight: plants.isEmpty ? 70 : 120)
            .animation(.easeInOut(duration: 0.5), value: isDry)
        }
        .padding(12)
        .background(Theme.card.opacity(0.75), in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(isUnderHose ? Color.blue : .clear, lineWidth: 3)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(bed.title). \(plants.count) plants, \(thirstyCount) thirsty.")
        .accessibilityAction(named: "Water this bed", onWater)
    }
}

private struct PlantInBed: View {
    let plant: GardenPlant
    let thirsty: Bool
    let textColor: Color

    var body: some View {
        VStack(spacing: 2) {
            PlantSprite(kind: plant.kind, growth: plant.growth, droopy: thirsty, size: 44)
                .frame(height: 60, alignment: .bottom)
            Text(plant.name)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
            Text(plant.stageName)
                .font(.caption2)
                .opacity(0.8)
        }
        .foregroundStyle(textColor)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(plant.name), \(plant.stageName), \(thirsty ? "thirsty" : "happy")")
        .accessibilityHint("Shows this plant's details")
    }
}

// MARK: - How a plant looks

/// Seedlings start as 🌱. Each watering grows them into their real plant: 🌻, 🌵, or 🪴.
struct PlantSprite: View {
    let kind: PlantKind
    let growth: Int
    let droopy: Bool
    var size: CGFloat = 100

    private var emoji: String { growth == 0 ? "🌱" : kind.emoji }
    private var scale: CGFloat { 0.7 + CGFloat(min(growth, GardenPlant.maxGrowth)) * 0.1 }

    var body: some View {
        Text(emoji)
            .font(.system(size: size))
            .scaleEffect(scale, anchor: .bottom)
            .rotationEffect(.degrees(droopy ? -12 : 0), anchor: .bottom)
            .saturation(droopy ? 0.35 : 1)
            .animation(.spring(duration: 0.6), value: growth)
            .animation(.easeInOut(duration: 0.5), value: droopy)
            .accessibilityHidden(true)
    }
}

// MARK: - Water drops (unchanged from your original)

private struct WaterDrips: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { proxy in
                let time = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<12, id: \.self) { index in
                        let progress = (time * 1.8 + Double(index) * 0.085).truncatingRemainder(dividingBy: 1)
                        let column = Double(index % 4)
                        Text("💧")
                            .font(.system(size: 11 + progress * 5))
                            .position(
                                x: proxy.size.width * (0.13 + column * 0.25),
                                y: proxy.size.height * progress
                            )
                            .opacity(0.45 + progress * 0.55)
                    }
                }
            }
        }
        .frame(width: 72, height: 120)
        .allowsHitTesting(false)
    }
}

private extension CGPoint {
    func moved(by translation: CGSize) -> CGPoint {
        CGPoint(x: x + translation.width, y: y + translation.height)
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
