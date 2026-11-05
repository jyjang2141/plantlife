//
//  PlantArt.swift
//  plantlife
//
//  Drawn plants and the watering can (replaces the emoji sprites).
//

import SwiftUI

// MARK: - How a plant looks

/// Seedlings are two little leaves. Each watering grows them into their real plant:
/// a sunflower, a cactus, or a leafy plant.
struct PlantSprite: View {
    let kind: PlantKind
    let growth: Int
    let droopy: Bool
    var size: CGFloat = 100
    /// Caterpillar damage, 0 to 3. Each level bites two more holes through the leaves.
    var holes: Int = 0

    var body: some View {
        ZStack {
            Canvas { context, canvasSize in
                // All drawing below uses an 80 x 80 box with the ground at the bottom.
                context.scaleBy(x: canvasSize.width / 80, y: canvasSize.height / 80)
                context.drawLayer { layer in
                    if growth == 0 {
                        PlantDrawing.seedling(in: &layer)
                    } else {
                        switch kind {
                        case .sunflower: PlantDrawing.sunflower(in: &layer)
                        case .cactus:    PlantDrawing.cactus(in: &layer)
                        case .standard:  PlantDrawing.leafy(in: &layer)
                        }
                    }
                    // Punch see-through holes where the caterpillar chewed.
                    if holes > 0 {
                        layer.blendMode = .destinationOut
                        for spot in PlantDrawing.holeSpots(kind: kind, growth: growth).prefix(min(holes, 3) * 2) {
                            layer.fill(Path(ellipseIn: CGRect(x: spot.x - 2.5, y: spot.y - 2, width: 5, height: 4)),
                                       with: .color(.black))
                        }
                    }
                }
            }
            // Thirsty plants droop. Chewed plants wilt: they slump, lean, and turn a little yellow.
            .scaleEffect(x: 1, y: Self.squash(holes: holes), anchor: .bottom)
            .rotationEffect(.degrees(Self.lean(droopy: droopy, holes: holes)), anchor: .bottom)
            .saturation(droopy ? 0.35 : 1)
            .colorMultiply(Self.wiltTint(holes: holes))

            // Leaves that dropped off the chewed plant, lying on the ground.
            if holes > 0 {
                Canvas { context, canvasSize in
                    context.scaleBy(x: canvasSize.width / 80, y: canvasSize.height / 80)
                    PlantDrawing.fallenLeaves(in: &context, kind: kind, count: min(holes, 3))
                }
                .transition(.opacity)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(Self.growthScale(growth), anchor: .bottom)
        .animation(.spring(duration: 0.6), value: growth)
        .animation(.easeInOut(duration: 0.5), value: droopy)
        .animation(.easeInOut(duration: 0.6), value: holes)
        .accessibilityHidden(true)
    }

    // These are shared with PlantWithBugs, so bugs sit in the right spot on a leaning plant.

    /// Bigger plants are drawn bigger.
    static func growthScale(_ growth: Int) -> CGFloat {
        growth == 0 ? 1 : 0.75 + CGFloat(min(growth, GardenPlant.maxGrowth)) * 0.083
    }

    /// Degrees the plant tips over (negative = to the left).
    static func lean(droopy: Bool, holes: Int) -> Double {
        (droopy ? -10 : 0) - (holes > 0 ? 2 + 2 * Double(min(holes, 3)) : 0)
    }

    /// How much a chewed plant slumps (1 = standing tall).
    static func squash(holes: Int) -> CGFloat {
        1 - 0.03 * CGFloat(min(holes, 3))
    }

    /// Chewed leaves turn yellowish. White = no change.
    static func wiltTint(holes: Int) -> Color {
        let h = Double(min(holes, 3))
        return Color(red: 1, green: 1 - 0.05 * h, blue: 1 - 0.24 * h)
    }
}

private enum PlantDrawing {
    static let stem      = Color(red: 0.24, green: 0.56, blue: 0.20)
    static let leafDark  = Color(red: 0.22, green: 0.58, blue: 0.22)
    static let leafLight = Color(red: 0.36, green: 0.74, blue: 0.30)
    static let vein      = Color(red: 0.72, green: 0.90, blue: 0.60)
    static let petal     = Color(red: 1.00, green: 0.78, blue: 0.10)
    static let seedCenter = Color(red: 0.45, green: 0.27, blue: 0.10)
    static let cactusGreen = Color(red: 0.33, green: 0.68, blue: 0.38)
    static let cactusRib   = Color(red: 0.22, green: 0.50, blue: 0.27)
    static let bloom       = Color(red: 0.98, green: 0.45, blue: 0.60)
    static let sprout      = Color(red: 0.50, green: 0.80, blue: 0.35)

    /// Spots on the leaves for caterpillar holes (in the 80 x 80 box), in the order they get chewed.
    static func holeSpots(kind: PlantKind, growth: Int) -> [CGPoint] {
        let spots: [(CGFloat, CGFloat)]
        if growth == 0 {
            spots = [(29, 57), (50, 56), (34, 58), (46, 58), (26, 56), (54, 55)]
        } else {
            switch kind {
            case .sunflower: spots = [(28, 59), (47, 49.5), (34, 58.5), (53, 50), (40, 10), (27, 25)]
            case .cactus:    spots = [(37, 40), (43, 58), (25, 47), (55, 38), (40, 66), (44, 30)]
            case .standard:  spots = [(31, 54), (49, 54), (37.5, 44), (42.5, 56), (27.5, 47), (52.5, 47)]
            }
        }
        return spots.map { CGPoint(x: $0.0, y: $0.1) }
    }

    /// Up to three dropped leaves on the ground (bits of cactus for cacti).
    static func fallenLeaves(in context: inout GraphicsContext, kind: PlantKind, count: Int) {
        let spots: [(x: CGFloat, y: CGFloat, angle: Double)] = [(22, 75.5, -18), (58, 76, 24), (31, 77.5, 8)]
        for (index, spot) in spots.prefix(count).enumerated() {
            var leaf = context
            leaf.translateBy(x: spot.x, y: spot.y)
            leaf.rotate(by: .degrees(spot.angle))
            if kind == .cactus {
                leaf.fill(Path(roundedRect: CGRect(x: -3.5, y: -2, width: 7, height: 4), cornerRadius: 2),
                          with: .color(Color(red: 0.45, green: 0.62, blue: 0.36)))
            } else {
                let color = index == 1 ? Color(red: 0.72, green: 0.57, blue: 0.24) : Color(red: 0.60, green: 0.66, blue: 0.24)
                leaf.fill(Path { p in
                    p.move(to: CGPoint(x: -6, y: 0))
                    p.addQuadCurve(to: CGPoint(x: 6, y: 0), control: CGPoint(x: 0, y: -5))
                    p.addQuadCurve(to: CGPoint(x: -6, y: 0), control: CGPoint(x: 0, y: 5))
                }, with: .color(color))
                leaf.stroke(Path { p in
                    p.move(to: CGPoint(x: -5, y: 0)); p.addLine(to: CGPoint(x: 5, y: 0))
                }, with: .color(.black.opacity(0.18)), lineWidth: 0.6)
            }
        }
    }

    static func seedling(in context: inout GraphicsContext) {
        context.stroke(Path { p in
            p.move(to: CGPoint(x: 40, y: 74)); p.addLine(to: CGPoint(x: 40, y: 58))
        }, with: .color(stem), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        context.fill(Path { p in
            p.move(to: CGPoint(x: 40, y: 60))
            p.addCurve(to: CGPoint(x: 23, y: 56), control1: CGPoint(x: 34, y: 51), control2: CGPoint(x: 26, y: 51))
            p.addCurve(to: CGPoint(x: 40, y: 60), control1: CGPoint(x: 28, y: 62), control2: CGPoint(x: 35, y: 63))
        }, with: .color(sprout))
        context.fill(Path { p in
            p.move(to: CGPoint(x: 40, y: 60))
            p.addCurve(to: CGPoint(x: 57, y: 56), control1: CGPoint(x: 46, y: 51), control2: CGPoint(x: 54, y: 51))
            p.addCurve(to: CGPoint(x: 40, y: 60), control1: CGPoint(x: 52, y: 62), control2: CGPoint(x: 45, y: 63))
        }, with: .color(leafLight))
    }

    static func sunflower(in context: inout GraphicsContext) {
        context.stroke(Path { p in
            p.move(to: CGPoint(x: 40, y: 74))
            p.addCurve(to: CGPoint(x: 40, y: 34), control1: CGPoint(x: 40, y: 62), control2: CGPoint(x: 41, y: 50))
        }, with: .color(stem), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        context.fill(Path { p in
            p.move(to: CGPoint(x: 40, y: 58))
            p.addCurve(to: CGPoint(x: 21, y: 60), control1: CGPoint(x: 32, y: 53), control2: CGPoint(x: 25, y: 55))
            p.addCurve(to: CGPoint(x: 40, y: 58), control1: CGPoint(x: 28, y: 64), control2: CGPoint(x: 35, y: 63))
        }, with: .color(leafLight))
        context.fill(Path { p in
            p.move(to: CGPoint(x: 40, y: 49))
            p.addCurve(to: CGPoint(x: 59, y: 51), control1: CGPoint(x: 48, y: 44), control2: CGPoint(x: 55, y: 46))
            p.addCurve(to: CGPoint(x: 40, y: 49), control1: CGPoint(x: 52, y: 55), control2: CGPoint(x: 45, y: 54))
        }, with: .color(leafDark))
        for index in 0..<10 {
            let petalShape = Path(ellipseIn: CGRect(x: -3.6, y: -17, width: 7.2, height: 16))
                .applying(CGAffineTransform(rotationAngle: CGFloat(index) * .pi / 5)
                    .concatenating(CGAffineTransform(translationX: 40, y: 24)))
            context.fill(petalShape, with: .color(petal))
        }
        context.fill(Path(ellipseIn: CGRect(x: 33, y: 17, width: 14, height: 14)), with: .color(seedCenter))
    }

    static func cactus(in context: inout GraphicsContext) {
        let parts = [
            CGRect(x: 33, y: 22, width: 14, height: 52),   // trunk
            CGRect(x: 21, y: 38, width: 8, height: 18),    // left arm
            CGRect(x: 21, y: 49, width: 16, height: 7),
            CGRect(x: 51, y: 30, width: 8, height: 18),    // right arm
            CGRect(x: 43, y: 41, width: 16, height: 7),
        ]
        for rect in parts {
            context.fill(Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) / 2),
                         with: .color(cactusGreen))
        }
        context.stroke(Path { p in
            for x in [36.5, 40, 43.5] {
                p.move(to: CGPoint(x: x, y: 28)); p.addLine(to: CGPoint(x: x, y: 72))
            }
        }, with: .color(cactusRib.opacity(0.7)), lineWidth: 1)
        context.fill(Path(ellipseIn: CGRect(x: 36.8, y: 17.8, width: 6.4, height: 6.4)), with: .color(bloom))
    }

    static func leafy(in context: inout GraphicsContext) {
        context.fill(Path { p in
            p.move(to: CGPoint(x: 40, y: 74))
            p.addCurve(to: CGPoint(x: 23, y: 37), control1: CGPoint(x: 30, y: 62), control2: CGPoint(x: 22, y: 52))
            p.addCurve(to: CGPoint(x: 40, y: 74), control1: CGPoint(x: 33, y: 43), control2: CGPoint(x: 39, y: 57))
        }, with: .color(leafDark))
        context.fill(Path { p in
            p.move(to: CGPoint(x: 40, y: 74))
            p.addCurve(to: CGPoint(x: 57, y: 37), control1: CGPoint(x: 50, y: 62), control2: CGPoint(x: 58, y: 52))
            p.addCurve(to: CGPoint(x: 40, y: 74), control1: CGPoint(x: 47, y: 43), control2: CGPoint(x: 41, y: 57))
        }, with: .color(leafDark))
        context.fill(Path { p in
            p.move(to: CGPoint(x: 40, y: 74))
            p.addCurve(to: CGPoint(x: 40, y: 22), control1: CGPoint(x: 33, y: 58), control2: CGPoint(x: 33, y: 40))
            p.addCurve(to: CGPoint(x: 40, y: 74), control1: CGPoint(x: 47, y: 40), control2: CGPoint(x: 47, y: 58))
        }, with: .color(leafLight))
        context.stroke(Path { p in
            p.move(to: CGPoint(x: 40, y: 70)); p.addLine(to: CGPoint(x: 40, y: 28))
        }, with: .color(vein), lineWidth: 1.2)
    }
}

// MARK: - Watering can

struct WateringCan: View {
    static let tankColor = Color(red: 0.25, green: 0.60, blue: 0.95)
    static let outline = Color(red: 0.10, green: 0.35, blue: 0.70)

    var body: some View {
        Canvas { context, canvasSize in
            // Drawn in a 48 x 48 box with the spout pointing up and to the left.
            context.scaleBy(x: canvasSize.width / 48, y: canvasSize.height / 48)
            let tank = Path(roundedRect: CGRect(x: 18, y: 18, width: 22, height: 23), cornerRadius: 3)
            context.fill(tank, with: .color(Self.tankColor))
            context.stroke(tank, with: .color(Self.outline), lineWidth: 1.8)
            context.stroke(Path { p in
                p.addArc(center: CGPoint(x: 29, y: 18), radius: 6,
                         startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            }, with: .color(Self.outline), lineWidth: 2.4)
            context.stroke(Path { p in
                p.move(to: CGPoint(x: 18, y: 25)); p.addLine(to: CGPoint(x: 6, y: 16))
            }, with: .color(Self.outline), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            context.stroke(Path { p in
                p.move(to: CGPoint(x: 3, y: 12)); p.addLine(to: CGPoint(x: 8, y: 19))
            }, with: .color(Self.outline), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
            context.stroke(Path { p in
                p.move(to: CGPoint(x: 18, y: 28)); p.addLine(to: CGPoint(x: 40, y: 28))
            }, with: .color(.white.opacity(0.5)), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

/// Falling water drops, shown under the can while it pours.
struct WaterDrops: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { proxy in
                let time = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<9, id: \.self) { index in
                        let progress = (time * 1.8 + Double(index) * 0.11).truncatingRemainder(dividingBy: 1)
                        let column = Double(index % 3)
                        Image(systemName: "drop.fill")
                            .font(.system(size: 7 + progress * 4))
                            .foregroundStyle(Color(red: 0.35, green: 0.70, blue: 1.0))
                            .position(x: proxy.size.width * (0.2 + column * 0.3),
                                      y: proxy.size.height * progress)
                            .opacity(0.5 + progress * 0.5)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
