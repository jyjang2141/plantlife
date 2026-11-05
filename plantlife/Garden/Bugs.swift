//
//  Bugs.swift
//  plantlife
//
//  Garden bugs: caterpillars chew leaves, ladybugs keep caterpillars away,
//  bees and butterflies pollinate flowers.
//  This file has the rules, the flying visitors, and the drawings.
//

import SwiftUI
import SwiftData

// MARK: - The four bugs

enum BugKind: String, CaseIterable, Identifiable {
    case caterpillar, ladybug, bee, butterfly
    var id: Self { self }

    var name: String {
        switch self {
        case .caterpillar: "Caterpillar"
        case .ladybug:     "Ladybug"
        case .bee:         "Bee"
        case .butterfly:   "Butterfly"
        }
    }

    var tint: Color {
        switch self {
        case .caterpillar: .green
        case .ladybug:     .red
        case .bee:         .yellow
        case .butterfly:   .orange
        }
    }
}

// MARK: - Rules

enum BugRules {
    // Tip for testing in class: set rollEvery to 60 (a roll every minute) and
    // healAfter to 120 (leaves grow back 2 minutes after the caterpillar leaves).

    /// How often the garden rolls the dice for a caterpillar on each plant.
    /// A caterpillar that's already there chews more holes at each roll.
    static let rollEvery: TimeInterval = 60 * 60 * 2
    /// Chance per roll that a caterpillar shows up on a plant with no ladybug.
    static let caterpillarChance = 0.04
    static let maxCaterpillarsPerBed = 2
    /// Chewed leaves grow back this long after the caterpillar is moved away.
    static let healAfter: TimeInterval = 60 * 60 * 24
    static let healText = "1 day"
    /// How long an invited or visiting ladybug stays and guards a plant.
    static let ladybugStays: TimeInterval = 60 * 60 * 24
    /// How long a bee or butterfly sits on a plant's flowers after it lands.
    static let pollinatorStays: TimeInterval = 60 * 60
    /// A plant can be pollinated once per this long.
    static let pollinatedLasts: TimeInterval = 60 * 60 * 24

    /// While a bed is open, every this many seconds a bee, butterfly or ladybug may fly in.
    static let visitorCheckSeconds = 12.0
    static let visitorChance = 0.35

    /// Catches the garden up to `now`: caterpillars arrive at random, chew, and leaves heal.
    /// Safe to call often. Works out what happened while the app was closed, too.
    static func update(_ plants: [GardenPlant], now: Date = .now) {
        for bed in GardenPlot.allCases {
            let bedPlants = plants.filter { $0.plot == bed }
            var caterpillars = bedPlants.filter(\.hasCaterpillar).count

            for plant in bedPlants {
                guard let due = plant.nextBugRoll else {
                    plant.nextBugRoll = now + rollEvery
                    continue
                }
                // Don't replay more than 4 days of rolls after a long break.
                var rollTime = max(due, now - rollEvery * 48)
                while rollTime <= now {
                    plant.healIfReady(at: rollTime)
                    if plant.hasCaterpillar {
                        plant.chew()
                    } else if caterpillars < maxCaterpillarsPerBed,
                              !plant.hasLadybug(at: rollTime),
                              Double.random(in: 0..<1) < caterpillarChance {
                        plant.addCaterpillar(at: rollTime)
                        caterpillars += 1
                    }
                    rollTime += rollEvery
                }
                if rollTime != due { plant.nextBugRoll = rollTime }
                plant.healIfReady(at: now)
            }
        }
    }
}

// MARK: - A plant's bugs

extension GardenPlant {
    var hasCaterpillar: Bool { caterpillarSince != nil }

    /// Seedlings have no flowers yet, so bees and butterflies skip them.
    var hasFlowers: Bool { growth >= 1 }

    func hasLadybug(at date: Date = .now) -> Bool {
        (ladybugUntil ?? .distantPast) > date
    }

    func isPollinated(at date: Date = .now) -> Bool {
        guard let lastPollinated else { return false }
        return date.timeIntervalSince(lastPollinated) < BugRules.pollinatedLasts
    }

