//
//  PlantingView.swift
//  plantlife
//
//  Planting a new plant in the Garden, opened from its Journal page once the kid
//  knows which bed it belongs in:
//    1. pick an open plot in that bed
//    2. dig a hole, drop in the seed, cover it with soil, and water it
//

import SwiftUI
import SwiftData

// MARK: - The whole flow

struct PlantingView: View {
    let entry: JournalEntry
    let bed: GardenPlot

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GardenPlant.datePlanted) private var allPlants: [GardenPlant]
    @State private var chosenSlot: Int?

    var body: some View {
        ZStack {
            ZStack {
                Theme.background
                LinearGradient(colors: [Color.cyan.opacity(0.28), Color.green.opacity(0.16)],
                               startPoint: .top, endPoint: .bottom)
            }
            .ignoresSafeArea()

            if let chosenSlot {
                PlantingActivity(entry: entry, bed: bed, slot: chosenSlot,
                                 onBack: { withAnimation(.spring(duration: 0.5)) { self.chosenSlot = nil } },
                                 onClose: { dismiss() })
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            } else {
                PlotPicker(entry: entry, bed: bed,
                           plots: GardenPlant.arrange(allPlants.filter { $0.plot == bed }),
                           onPick: { slot in withAnimation(.spring(duration: 0.5)) { chosenSlot = slot } },
                           onClose: { dismiss() })
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - Step 0: pick a plot

private struct PlotPicker: View {
    let entry: JournalEntry
    let bed: GardenPlot
    /// Index = plot number, nil = open.
    let plots: [GardenPlant?]
    let onPick: (Int) -> Void
    let onClose: () -> Void

    @State private var glow = false

    private var openCount: Int { plots.filter { $0 == nil }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    RoundIconButton(systemImage: "xmark", label: "Close", action: onClose)
                    Spacer()
                    Image(systemName: bed.symbol)
                        .font(.system(size: 42))
                        .foregroundStyle(bed.tint)
                        .accessibilityHidden(true)
                }
                .padding(.top, 8)

                Text(bed.title)
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(openCount > 0
                     ? "Where should your \(entry.name) grow? Tap an open plot."
                     : "The \(bed.title) is full! Remove a plant from it in the Garden to make room, then come back.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(Array(plots.enumerated()), id: \.offset) { index, plant in
                        if let plant {
                            takenPlot(plant)
                        } else {
                            openPlot(index)
                        }
                    }
                }
                .bedFrame(bed)
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { glow = true }
        }
    }

    private func takenPlot(_ plant: GardenPlant) -> some View {
        VStack(spacing: 2) {
            PlantSprite(kind: plant.kind, growth: plant.growth, droopy: false, size: 60)
                .frame(height: 70, alignment: .bottom)
            Text(plant.name)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(bed.textOnSoil)
        .padding(.horizontal, 4)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 116)
        .background(bed.wetSoil, in: RoundedRectangle(cornerRadius: 16))
        .opacity(0.55)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(plant.name) already grows here")
    }

    private func openPlot(_ index: Int) -> some View {
        Button {
            onPick(index)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "hand.tap.fill")
                    .font(.title2)
                Text("Plant here")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(bed.textOnSoil)
            .frame(maxWidth: .infinity, minHeight: 116)
            .background(bed.drySoil, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(glow ? 0.95 : 0.35),
                                  style: StrokeStyle(lineWidth: 2.5, dash: [7, 5]))
            )
            .shadow(color: .white.opacity(glow ? 0.5 : 0), radius: 8)
            .scaleEffect(glow ? 1.03 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open plot \(index + 1)")
        .accessibilityHint("Plant your \(entry.name) here")
    }
}

// MARK: - Steps 1 to 4: dig, seed, cover, water

private struct PlantingActivity: View {
    let entry: JournalEntry
    let bed: GardenPlot
    let slot: Int
    let onBack: () -> Void
    let onClose: () -> Void

    @Environment(\.modelContext) private var context

