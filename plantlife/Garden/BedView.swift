//
//  BedView.swift
//  plantlife
//
//  One garden bed, full screen: a 3 x 3 grid of plots.
//  Tap a plant for its details. Drag the watering can onto a thirsty plant to water it.
//  Switch the tray to Bugs to invite bugs, and tap a bug on a plant to move it away.
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

    // Bugs
    enum Tool: Hashable { case water, bugs }
    @State private var tool: Tool = .water
    @State private var draggedBug: BugKind?
    @State private var bugPoint: CGPoint?               // where the finger is while dragging a bug
    @State private var bugTarget: PersistentIdentifier?
    @State private var visitors: [BugVisitor] = []

    /// Seconds of watering to fill one plant = 1 / this. 0.5 ≈ 2 seconds.
    private let waterSpeed = 0.5

    private var plants: [GardenPlant] { allPlants.filter { $0.plot == bed } }
    private var thirstyCount: Int { plants.filter { $0.isThirsty(at: now) }.count }
    private var caterpillarCount: Int { plants.filter(\.hasCaterpillar).count }

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
                .padding(.bottom, 210)   // room for the tray
            }
            .scrollDisabled(canPosition != nil || bugPoint != nil)

            VStack(spacing: 10) {
                if let message { messageCard(message) }
                toolPicker
                if tool == .water { wateringTray } else { bugTray }
            }
            .padding()
        }
        .coordinateSpace(.named("bed"))
        .overlay { visitorLayer }
        .overlay { canCursor }
        .overlay { bugCursor }
        .background {
            ZStack {
                Theme.background
                LinearGradient(colors: [Color.cyan.opacity(0.28), Color.green.opacity(0.16)],
                               startPoint: .top, endPoint: .bottom)
            }
            .ignoresSafeArea()
        }
        // Re-checks every few seconds so plants get thirsty, and caterpillars come and chew, on their own.
        .task {
            while !Task.isCancelled {
                BugRules.update(allPlants)
                now = .now
                try? await Task.sleep(for: .seconds(5))
            }
        }
        // Now and then a bee, butterfly or ladybug flies in by itself.
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(BugRules.visitorCheckSeconds))
                maybeSendVisitor()
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
        switch caterpillarCount {
        case 0:  break
        case 1:  return "A caterpillar is chewing leaves! Tap the plant, then drag the caterpillar off."
        default: return "\(caterpillarCount) caterpillars are chewing leaves! Tap a plant, then drag its caterpillar off."
        }
        switch thirstyCount {
        case 0:  return "Everyone here is happy!"
        case 1:  return "1 plant is thirsty."
        default: return "\(thirstyCount) of \(plants.count) plants are thirsty."
        }
    }

    // MARK: The bed

    private var bedGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            // Each plant sits in the plot the kid picked when they planted it.
            ForEach(Array(GardenPlant.arrange(plants).enumerated()), id: \.offset) { _, plant in
                if let plant {
                    PlotTile(
                        plant: plant,
                        bed: bed,
                        thirsty: plant.isThirsty(at: now),
                        isUnderCan: plantUnderCan == plant.persistentModelID,
                        isBugTarget: bugTarget == plant.persistentModelID,
                        pollinated: plant.isPollinated(at: now),
                        now: now,
                        progress: progress[plant.persistentModelID] ?? 0,
                        onSelect: { selectedPlant = plant },
                        onWater: { water(plant) },
                        onRemove: { context.delete(plant) },
                        onInvite: { kind in invite(kind, to: plant) }
                    )
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .named("bed"))
                    } action: { frame in
                        plotFrames[plant.persistentModelID] = frame
                    }
                } else {
                    EmptyPlot(bed: bed, onTap: onFindPlant)
                }
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

    /// Water or Bugs: which tool the tray holds.
    private var toolPicker: some View {
        Picker("Tool", selection: $tool) {
            Label("Water", systemImage: "drop.fill").tag(Tool.water)
            Label("Bugs", systemImage: "ladybug.fill").tag(Tool.bugs)
        }
        .pickerStyle(.segmented)
        .padding(4)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
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
        withAnimation(.spring(duration: 0.6)) {
            let result = plant.water()
            progress[plant.persistentModelID] = 0
            now = .now
            message = switch result {
            case .grew:      "\(plant.name) drank it all up and grew!"
            case .grewExtra: "\(plant.name)'s pollinated flowers gave it a boost. It grew two stages!"
            case .slowed:    "\(plant.name) drank it up, but its chewed leaves slow it down. It needs one more drink to grow."
            case .happy:     "\(plant.name) is happy again!"
            }
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

    // MARK: Bugs

    private var bugTray: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(BugKind.allCases) { kind in
                    VStack(spacing: 4) {
                        ZStack {
                            Circle().fill(kind.tint.opacity(0.18))
                            if draggedBug == kind {
                                Circle().strokeBorder(kind.tint.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                            } else {
                                BugSprite(kind: kind).frame(width: 38, height: 38)
                            }
                        }
                        .frame(width: 56, height: 56)
                        .contentShape(Circle())
                        .gesture(bugDrag(kind))
                        Text(kind.name)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Text("Drag a bug onto a plant to invite it. To move a bug away, tap the plant and drag the bug off.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
        // VoiceOver users get "Invite a ..." actions on each plant instead.
        .accessibilityHidden(true)
    }

    private func bugDrag(_ kind: BugKind) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("bed"))
            .onChanged { value in
                draggedBug = kind
                bugPoint = value.location
                bugTarget = plant(at: value.location)?.persistentModelID
            }
            .onEnded { value in
                if let target = plant(at: value.location) {
                    invite(kind, to: target, droppedAt: bugDrawPoint(for: value.location))
                }
                bugTarget = nil
                withAnimation(.spring(duration: 0.3)) {
                    bugPoint = nil
                    draggedBug = nil
                }
            }
    }

    /// The bug floats a little above the finger so you can see it.
    private func bugDrawPoint(for finger: CGPoint) -> CGPoint {
        CGPoint(x: finger.x, y: finger.y - 34)
    }

    @ViewBuilder private var bugCursor: some View {
        if let point = bugPoint, let kind = draggedBug {
            LiveBug(kind: kind)
            .frame(width: 50, height: 50)
            .shadow(color: .black.opacity(0.25), radius: 6, y: 4)
            .position(bugDrawPoint(for: point))
            .allowsHitTesting(false)
        }
    }

    private func plant(at point: CGPoint) -> GardenPlant? {
        plants.first { plotFrames[$0.persistentModelID]?.contains(point) == true }
    }

    /// A kid invited a bug onto a plant (by dragging it there, or with VoiceOver).
    private func invite(_ kind: BugKind, to plant: GardenPlant, droppedAt point: CGPoint? = nil) {
        let date = Date.now
        switch kind {
        case .caterpillar:
            if plant.hasCaterpillar {
                say("\(plant.name) already has a caterpillar.")
            } else if plant.hasLadybug(at: date) {
                say("The ladybug is guarding \(plant.name)! Ladybugs eat tiny bug eggs, so caterpillars stay away.")
            } else {
                withAnimation(.spring(duration: 0.4)) { plant.addCaterpillar(at: date) }
                say("A caterpillar crawled onto \(plant.name). It's hungry for leaves!")
            }
        case .ladybug:
            if plant.hasLadybug(at: date) {
                say("A ladybug is already guarding \(plant.name).")
            } else {
                withAnimation(.spring(duration: 0.4)) { plant.addLadybug(at: date) }
                say(ladybugMessage(for: plant))
                celebrations += 1
            }
        case .bee, .butterfly:
            if !plant.hasFlowers {
                say("Seedlings don't have flowers yet. Bees and butterflies visit flowers, so let it grow first!")
            } else if let visiting = plant.pollinator(at: date) {
                say("A \(visiting.name.lowercased()) is already sitting on \(plant.name)'s flowers.")
            } else if visitors.contains(where: { $0.plantID == plant.persistentModelID }) {
                say("Something is already flying to \(plant.name).")
            } else {
                sendVisitor(kind, to: plant, from: point)
            }
        }
        now = .now
    }

    private func ladybugMessage(for plant: GardenPlant) -> String {
        var text = "A ladybug is guarding \(plant.name). Ladybugs eat tiny bug eggs, so new caterpillars stay away."
        if plant.hasCaterpillar { text += " You still need to move the caterpillar that's already there." }
        return text
    }

    private func say(_ text: String) {
        withAnimation { message = text }
    }

    /// Sends a bee, butterfly or ladybug flying to a plant. It lands, does its job, and stays a while.
    private func sendVisitor(_ kind: BugKind, to plant: GardenPlant, from point: CGPoint? = nil) {
        let visitor = BugVisitor(kind: kind, plantID: plant.persistentModelID, from: point)
        visitors.append(visitor)
        Task {
            try? await Task.sleep(for: .seconds(BugVisitor.flyIn))
            land(visitor)
            visitors.removeAll { $0.id == visitor.id }
        }
    }

    private func land(_ visitor: BugVisitor) {
        guard let plant = plants.first(where: { $0.persistentModelID == visitor.plantID }) else { return }
        let date = Date.now
        switch visitor.kind {
        case .bee, .butterfly:
            guard plant.pollinator(at: date) == nil else { return }
            let alreadyPollinated = plant.isPollinated(at: date)
            withAnimation(.spring(duration: 0.4)) {
                plant.addPollinator(visitor.kind, at: date)
                if !alreadyPollinated { plant.pollinate(at: date) }
            }
            if alreadyPollinated {
                say("A \(visitor.kind.name.lowercased()) is resting on \(plant.name)'s flowers.")
            } else {
                var text = "A \(visitor.kind.name.lowercased()) carried pollen to \(plant.name)'s flowers! Pollen helps plants make seeds."
                if plant.pollenBoost { text += " Water it when it's thirsty for a growth boost." }
                say(text)
            }
        case .ladybug:
            guard !plant.hasLadybug(at: date) else { return }
            withAnimation(.spring(duration: 0.4)) { plant.addLadybug(at: date) }
            say(ladybugMessage(for: plant))
        case .caterpillar:
            return
        }
        celebrations += 1
        now = .now
    }

    /// Every so often, while the bed is open, a bug flies in on its own.
    private func maybeSendVisitor() {
        guard visitors.isEmpty, canPosition == nil, bugPoint == nil, selectedPlant == nil,
              Double.random(in: 0..<1) < BugRules.visitorChance else { return }
        let date = Date.now
        let flowers = plants.filter { $0.hasFlowers && !$0.isPollinated(at: date) && $0.pollinator(at: date) == nil }
        let unguarded = plants.filter { !$0.hasLadybug(at: date) }
        let roll = Double.random(in: 0..<1)
        if roll < 0.8, let plant = flowers.randomElement() {
            sendVisitor(roll < 0.45 ? .bee : .butterfly, to: plant)
        } else if let plant = unguarded.randomElement() {
            sendVisitor(.ladybug, to: plant)
        }
    }

    /// Bees, butterflies and ladybugs flying in to land on a plant.
    private var visitorLayer: some View {
        TimelineView(.animation(paused: visitors.isEmpty)) { timeline in
            GeometryReader { proxy in
                ForEach(visitors) { visitor in
                    let plant = plants.first { $0.persistentModelID == visitor.plantID }
                    let target = visitorTarget(visitor, plant: plant, size: proxy.size)
                    let here = visitor.position(at: timeline.date, target: target, size: proxy.size)
                    let next = visitor.position(at: timeline.date.addingTimeInterval(0.05), target: target, size: proxy.size)
                    // Shrinks to its sitting size as it lands, so it lines up with the bug drawn on the plant.
                    let landSize = plant.map { PlantWithBugs.bugSize(visitor.kind, on: $0, size: PlotTile.spriteSize) } ?? 20
                    let bugSize = 36 + (landSize - 36) * visitor.progress(at: timeline.date)
                    BugSprite(kind: visitor.kind, flap: visitor.flap(at: timeline.date))
                        .frame(width: bugSize, height: bugSize)
                        .scaleEffect(x: next.x < here.x - 0.5 ? -1 : 1, y: 1)   // face the way it's flying
                        .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
                        .position(here)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Where a visiting bug lands: its spot on the plant drawn in the plot.
    private func visitorTarget(_ visitor: BugVisitor, plant: GardenPlant?, size: CGSize) -> CGPoint {
        guard let plant, let frame = plotFrames[visitor.plantID] else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }
        let perch = PlantWithBugs.perch(visitor.kind, on: plant, droopy: plant.isThirsty(at: now),
                                        size: PlotTile.spriteSize)
        return CGPoint(x: frame.midX - PlotTile.spriteSize / 2 + perch.x,
                       y: frame.minY + PlotTile.spriteTop + perch.y)
    }
}

// MARK: - One plot with a plant in it

private struct PlotTile: View {
    let plant: GardenPlant
    let bed: GardenPlot
    let thirsty: Bool
    let isUnderCan: Bool
    let isBugTarget: Bool
    let pollinated: Bool
    let now: Date
    let progress: Double
    let onSelect: () -> Void
    let onWater: () -> Void
    let onRemove: () -> Void
    let onInvite: (BugKind) -> Void

    /// The plant drawing's size, and how far its top sits below the top of the tile.
    static let spriteSize: CGFloat = 64
    static let spriteTop: CGFloat = 14 + (70 - 64)

    private static let alertOrange = Color(red: 0.75, green: 0.33, blue: 0.0)

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 2) {
                // Bugs show here; tap the plant to see them up close and drag them away.
                PlantWithBugs(plant: plant, droopy: thirsty, size: Self.spriteSize, now: now)
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
                if pollinated {
                    // Pollen dusting the flowers.
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .shadow(color: .black.opacity(0.3), radius: 1)
                        .padding(7)
                        .transition(.scale.combined(with: .opacity))
                } else if !thirsty {
                    Image(systemName: "drop.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .padding(8)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(borderColor, lineWidth: isUnderCan || isBugTarget ? 3 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Remove from garden", systemImage: "trash", role: .destructive, action: onRemove)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Shows this plant up close")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Water", onWater)
        .accessibilityActions {
            ForEach(BugKind.allCases) { kind in
                Button("Invite a \(kind.name.lowercased())") { onInvite(kind) }
            }
        }
    }

    private var borderColor: Color {
        if isUnderCan { return .blue }
        if isBugTarget { return .orange }
        return .white.opacity(0.15)
    }

    private var accessibilityText: String {
        var parts = [plant.name, plant.stageName, thirsty ? "thirsty" : "happy"]
        if plant.hasCaterpillar { parts.append("a caterpillar is chewing its leaves") }
        else if plant.leafHoles > 0 { parts.append("chewed leaves") }
        if plant.hasLadybug(at: now) { parts.append("guarded by a ladybug") }
        if let pollinator = plant.pollinator(at: now) { parts.append("a \(pollinator.name.lowercased()) is on its flowers") }
        else if pollinated { parts.append("pollinated") }
        return parts.joined(separator: ", ")
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
    let basil = GardenPlant(name: "Basil", kind: .standard, plot: .sunny)
    basil.growth = 2
    basil.addCaterpillar()
    basil.chew()
    container.mainContext.insert(basil)
    return BedView(bed: .sunny).modelContainer(container)
}
