//
//  PlantArt.swift
//  plantlife
//
//  The plant sprite and the watering can.
//

import SwiftUI

// MARK: - How a plant looks

/// A plant drawn at one growth stage. The drawings come from the icon database (Garden/Icons).
struct PlantSprite: View {
    let species: PlantSpecies
    let stage: GrowthStage
    var flowerColor: FlowerColor? = nil
    /// Thirsty plants droop, lean, and fade.
    var droopy: Bool = false
    var dead: Bool = false
    var size: CGFloat = 100
    /// Caterpillar damage, 0 to 3. The icons draw bitten leaves, and the plant wilts a little more each level.
    var holes: Int = 0

    var body: some View {
        ZStack {
            Canvas { context, canvasSize in
                // All drawing uses an 80 x 80 box with the ground at the bottom.
                context.scaleBy(x: canvasSize.width / 80, y: canvasSize.height / 80)
                if dead {
                    PlantIcons.drawDead(in: context)
                } else {
                    PlantIcons.draw(species, stage, flowerColor: flowerColor ?? species.classicFlowerColor, in: context)
                }
            }
            .environment(\.leafBites, dead ? 0 : min(holes, 3))
            // Thirsty plants droop. Chewed plants wilt: they slump, lean, and turn a little yellow.
            .scaleEffect(x: 1, y: Self.squash(holes: dead ? 0 : holes), anchor: .bottom)
            .rotationEffect(.degrees(dead ? 0 : Self.lean(droopy: droopy, holes: holes)), anchor: .bottom)
            .saturation(droopy && !dead ? 0.35 : 1)
            .colorMultiply(Self.wiltTint(holes: dead ? 0 : holes))

            // Leaves that dropped off the chewed plant, lying on the ground.
            if holes > 0 && !dead {
                Canvas { context, canvasSize in
                    context.scaleBy(x: canvasSize.width / 80, y: canvasSize.height / 80)
                    Self.fallenLeaves(in: context, species: species, count: min(holes, 3))
                }
                .transition(.opacity)
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(duration: 0.6), value: stage)
        .animation(.easeInOut(duration: 0.5), value: droopy)
        .animation(.easeInOut(duration: 0.6), value: holes)
        .accessibilityHidden(true)
    }

    // These are shared with PlantWithBugs, so bugs sit in the right spot on a leaning plant.

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

    /// Up to three dropped leaves on the ground (bits of cactus for cacti and succulents,
    /// needles for pines, blades for grass and corn).
    static func fallenLeaves(in context: GraphicsContext, species: PlantSpecies, count: Int) {
        let spots: [(x: CGFloat, y: CGFloat, angle: Double)] = [(22, 75.5, -18), (58, 76, 24), (31, 77.5, 8)]
        for (index, spot) in spots.prefix(count).enumerated() {
            var leaf = context
            leaf.translateBy(x: spot.x, y: spot.y)
            leaf.rotate(by: .degrees(spot.angle))
            let brown = index == 1 ? Color(red: 0.72, green: 0.57, blue: 0.24) : Color(red: 0.60, green: 0.66, blue: 0.24)
            switch species {
            case .cactus, .succulent:
                leaf.fill(Path(roundedRect: CGRect(x: -3.5, y: -2, width: 7, height: 4), cornerRadius: 2),
                          with: .color(Color(red: 0.45, green: 0.62, blue: 0.36)))
            case .pine:
                for tilt in [-14.0, 0, 14] {
                    var needle = leaf
                    needle.rotate(by: .degrees(tilt))
                    needle.stroke(Path { p in p.move(to: pt(-5, 0)); p.addLine(to: pt(5, 0)) },
                                  with: .color(brown), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
                }
            case .grass, .corn:
                leaf.fill(Path { p in
                    p.move(to: pt(-7, 0.8))
                    p.addQuadCurve(to: pt(7, 0), control: pt(0, -1.6))
                    p.addQuadCurve(to: pt(-7, 0.8), control: pt(0, 1.8))
                }, with: .color(brown))
            default:
                leaf.fill(Path { p in
                    p.move(to: CGPoint(x: -6, y: 0))
                    p.addQuadCurve(to: CGPoint(x: 6, y: 0), control: CGPoint(x: 0, y: -5))
                    p.addQuadCurve(to: CGPoint(x: -6, y: 0), control: CGPoint(x: 0, y: 5))
                }, with: .color(brown))
                leaf.stroke(Path { p in
                    p.move(to: CGPoint(x: -5, y: 0)); p.addLine(to: CGPoint(x: 5, y: 0))
                }, with: .color(.black.opacity(0.18)), lineWidth: 0.6)
            }
        }
    }
}

extension PlantSprite {
    /// A garden plant as it looks now, or at another of its stages.
    init(plant: GardenPlant, stage: GrowthStage? = nil, droopy: Bool = false, size: CGFloat = 100, holes: Int = 0) {
        self.init(species: plant.species, stage: stage ?? plant.stage, flowerColor: plant.flowerColor,
                  droopy: droopy, size: size, holes: holes)
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