    enum Step: Int, CaseIterable {
        case dig, seed, cover, water, done
    }

    @State private var step: Step = .dig
    @State private var dig = 0.0        // 0 = flat soil, 1 = deep hole
    @State private var seedPlaced = false
    @State private var cover = 0.0      // 0 = hole open, 1 = filled back in
    @State private var water = 0.0      // 0 = dry, 1 = watered

    // Dragging a tool
    @State private var fingerPoint: CGPoint?    // nil = tool resting in its tray
    @State private var lastPoint: CGPoint?
    @State private var waitForLift = false      // a step just finished; ignore the finger until it lifts
    @State private var soilFrame: CGRect = .zero

    @State private var hint: String?
    @State private var tickCount = 0
    @State private var ticks = 0
    @State private var cheers = 0

    /// How far (in points) the finger has to rub over the soil to finish digging or covering.
    private let digDistance: CGFloat = 900
    private let coverDistance: CGFloat = 700
    /// Watering fills in about 2 seconds of holding.
    private let waterPerTick = 0.025

    private var kind: PlantKind { entry.info.map(PlantKind.from(info:)) ?? .standard }

    private var isPouring: Bool {
        guard step == .water, let point = fingerPoint else { return false }
        return soilFrame.contains(point)
    }

    var body: some View {
        VStack(spacing: 14) {
            topBar
            StepTracker(current: step.rawValue)
            instruction
            soil
            Spacer(minLength: 0)
            if let hint { HintCard(text: hint) }
            tray
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .coordinateSpace(.named("planting"))
        .overlay { toolCursor }
        .sensoryFeedback(.impact(weight: .light), trigger: ticks)
        .sensoryFeedback(.success, trigger: cheers)
        // Fills the water bar while the can is held over the soil, even if the finger stops moving.
        .task(id: isPouring) {
            guard isPouring else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                water = min(1, water + waterPerTick)
                if water >= 1 {
                    finishPlanting()
                    return
                }
            }
        }
        .task(id: hint) {
            guard hint != nil else { return }
            try? await Task.sleep(for: .seconds(3))
            withAnimation { hint = nil }
        }
    }

    // MARK: Top