    /// When chewed leaves will be back to normal, once the caterpillar is gone.
    var leavesHealDate: Date? {
        guard !hasCaterpillar, leafHoles > 0, let caterpillarGoneAt else { return nil }
        return caterpillarGoneAt + BugRules.healAfter
    }

    func addCaterpillar(at date: Date = .now) {
        guard !hasCaterpillar else { return }
        caterpillarSince = date
        caterpillarGoneAt = nil
        leafHoles = max(leafHoles, 1)   // the first bite
    }

    func removeCaterpillar(at date: Date = .now) {
        guard hasCaterpillar else { return }
        caterpillarSince = nil
        caterpillarGoneAt = date
        caterpillarsMoved += 1
    }

    func chew() {
        leafHoles = min(3, leafHoles + 1)
    }

    func healIfReady(at date: Date) {
        guard let heal = leavesHealDate, date >= heal else { return }
        leafHoles = 0
    }

    func addLadybug(at date: Date = .now) {
        ladybugUntil = date + BugRules.ladybugStays
    }

    func shooLadybug() {
        ladybugUntil = nil
    }

    /// The bee or butterfly sitting on its flowers right now, if any.
    func pollinator(at date: Date = .now) -> BugKind? {
        guard let pollinatorUntil, pollinatorUntil > date else { return nil }
        return BugKind(rawValue: pollinatorRaw)
    }

    func addPollinator(_ kind: BugKind, at date: Date = .now) {
        pollinatorRaw = kind.rawValue
        pollinatorUntil = date + BugRules.pollinatorStays
    }

    func shooPollinator() {
        pollinatorUntil = nil
    }

    /// Every bug on the plant right now, in drawing order.
    func bugs(at date: Date = .now) -> [BugKind] {
        var bugs: [BugKind] = []
        if hasCaterpillar { bugs.append(.caterpillar) }
        if hasLadybug(at: date) { bugs.append(.ladybug) }
        if let pollinator = pollinator(at: date) { bugs.append(pollinator) }
        return bugs
    }

    func pollinate(at date: Date = .now) {
        lastPollinated = date
        timesPollinated += 1
        if growth < GardenPlant.maxGrowth { pollenBoost = true }
    }
}

// MARK: - A bee, butterfly or ladybug flying to a plant

/// Flies in (from the edge of the screen, or from where it was dropped) and lands on a plant,
/// where it stays (see `PlantWithBugs`).
struct BugVisitor: Identifiable {
    let id = UUID()
    let kind: BugKind
    let plantID: PersistentIdentifier
    /// nil = fly in from the side of the screen.
    var from: CGPoint? = nil
    let start = Date.now
    let fromLeft = Bool.random()
    let startHeight = CGFloat.random(in: 0.15...0.5)

    /// Seconds to fly in and land.
    static let flyIn = 1.8

    /// 0 when it sets off, 1 when it lands.
    func progress(at date: Date) -> Double {
        min(1, max(0, date.timeIntervalSince(start) / Self.flyIn))
    }

    func position(at date: Date, target: CGPoint, size: CGSize) -> CGPoint {
        let t = date.timeIntervalSince(start)
        let entry = from ?? CGPoint(x: fromLeft ? -40 : size.width + 40, y: size.height * startHeight)
        let wobble = CGFloat(sin(t * 7)) * 8
        let k = Self.ease(progress(at: date))
        return CGPoint(x: entry.x + (target.x - entry.x) * k,
                       y: entry.y + (target.y - entry.y) * k + wobble * (1 - k))
    }

    /// Wings: 0 = closed, 1 = open. Bees buzz fast, butterflies flap slowly.
    func flap(at date: Date) -> Double {
        let speed: Double = switch kind {
        case .bee:       45
        case .butterfly: 11
        default:         28
        }
        return (sin(date.timeIntervalSinceReferenceDate * speed) + 1) / 2
    }