    private var topBar: some View {
        HStack {
            if step != .done {
                RoundIconButton(systemImage: "chevron.left", label: "Pick a different plot", action: onBack)
            }
            Spacer()
            Label(bed.title, systemImage: bed.symbol)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(height: 44)
    }

    private var instruction: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.bold())
            Text(why)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(nil, value: step)
    }

    private var title: String {
        switch step {
        case .dig:   "Dig a hole"
        case .seed:  "Drop in the seed"
        case .cover: "Cover it up"
        case .water: "Give it a drink"
        case .done:  "You planted your \(entry.name)!"
        }
    }

    private var why: String {
        switch step {
        case .dig:   "Seeds need a cozy spot under the soil to start growing."
        case .seed:  "Put it right in the middle of the hole."
        case .cover: "Soil keeps the seed warm, damp, and safe from hungry birds."
        case .water: "Water wakes the seed up so it can sprout."
        case .done:  "It's a seedling now. Water it when it gets thirsty to help it grow."
        }
    }

    // MARK: The soil

    private var soil: some View {
        SoilPatch(bed: bed, dig: dig, seedPlaced: seedPlaced, cover: cover, water: water)
            .frame(height: 280)
            .overlay {
                if step == .done {
                    // The sprite's ground line sits on the little mound in the middle.
                    PlantSprite(kind: kind, growth: 0, droopy: false, size: 130)
                        .offset(y: -40)
                        .transition(.scale(scale: 0.1, anchor: .bottom).combined(with: .opacity))
                }
            }
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named("planting"))
            } action: { frame in
                soilFrame = frame
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityHint(step == .done ? "" : why)
            .accessibilityAction(named: accessibilityVerb) { finishStepForVoiceOver() }
    }

    // MARK: The tool tray

    private var tray: some View {
        Group {
            if step == .done {
                Button(action: onClose) {
                    Label("All done!", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.leaf)
            } else {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(toolTint.opacity(0.15))
                        if fingerPoint == nil {
                            toolArt.frame(width: 44, height: 44)
                        } else {
                            Circle().strokeBorder(toolTint.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                        }
                    }
                    .frame(width: 64, height: 64)
                    .contentShape(Circle())
                    .gesture(toolDrag)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(trayText)
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                        if let progress = stepProgress {
                            ProgressView(value: progress)
                                .tint(toolTint)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
                // VoiceOver users finish each step with an action on the soil instead.
                .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder private var toolArt: some View {
        switch step {
        case .dig, .cover: Trowel()
        case .seed:        SeedArt()
        case .water:       WateringCan()
        case .done:        EmptyView()
        }
    }

    private var toolTint: Color {
        switch step {
        case .water: .blue
        case .seed:  .orange
        default:     .brown
        }
    }

    private var trayText: String {
        switch step {
        case .dig:   "Drag the trowel back and forth to dig the soil."
        case .seed:  "Drag the seed into the hole."
        case .cover: "Drag the trowel to push the dirt back."
        case .water: "Hold the can over the soil until the bar fills."
        case .done:  ""
        }
    }

    private var stepProgress: Double? {
        switch step {
        case .dig:   dig
        case .cover: cover
        case .water: water
        default:     nil
        }
    }

    /// The tool follows your finger.
    @ViewBuilder private var toolCursor: some View {
        if let point = fingerPoint {
            ZStack {
                switch step {
                case .dig, .cover:
                    Trowel()
                        .frame(width: 70, height: 70)
                        .position(x: point.x + 23, y: point.y - 33)   // blade tip just above the finger
                case .seed:
                    SeedArt()
                        .frame(width: 36, height: 36)
                        .position(seedPoint(for: point))
                case .water:
                    if isPouring {
                        WaterDrops()
                            .frame(width: 30, height: 46)
                            .position(x: point.x, y: point.y - 24)
                    }
                    WateringCan()
                        .frame(width: 76, height: 76)
                        .rotationEffect(.degrees(isPouring ? -28 : -8))
                        .position(x: point.x + 34, y: point.y - 62)
                        .animation(.easeInOut(duration: 0.2), value: isPouring)
                case .done:
                    EmptyView()
                }
            }
            .shadow(color: .black.opacity(0.25), radius: 6, y: 4)
            .allowsHitTesting(false)
        }
    }

    /// The seed floats a little above the finger so you can see it.
    private func seedPoint(for finger: CGPoint) -> CGPoint {
        CGPoint(x: finger.x, y: finger.y - 40)
    }

    // MARK: Dragging

    private var toolDrag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("planting"))
            .onChanged { value in
                guard !waitForLift, step != .done else { return }
                let point = value.location
                defer { lastPoint = point }
                fingerPoint = point
                guard let last = lastPoint, soilFrame.contains(point) else { return }
                let moved = hypot(point.x - last.x, point.y - last.y)

                switch step {
                case .dig:
                    dig = min(1, dig + Double(moved / digDistance))
                    tick(dig)
                    if dig >= 1 { advance(to: .seed) }
                case .cover:
                    cover = min(1, cover + Double(moved / coverDistance))
                    tick(cover)
                    if cover >= 1 { advance(to: .water) }
                default:
                    break
                }
            }
            .onEnded { value in
                if !waitForLift && step == .seed {
                    dropSeed(at: seedPoint(for: value.location))
                }
                waitForLift = false
                lastPoint = nil
                withAnimation(.spring(duration: 0.3)) { fingerPoint = nil }
            }
    }

    /// A little tap you can feel every eighth of the way.
    private func tick(_ progress: Double) {
        let reached = Int(progress * 8)
        if reached > tickCount {
            tickCount = reached
            ticks += 1
        }
    }

    private func dropSeed(at point: CGPoint) {
        // The hole is in the middle of the soil.
        let hole = CGRect(x: soilFrame.midX - 80, y: soilFrame.midY - 60, width: 160, height: 120)
        if hole.contains(point) {
            withAnimation(.spring(duration: 0.4)) { seedPlaced = true }
            advance(to: .cover)
        } else {
            withAnimation { hint = "Almost! Drop the seed right into the hole." }
        }
    }

    private func advance(to next: Step) {
        tickCount = 0
        cheers += 1
        waitForLift = fingerPoint != nil
        withAnimation(.spring(duration: 0.4)) {
            fingerPoint = nil
            step = next
        }
    }

    private func finishPlanting() {
        guard step == .water else { return }
        PlantRecorder.plant(entry, in: bed, slot: slot, context: context)
        advance(to: .done)
    }

    // MARK: VoiceOver

    private var accessibilityVerb: String {
        switch step {
        case .dig:   "Dig"
        case .seed:  "Drop in seed"
        case .cover: "Cover with soil"
        case .water: "Water"
        case .done:  "Done"
        }
    }

    private func finishStepForVoiceOver() {
        switch step {
        case .dig:   dig = 1; advance(to: .seed)
        case .seed:  seedPlaced = true; advance(to: .cover)
        case .cover: cover = 1; advance(to: .water)
        case .water: water = 1; finishPlanting()
        case .done:  onClose()
        }
    }
}

// MARK: - Pieces

/// "1 Dig · 2 Seed · 3 Cover · 4 Water", with checkmarks for finished steps.
private struct StepTracker: View {
    let current: Int
    private let names = ["Dig", "Seed", "Cover", "Water"]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(names.indices, id: \.self) { index in
                let finished = index < current
                let active = index == current
                HStack(spacing: 5) {
                    ZStack {
                        Circle().fill(finished || active ? Theme.leaf : Color.secondary.opacity(0.25))
                        if finished {
                            Image(systemName: "checkmark").font(.caption2.bold())
                        } else {
                            Text("\(index + 1)").font(.caption2.bold())
                        }
                    }
                    .foregroundStyle(finished || active ? Color.white : Color.secondary)
                    .frame(width: 22, height: 22)
                    Text(names[index])
                        .font(.caption.weight(active ? .bold : .regular))
                        .foregroundStyle(active ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(Theme.card.opacity(0.8), in: Capsule())
        .animation(.easeInOut(duration: 0.3), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(current < names.count ? "Step \(current + 1) of 4: \(names[current])" : "All 4 steps done")
    }
}

private struct HintCard: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "info.circle.fill")
            .font(.headline)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.07), radius: 8, y: 3)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

private struct RoundIconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(Theme.card, in: Circle())
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        }
        .accessibilityLabel(label)
    }
}

extension View {
    /// Soil and the wooden frame around a bed's 3 x 3 plots (matches BedView).
    func bedFrame(_ bed: GardenPlot) -> some View {
        self
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
            .padding(8)
            .background(Color(red: 0.55, green: 0.37, blue: 0.22), in: RoundedRectangle(cornerRadius: 26))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }
}

// MARK: - Drawing: the close-up of one plot

/// One plot up close. The hole, dirt pile, seed and mound are all drawn from the progress values.
private struct SoilPatch: View {
    let bed: GardenPlot
    let dig: Double
    let seedPlaced: Bool
    let cover: Double
    let water: Double

    /// Little stones, as fractions of the patch size, so they stay put at any screen size.
    private static let pebbles: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (0.08, 0.15, 9), (0.22, 0.80, 7), (0.35, 0.12, 6), (0.62, 0.88, 8), (0.80, 0.20, 10),
        (0.90, 0.72, 6), (0.15, 0.48, 5), (0.70, 0.40, 5), (0.48, 0.92, 6), (0.95, 0.45, 7),
    ]

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let patch = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 26)
            let center = CGPoint(x: w / 2, y: h * 0.55)
            let dirt = Color(red: 0.30, green: 0.20, blue: 0.12)   // fresh, darker dug-up dirt

            // Soil
            context.fill(patch, with: .color(bed.drySoil))
            if bed == .shady {
                context.fill(patch, with: .linearGradient(
                    Gradient(colors: [.black.opacity(0.25), .clear]),
                    startPoint: CGPoint(x: w, y: 0), endPoint: CGPoint(x: 0, y: h)))
            }
            for pebble in Self.pebbles {
                let rect = CGRect(x: pebble.x * w, y: pebble.y * h, width: pebble.size, height: pebble.size * 0.7)
                context.fill(Path(ellipseIn: rect), with: .color(.black.opacity(0.12)))
            }

            // Wet patch spreading out from the middle
            if water > 0 {
                let radius = 40 + 90 * water
                context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius * 0.5,
                                                    width: radius * 2, height: radius)),
                             with: .radialGradient(Gradient(colors: [.black.opacity(0.35 * water), .clear]),
                                                   center: center, startRadius: 0, endRadius: radius))
            }

            // The hole: grows while digging, fills back in while covering
            let open = dig * (1 - cover)
            let holeWidth = w * (0.16 + 0.22 * dig)
            let holeHeight = 16 + 34 * dig
            let hole = CGRect(x: center.x - holeWidth / 2, y: center.y - holeHeight / 2,
                              width: holeWidth, height: holeHeight)
            if open > 0.01 {
                context.fill(Path(ellipseIn: hole), with: .color(.black.opacity(0.55 * open)))
                context.fill(Path(ellipseIn: hole.insetBy(dx: holeWidth * 0.18, dy: holeHeight * 0.22)
                                    .offsetBy(dx: 0, dy: holeHeight * 0.08)),
                             with: .color(.black.opacity(0.35 * open)))
            }

            // The seed, sitting in the hole until the dirt covers it
            if seedPlaced && cover < 0.7 {
                var seedContext = context
                seedContext.opacity = 1 - cover / 0.7
                SeedArt.draw(in: seedContext, at: CGPoint(x: center.x, y: center.y + 2), size: 26)
            }

            // A little mound once it's covered
            if cover > 0 && seedPlaced {
                let moundWidth = holeWidth * (0.6 + 0.3 * cover)
                let mound = CGRect(x: center.x - moundWidth / 2, y: center.y - 10 * cover,
                                   width: moundWidth, height: 22 * cover)
                context.fill(Path(ellipseIn: mound), with: .color(dirt.opacity(0.85)))
            }

            // The pile of dug-up dirt beside the hole
            let pile = dig * (1 - cover)
            if pile > 0.01 {
                let base = CGPoint(x: center.x + w * 0.30, y: center.y + 16)
                let pileWidth = w * (0.10 + 0.18 * pile)
                let pileHeight = 10 + 44 * pile
                context.fill(Path { p in
                    p.move(to: CGPoint(x: base.x - pileWidth / 2, y: base.y))
                    p.addQuadCurve(to: CGPoint(x: base.x + pileWidth / 2, y: base.y),
                                   control: CGPoint(x: base.x, y: base.y - pileHeight * 2))
                    p.closeSubpath()
                }, with: .color(dirt))
                for (dx, dy) in [(-0.6, 4.0), (0.55, 6.0), (-0.2, 9.0), (0.3, 2.0)] {
                    context.fill(Path(ellipseIn: CGRect(x: base.x + pileWidth * dx, y: base.y + dy, width: 5, height: 4)),
                                 with: .color(dirt))
                }
            }

            context.stroke(Path(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1), cornerRadius: 26),
                           with: .color(.black.opacity(0.15)), lineWidth: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }
}