    private static func ease(_ x: Double) -> CGFloat {
        CGFloat(x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2)
    }
}

// MARK: - Drawings

/// One bug, drawn in the same style as the plants. Caterpillars and bees face right.
struct BugSprite: View {
    let kind: BugKind
    /// How open the wings are, 0 to 1 (bees and butterflies).
    var flap: Double = 0.6

    var body: some View {
        Canvas { context, size in
            // All drawing below uses a 40 x 40 box.
            context.scaleBy(x: size.width / 40, y: size.height / 40)
            switch kind {
            case .caterpillar: BugDrawing.caterpillar(in: &context, wiggle: 0)
            case .ladybug:     BugDrawing.ladybug(in: &context)
            case .bee:         BugDrawing.bee(in: &context, flap: flap)
            case .butterfly:   BugDrawing.butterfly(in: &context, flap: flap)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A bug that moves while it sits: caterpillars inch along, bees buzz, butterflies flap slowly.
struct LiveBug: View {
    let kind: BugKind

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: kind == .ladybug)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                context.scaleBy(x: size.width / 40, y: size.height / 40)
                switch kind {
                case .caterpillar: BugDrawing.caterpillar(in: &context, wiggle: (time * 0.9).truncatingRemainder(dividingBy: 1))
                case .ladybug:     BugDrawing.ladybug(in: &context)
                case .bee:         BugDrawing.bee(in: &context, flap: 0.35 + 0.25 * sin(time * 40))
                case .butterfly:   BugDrawing.butterfly(in: &context, flap: 0.55 + 0.45 * sin(time * 2.5))
                }
            }
            .offset(x: kind == .caterpillar ? CGFloat(sin(time * 1.4)) * 2 : 0)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - A plant with its bugs on it

/// A plant drawing with its bugs sitting on the leaves and flowers.
/// Give it `onDragOff` and kids can drag the bugs off (the close-up view); without it the bugs are just pictures.
struct PlantWithBugs: View {
    let plant: GardenPlant
    var droopy = false
    var size: CGFloat = 100
    var now: Date = .now
    /// Called when a bug is dragged off the plant and let go.
    var onDragOff: ((BugKind) -> Void)? = nil
    /// Called with true when a drag starts and false when it ends (to stop the sheet scrolling meanwhile).
    var onDragging: ((Bool) -> Void)? = nil

    @State private var offsets: [BugKind: CGSize] = [:]
    @State private var ouch: BugKind?
    @State private var ouchCount = 0

    private var dragOffDistance: CGFloat { size * 0.3 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            PlantSprite(kind: plant.kind, growth: plant.growth, droopy: droopy, size: size, holes: plant.leafHoles)
            ForEach(plant.bugs(at: now)) { kind in
                let bugSize = Self.bugSize(kind, on: plant, size: size)
                LiveBug(kind: kind)
                    .frame(width: bugSize, height: bugSize)
                    .overlay(alignment: .top) {
                        if ouch == kind {
                            OuchBubble()
                                .fixedSize()
                                .offset(y: -bugSize * 0.75)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .scaleEffect(offsets[kind] == nil ? 1 : 1.2)
                    .contentShape(Rectangle().inset(by: -10))
                    .position(Self.perch(kind, on: plant, droopy: droopy, size: size))
                    .offset(offsets[kind] ?? .zero)
                    .highPriorityGesture(dragGesture(kind))
                    .onDisappear { offsets[kind] = nil }
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(onDragOff != nil)
        .sensoryFeedback(.warning, trigger: ouchCount)
        .task(id: ouchCount) {
            guard ouch != nil else { return }
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation { ouch = nil }
        }
    }

    private func dragGesture(_ kind: BugKind) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { value in
                if offsets[kind] == nil { onDragging?(true) }
                offsets[kind] = value.translation
            }
            .onEnded { value in
                onDragging?(false)
                let draggedOff = hypot(value.translation.width, value.translation.height) > dragOffDistance
                if draggedOff && kind != .caterpillar {
                    // Helper bugs say "Ouch!" and spring back while the kid decides.
                    withAnimation(.spring(duration: 0.3)) { ouch = kind }
                    ouchCount += 1
                }
                if draggedOff { onDragOff?(kind) }
                if !draggedOff || kind != .caterpillar {
                    withAnimation(.spring(duration: 0.45, bounce: 0.4)) { offsets[kind] = nil }
                }
            }
    }

    // MARK: Where bugs sit

    /// Where each bug sits, in the plant's 80 x 80 drawing box.
    static func perchSpot(_ bug: BugKind, kind: PlantKind, growth: Int) -> CGPoint {
        let spots: (caterpillar: CGPoint, ladybug: CGPoint, flower: CGPoint)
        if growth == 0 {
            spots = (CGPoint(x: 31, y: 55), CGPoint(x: 51, y: 54), CGPoint(x: 40, y: 48))
        } else {
            switch kind {
            case .sunflower: spots = (CGPoint(x: 29, y: 57), CGPoint(x: 52, y: 48), CGPoint(x: 44, y: 21))
            case .cactus:    spots = (CGPoint(x: 25, y: 50), CGPoint(x: 55, y: 36), CGPoint(x: 41, y: 16))
            case .standard:  spots = (CGPoint(x: 29, y: 52), CGPoint(x: 50, y: 45), CGPoint(x: 40, y: 24))
            }
        }
        switch bug {
        case .caterpillar:     return spots.caterpillar
        case .ladybug:         return spots.ladybug
        case .bee, .butterfly: return spots.flower
        }
    }

    /// Where a bug sits in a `size` x `size` plant drawing, following the plant's growth, droop and wilt.
    static func perch(_ bug: BugKind, on plant: GardenPlant, droopy: Bool, size: CGFloat) -> CGPoint {
        let spot = perchSpot(bug, kind: plant.kind, growth: plant.growth)
        let unit = size / 80
        let scale = PlantSprite.growthScale(plant.growth)
        // Measured from the bottom middle, which is where the plant tips over from.
        let dx = (spot.x - 40) * unit
        let dy = -(80 - spot.y) * unit * PlantSprite.squash(holes: plant.leafHoles)
        let angle = PlantSprite.lean(droopy: droopy, holes: plant.leafHoles) * .pi / 180
        let x = dx * CGFloat(cos(angle)) - dy * CGFloat(sin(angle))
        let y = dx * CGFloat(sin(angle)) + dy * CGFloat(cos(angle))
        return CGPoint(x: size / 2 + x * scale, y: size + y * scale)
    }

    static func bugSize(_ bug: BugKind, on plant: GardenPlant, size: CGFloat) -> CGFloat {
        // Smaller on seedlings, so a caterpillar doesn't dwarf two little leaves.
        (bug == .caterpillar ? 26 : 22) * size / 80 * PlantSprite.growthScale(plant.growth) * (plant.growth == 0 ? 0.75 : 1)
    }
}

/// A little "Ouch!" speech bubble.
private struct OuchBubble: View {
    var body: some View {
        Text("Ouch!")
            .font(.caption.weight(.heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(red: 0.85, green: 0.25, blue: 0.20), in: Capsule())
            .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
    }
}

private enum BugDrawing {
    static let ink = Color(red: 0.12, green: 0.10, blue: 0.08)

    static func caterpillar(in context: inout GraphicsContext, wiggle: Double) {
        let bodyLight = Color(red: 0.55, green: 0.82, blue: 0.30)
        let bodyDark  = Color(red: 0.38, green: 0.68, blue: 0.22)
        let spot      = Color(red: 1.00, green: 0.85, blue: 0.25)

        // Five round segments in a gentle wave, head on the right.
        let centers: [CGPoint] = (0..<5).map { i in
            let lift = sin(Double(i) * 1.3 + wiggle * 2 * .pi) * 1.6
            return CGPoint(x: 8 + Double(i) * 5.6, y: 25 - lift)
        }
        for (i, c) in centers.enumerated() {
            let isHead = i == centers.count - 1
            let r: CGFloat = isHead ? 5.4 : 4.7
            if !isHead {
                context.fill(Path(ellipseIn: CGRect(x: c.x - 1, y: c.y + r - 1.2, width: 2, height: 2.6)),
                             with: .color(ink.opacity(0.7)))   // little feet
            }
            context.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                         with: .color(isHead ? bodyDark : (i.isMultiple(of: 2) ? bodyLight : bodyDark)))
            if !isHead {
                context.fill(Path(ellipseIn: CGRect(x: c.x - 1.1, y: c.y - 3.2, width: 2.2, height: 2.2)),
                             with: .color(spot))
            }
        }

        let head = centers[centers.count - 1]
        context.stroke(Path { p in
            p.move(to: CGPoint(x: head.x - 1, y: head.y - 4.5)); p.addLine(to: CGPoint(x: head.x - 2.5, y: head.y - 9.5))
            p.move(to: CGPoint(x: head.x + 1.5, y: head.y - 4.5)); p.addLine(to: CGPoint(x: head.x + 3.5, y: head.y - 9.5))
        }, with: .color(ink), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        context.fill(Path(ellipseIn: CGRect(x: head.x + 0.6, y: head.y - 2.6, width: 2.6, height: 2.6)), with: .color(ink))
        context.fill(Path(ellipseIn: CGRect(x: head.x + 1.5, y: head.y - 2.2, width: 0.9, height: 0.9)), with: .color(.white))
    }

    static func ladybug(in context: inout GraphicsContext) {
        let red = Color(red: 0.88, green: 0.16, blue: 0.14)
        // Seen from above, head up.
        context.stroke(Path { p in
            p.move(to: CGPoint(x: 17, y: 7)); p.addLine(to: CGPoint(x: 14, y: 2.5))
            p.move(to: CGPoint(x: 23, y: 7)); p.addLine(to: CGPoint(x: 26, y: 2.5))
        }, with: .color(ink), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
        context.fill(Path(ellipseIn: CGRect(x: 14, y: 5, width: 12, height: 10)), with: .color(ink))
        context.fill(Path(ellipseIn: CGRect(x: 16.6, y: 8, width: 1.8, height: 1.8)), with: .color(.white))
        context.fill(Path(ellipseIn: CGRect(x: 21.6, y: 8, width: 1.8, height: 1.8)), with: .color(.white))

        let shell = Path(ellipseIn: CGRect(x: 8.5, y: 11.5, width: 23, height: 23))
        context.fill(shell, with: .color(red))
        context.stroke(Path { p in
            p.move(to: CGPoint(x: 20, y: 12)); p.addLine(to: CGPoint(x: 20, y: 34))
        }, with: .color(ink), lineWidth: 1.2)
        for spot in [CGPoint(x: 15, y: 18), CGPoint(x: 25, y: 18), CGPoint(x: 13.5, y: 25),
                     CGPoint(x: 26.5, y: 25), CGPoint(x: 16.5, y: 30.5), CGPoint(x: 23.5, y: 30.5)] {
            context.fill(Path(ellipseIn: CGRect(x: spot.x - 2, y: spot.y - 2, width: 4, height: 4)), with: .color(ink))
        }
        context.stroke(shell, with: .color(ink.opacity(0.6)), lineWidth: 1)
        context.fill(Path(ellipseIn: CGRect(x: 12, y: 14, width: 5, height: 3)), with: .color(.white.opacity(0.4)))
    }

    static func bee(in context: inout GraphicsContext, flap: Double) {
        let yellow = Color(red: 1.00, green: 0.80, blue: 0.20)
        let body = Path(ellipseIn: CGRect(x: 7, y: 16, width: 23, height: 13))

        context.fill(Path { p in      // stinger
            p.move(to: CGPoint(x: 8.5, y: 21)); p.addLine(to: CGPoint(x: 4, y: 22.5)); p.addLine(to: CGPoint(x: 8.5, y: 24))
        }, with: .color(ink))
        context.fill(body, with: .color(yellow))
        var stripes = context
        stripes.clip(to: body)
        stripes.fill(Path(CGRect(x: 13, y: 14, width: 3.4, height: 18)), with: .color(ink))
        stripes.fill(Path(CGRect(x: 20, y: 14, width: 3.4, height: 18)), with: .color(ink))
        context.stroke(body, with: .color(ink.opacity(0.6)), lineWidth: 0.9)

        context.fill(Path(ellipseIn: CGRect(x: 26.5, y: 17.5, width: 9, height: 9)), with: .color(ink))
        context.fill(Path(ellipseIn: CGRect(x: 31.2, y: 19.4, width: 2, height: 2)), with: .color(.white))
        context.stroke(Path { p in
            p.move(to: CGPoint(x: 31, y: 18)); p.addLine(to: CGPoint(x: 33.5, y: 13))
        }, with: .color(ink), style: StrokeStyle(lineWidth: 1, lineCap: .round))

        // Wings on top, opening and closing.
        let height = 4 + 7 * flap
        for x in [12.5, 18.5] {
            let wing = Path(ellipseIn: CGRect(x: x, y: 18 - height, width: 9, height: height))
            context.fill(wing, with: .color(Color(red: 0.85, green: 0.94, blue: 1.0).opacity(0.85)))
            context.stroke(wing, with: .color(Color(red: 0.45, green: 0.62, blue: 0.80)), lineWidth: 0.8)
        }
    }

    static func butterfly(in context: inout GraphicsContext, flap: Double) {
        let upper = Color(red: 0.98, green: 0.58, blue: 0.16)
        let lower = Color(red: 0.95, green: 0.42, blue: 0.22)
        let edge  = Color(red: 0.25, green: 0.14, blue: 0.08)

        // Wings get narrower as they close.
        var wings = context
        wings.translateBy(x: 20, y: 0)
        wings.scaleBy(x: 0.3 + 0.7 * flap, y: 1)
        for rect in [CGRect(x: -15, y: 19, width: 13, height: 13), CGRect(x: 2, y: 19, width: 13, height: 13)] {
            wings.fill(Path(ellipseIn: rect), with: .color(lower))
            wings.stroke(Path(ellipseIn: rect), with: .color(edge), lineWidth: 1.2)
        }
        for rect in [CGRect(x: -18, y: 5, width: 17, height: 16), CGRect(x: 1, y: 5, width: 17, height: 16)] {
            wings.fill(Path(ellipseIn: rect), with: .color(upper))
            wings.stroke(Path(ellipseIn: rect), with: .color(edge), lineWidth: 1.2)
        }
        for dot in [CGPoint(x: -13, y: 10), CGPoint(x: 13, y: 10), CGPoint(x: -9, y: 27), CGPoint(x: 9, y: 27)] {
            wings.fill(Path(ellipseIn: CGRect(x: dot.x - 1.3, y: dot.y - 1.3, width: 2.6, height: 2.6)), with: .color(.white))
        }

        context.fill(Path(roundedRect: CGRect(x: 18.6, y: 9, width: 2.8, height: 22), cornerRadius: 1.4), with: .color(edge))
        context.fill(Path(ellipseIn: CGRect(x: 17.7, y: 6, width: 4.6, height: 4.6)), with: .color(edge))
        context.stroke(Path { p in
            p.move(to: CGPoint(x: 19.3, y: 7)); p.addQuadCurve(to: CGPoint(x: 15, y: 1.5), control: CGPoint(x: 17, y: 3))
            p.move(to: CGPoint(x: 20.7, y: 7)); p.addQuadCurve(to: CGPoint(x: 25, y: 1.5), control: CGPoint(x: 23, y: 3))
        }, with: .color(edge), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
    }
}

#Preview {
    HStack(spacing: 16) {
        ForEach(BugKind.allCases) { kind in
            VStack {
                BugSprite(kind: kind).frame(width: 60, height: 60)
                Text(kind.name).font(.caption)
            }
        }
    }
    .padding()
}