// MARK: - Drawing: tools

/// A garden trowel with the blade tip pointing down and to the left.
private struct Trowel: View {
    var body: some View {
        Canvas { context, canvasSize in
            // Drawn in a 48 x 48 box, standing up, then tipped over 45°.
            context.scaleBy(x: canvasSize.width / 48, y: canvasSize.height / 48)
            context.translateBy(x: 24, y: 24)
            context.rotate(by: .degrees(45))

            let blade = Path { p in
                p.move(to: CGPoint(x: 0, y: 22))
                p.addQuadCurve(to: CGPoint(x: -8, y: 2), control: CGPoint(x: -10, y: 15))
                p.addLine(to: CGPoint(x: 8, y: 2))
                p.addQuadCurve(to: CGPoint(x: 0, y: 22), control: CGPoint(x: 10, y: 15))
                p.closeSubpath()
            }
            context.fill(blade, with: .linearGradient(
                Gradient(colors: [Color(white: 0.88), Color(white: 0.62)]),
                startPoint: CGPoint(x: -8, y: 0), endPoint: CGPoint(x: 8, y: 0)))
            context.stroke(blade, with: .color(Color(white: 0.40)), lineWidth: 1.2)
            context.stroke(Path { p in
                p.move(to: CGPoint(x: 0, y: 4)); p.addLine(to: CGPoint(x: 0, y: 17))
            }, with: .color(Color(white: 0.5)), lineWidth: 1)

            context.fill(Path(CGRect(x: -1.5, y: -4, width: 3, height: 7)), with: .color(Color(white: 0.45)))

            let handle = Path(roundedRect: CGRect(x: -4.5, y: -22, width: 9, height: 19), cornerRadius: 4.5)
            context.fill(handle, with: .color(Color(red: 0.62, green: 0.40, blue: 0.20)))
            context.stroke(handle, with: .color(Color(red: 0.40, green: 0.25, blue: 0.12)), lineWidth: 1.2)
        }
        .accessibilityHidden(true)
    }
}

/// A seed: a brown teardrop with a light stripe.
private struct SeedArt: View {
    var body: some View {
        Canvas { context, canvasSize in
            Self.draw(in: context, at: CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2),
                      size: min(canvasSize.width, canvasSize.height) * 0.8)
        }
        .accessibilityHidden(true)
    }

    static func draw(in context: GraphicsContext, at center: CGPoint, size: CGFloat) {
        var seed = context
        seed.translateBy(x: center.x, y: center.y)
        seed.rotate(by: .degrees(-25))
        let w = size * 0.55, h = size
        let shape = Path { p in
            p.move(to: CGPoint(x: 0, y: -h / 2))
            p.addCurve(to: CGPoint(x: 0, y: h / 2), control1: CGPoint(x: w * 0.9, y: -h * 0.2), control2: CGPoint(x: w * 0.7, y: h / 2))
            p.addCurve(to: CGPoint(x: 0, y: -h / 2), control1: CGPoint(x: -w * 0.7, y: h / 2), control2: CGPoint(x: -w * 0.9, y: -h * 0.2))
            p.closeSubpath()
        }
        seed.fill(shape, with: .color(Color(red: 0.42, green: 0.26, blue: 0.12)))
        seed.stroke(Path { p in
            p.move(to: CGPoint(x: 0, y: -h * 0.36))
            p.addQuadCurve(to: CGPoint(x: 0, y: h * 0.38), control: CGPoint(x: w * 0.18, y: 0))
        }, with: .color(Color(red: 0.86, green: 0.74, blue: 0.52)), lineWidth: max(1, size * 0.07))
    }
}

#Preview {
    let container = try! ModelContainer(
        for: JournalEntry.self, GardenPlant.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let entry = JournalEntry(name: "Marigold", photoData: nil, infoData: Data())
    container.mainContext.insert(entry)
    container.mainContext.insert(GardenPlant(name: "Sunflower", kind: .sunflower, plot: .sunny, slot: 0))
    container.mainContext.insert(GardenPlant(name: "Basil", kind: .standard, plot: .sunny, slot: 4))
    return PlantingView(entry: entry, bed: .sunny).modelContainer(container)
}
