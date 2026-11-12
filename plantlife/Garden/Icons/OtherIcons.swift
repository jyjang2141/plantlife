//
//  OtherIcons.swift
//  plantlife
//
//  Fern, grass, succulent, basil, berry bush, the default plant, and the dead plant.
//

import SwiftUI

enum OtherIcons {

    // MARK: Fern

    private static let fernDark  = Color(red: 0.18, green: 0.52, blue: 0.24)
    private static let fernLight = Color(red: 0.32, green: 0.66, blue: 0.30)

    static func fern(_ stage: GrowthStage, _ g: GraphicsContext) {
        switch stage {
        case .sprout:
            fiddlehead(g, base: pt(40, 74), height: 14, radius: 3.6)
        case .seedling:
            g.frond(from: pt(40, 74), bend: pt(32, 56), to: pt(24, 46), leaflet: 6, count: 7, spread: 75, fernLight)
            fiddlehead(g, base: pt(43, 74), height: 16, radius: 3.2)
        default:
            let fronds: [(CGPoint, CGPoint, Color)] = [
                (pt(8, 54), pt(16, 30), fernDark), (pt(72, 54), pt(64, 30), fernDark),
                (pt(20, 18), pt(26, 34), fernLight), (pt(60, 18), pt(54, 34), fernLight),
                (pt(40, 10), pt(42, 40), fernDark),
            ]
            for (tip, bend, color) in fronds {
                g.frond(from: pt(40, 74), bend: bend, to: tip, leaflet: 8, count: 10, spread: 75, color)
            }
            fiddlehead(g, base: pt(44, 74), height: 18, radius: 3.4)
        }
    }

    /// A young fern leaf, still curled up like the top of a violin.
    private static func fiddlehead(_ g: GraphicsContext, base: CGPoint, height: CGFloat, radius r: CGFloat) {
        let y = base.y - height + r
        var path = Path()
        path.move(to: base)
        path.addLine(to: pt(base.x, y))
        path.addArc(center: pt(base.x + r, y), radius: r, startAngle: .degrees(180), endAngle: .degrees(90), clockwise: false)
        path.addArc(center: pt(base.x + r, y + r * 0.45), radius: r * 0.55,
                    startAngle: .degrees(90), endAngle: .degrees(330), clockwise: false)
        g.stroke(path, with: .color(fernLight), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
    }

    // MARK: Grass

    static func grass(_ stage: GrowthStage, _ g: GraphicsContext) {
        switch stage {
        case .sprout:
            grassBlades(g, [(pt(39, 74), pt(37, 61)), (pt(41, 74), pt(44, 64))], width: 2.2)
        case .seedling:
            grassBlades(g, [(pt(37, 74), pt(30, 56)), (pt(39, 74), pt(36, 50)), (pt(40, 74), pt(42, 47)),
                            (pt(41, 74), pt(48, 52)), (pt(43, 74), pt(53, 59))], width: 2.6)
        default:
            grassBlades(g, [(pt(34, 74), pt(12, 50)), (pt(35, 74), pt(20, 34)), (pt(37, 74), pt(28, 20)),
                            (pt(38, 74), pt(34, 12)), (pt(39, 74), pt(39, 26)), (pt(40, 74), pt(45, 8)),
                            (pt(41, 74), pt(50, 20)), (pt(42, 74), pt(55, 30)), (pt(43, 74), pt(62, 22)),
                            (pt(45, 74), pt(68, 42)), (pt(46, 74), pt(72, 58))], width: 3.2)
        }
    }

    private static func grassBlades(_ g: GraphicsContext, _ blades: [(CGPoint, CGPoint)], width: CGFloat) {
        let colors = [Ink.leafDark, Ink.leafLight, Ink.sprout]
        for (index, (base, tip)) in blades.enumerated() {
            // rises first, then leans out
            let bend = pt(base.x + (tip.x - base.x) * 0.25, base.y + (tip.y - base.y) * 0.75)
            g.blade(from: base, to: tip, bend: bend, width: width, colors[index % colors.count])
        }
    }

    // MARK: Succulent

    private static let succulent      = Color(red: 0.50, green: 0.72, blue: 0.62)
    private static let succulentLight = Color(red: 0.64, green: 0.83, blue: 0.73)
    private static let succulentDark  = Color(red: 0.38, green: 0.60, blue: 0.52)
    private static let succulentTip   = Color(red: 0.88, green: 0.50, blue: 0.56)

    static func succulent(_ stage: GrowthStage, _ g: GraphicsContext) {
        switch stage {
        case .sprout:
            plumpLeaf(g, angle: -40, length: 8, width: 6, succulent)
            plumpLeaf(g, angle: 40, length: 8, width: 6, succulentLight)
        case .seedling:
            for angle in [-70.0, -35, 0, 35, 70] { plumpLeaf(g, angle: angle, length: 12, width: 8, succulent) }
            for angle in [-18.0, 18] { plumpLeaf(g, angle: angle, length: 8, width: 6, succulentLight) }
        default:
            for angle in [-36.0, -12, 12, 36] { plumpLeaf(g, angle: angle, length: 26, width: 9, succulentLight) }
            for angle in [-58.0, -28, 0, 28, 58] { plumpLeaf(g, angle: angle, length: 23, width: 9, succulent) }
            for angle in [-84.0, -70, 70, 84] { plumpLeaf(g, angle: angle, length: 21, width: 8, succulentDark) }
            for angle in [-14.0, 14] { plumpLeaf(g, angle: angle, length: 12, width: 6, succulentLight) }
        }
    }

    private static func plumpLeaf(_ g: GraphicsContext, angle: Double, length: CGFloat, width: CGFloat, _ color: Color) {
        let base = pt(40, 72)
        g.leaf(base, angle: angle, length: length, width: width, color)
        g.leaf(toward(base, angle, length * 0.8), angle: angle, length: length * 0.2, width: width * 0.22, succulentTip)
    }

    // MARK: Basil

    private static let basilDark  = Color(red: 0.24, green: 0.60, blue: 0.24)
    private static let basilLight = Color(red: 0.40, green: 0.76, blue: 0.32)

    static func basil(_ stage: GrowthStage, _ color: FlowerColor, _ g: GraphicsContext) {
        switch stage {
        case .sprout:
            CommonParts.sprout(g, width: 5, length: 8)
        case .seedling:
            g.line(pt(40, 74), pt(40, 54))
            g.leaf(pt(40, 64), angle: -75, length: 8, width: 5.5, Ink.sprout)
            g.leaf(pt(40, 64), angle: 75, length: 8, width: 5.5, Ink.leafLight)
            basilPair(g, at: pt(40, 55), size: 11, spread: 45, basilDark)
        case .vegetating:
            basilBush(g, top: 22)
            basilPair(g, at: pt(40, 23), size: 7, spread: 30, basilLight)
        case .budding:
            basilBush(g, top: 12)
            for y in [24.0, 19, 14] as [CGFloat] {
                g.oval(pt(37, y), width: 5, height: 3, Ink.bud)
                g.oval(pt(43, y), width: 5, height: 3, Ink.bud)
            }
        default:
            basilBush(g, top: 10)
            for y in [26.0, 20, 14] as [CGFloat] {
                for x in [36.0, 44] as [CGFloat] {
                    g.flower(pt(x, y), radius: 2.8, petals: 4, color.shade, center: nil, petalWidth: 1)
                    g.flower(pt(x, y), radius: 2.3, petals: 4, color.petal, center: nil, petalWidth: 0.9)
                }
            }
            g.dot(pt(40, 10), 1.8, color.petal)
        }
    }

    private static func basilBush(_ g: GraphicsContext, top: CGFloat) {
        g.line(pt(40, 74), pt(40, top), width: 3)
        basilPair(g, at: pt(40, 64), size: 16, spread: 68, basilDark)
        basilPair(g, at: pt(40, 54), size: 16, spread: 48, basilLight)
        basilPair(g, at: pt(40, 44), size: 14, spread: 66, basilDark)
        basilPair(g, at: pt(40, 35), size: 12, spread: 44, basilLight)
    }

    private static func basilPair(_ g: GraphicsContext, at p: CGPoint, size: CGFloat, spread: Double, _ color: Color) {
        g.leaf(p, angle: -spread, length: size, width: size * 0.55, color, vein: true)
        g.leaf(p, angle: spread, length: size, width: size * 0.55, color, vein: true)
    }

    // MARK: Berry bush

    private static let bushDark    = Color(red: 0.18, green: 0.46, blue: 0.26)
    private static let bushLight   = Color(red: 0.32, green: 0.60, blue: 0.34)
    private static let blueberry   = Color(red: 0.28, green: 0.34, blue: 0.68)
    private static let unripeBerry = Color(red: 0.72, green: 0.42, blue: 0.56)
    private static let bushSpots   = [pt(26, 46), pt(36, 36), pt(52, 42), pt(57, 54), pt(41, 52), pt(46, 28), pt(28, 58)]

    static func bush(_ stage: GrowthStage, _ g: GraphicsContext) {
        switch stage {
        case .sprout:     CommonParts.sprout(g)
        case .seedling:   CommonParts.seedling(g)
        case .vegetating: bushBody(g)
        case .budding:
            bushBody(g)
            for spot in bushSpots {
                g.dot(spot, 1.8, Color(red: 0.95, green: 0.78, blue: 0.80))
                g.dot(pt(spot.x + 3, spot.y + 1), 1.6, Ink.bud)
            }
        case .flowering:
            bushBody(g)
            for spot in bushSpots {
                for offset in [pt(-2.4, 0), pt(2.4, 0.8), pt(0, 3)] {
                    let p = pt(spot.x + offset.x, spot.y + offset.y)
                    g.oval(p, width: 4, height: 4.6, FlowerColor.white.petal)
                    g.dot(pt(p.x, p.y + 2), 1, FlowerColor.white.shade)
                }
            }
        default:
            bushBody(g)
            for (index, spot) in bushSpots.enumerated() {
                for offset in [pt(-2.6, 0), pt(2.6, 0.6), pt(0, 3.4)] {
                    let p = pt(spot.x + offset.x, spot.y + offset.y)
                    g.dot(p, 2.6, index == 4 ? unripeBerry : blueberry)
                    g.dot(pt(p.x - 0.8, p.y - 0.8), 0.7, .white.opacity(0.5))
                }
            }
        }
    }

    private static func bushBody(_ g: GraphicsContext) {
        g.line(pt(38, 74), pt(30, 56), width: 2.6, color: Ink.bark)
        g.line(pt(40, 74), pt(40, 52), width: 2.6, color: Ink.bark)
        g.line(pt(42, 74), pt(52, 56), width: 2.6, color: Ink.bark)
        g.canopy([(40, 44, 18), (23, 50, 12), (57, 50, 12), (29, 34, 12), (51, 34, 12), (40, 27, 11)], bushDark)
        g.canopy([(34, 32, 7), (50, 40, 6), (24, 48, 5)], bushLight)
        for (p, angle) in [(pt(12, 48), -80.0), (pt(68, 48), 80.0), (pt(22, 28), -40.0), (pt(58, 28), 40.0), (pt(40, 17), 0.0)] {
            g.leaf(p, angle: angle, length: 6, width: 3, bushLight)
        }
    }

    // MARK: Default plant

    static func defaultPlant(_ stage: GrowthStage, _ color: FlowerColor, _ g: GraphicsContext) {
        switch stage {
        case .sprout:
            CommonParts.sprout(g)
        case .seedling:
            CommonParts.seedling(g)
        case .vegetating:
            g.leaf(pt(40, 74), angle: -32, length: 40, width: 11, Ink.leafDark)
            g.leaf(pt(40, 74), angle: 32, length: 40, width: 11, Ink.leafDark)
            g.leaf(pt(40, 74), angle: 0, length: 52, width: 11, Ink.leafLight, vein: true)
        case .budding:
            smallLeaves(g)
            g.line(pt(40, 72), pt(41, 44), pt(40, 24), width: 2.4)
            g.oval(pt(40, 21), width: 7, height: 10, Ink.bud)
            g.oval(pt(40, 18), width: 4.5, height: 5, color.petal)
        default:
            smallLeaves(g)
            g.line(pt(40, 72), pt(41, 44), pt(40, 26), width: 2.4)
            g.flower(pt(40, 20), radius: 10.5, petals: 6, color.shade, center: nil, petalWidth: 0.8)
            g.flower(pt(40, 20), radius: 9.2, petals: 6, color.petal,
                     center: color == .yellow ? Ink.blossomCenter : Ink.flowerCenter,
                     petalWidth: 0.66, centerSize: 0.3)
        }
    }

    private static func smallLeaves(_ g: GraphicsContext) {
        g.leaf(pt(40, 74), angle: -40, length: 30, width: 9, Ink.leafDark)
        g.leaf(pt(40, 74), angle: 40, length: 30, width: 9, Ink.leafDark)
        g.leaf(pt(40, 74), angle: -14, length: 28, width: 8, Ink.leafLight, vein: true)
        g.leaf(pt(40, 74), angle: 16, length: 26, width: 8, Ink.leafLight, vein: true)
    }

    // MARK: Dead plant (shared by every plant)

    static func dead(_ g: GraphicsContext) {
        g.line(pt(40, 74), pt(40, 50), pt(46, 40), pt(55, 50), width: 3, color: Ink.deadDark)
        g.leaf(pt(40, 64), angle: -128, length: 13, width: 5, Ink.dead)
        g.leaf(pt(41, 55), angle: 140, length: 12, width: 4.5, Ink.dead)
        g.leaf(pt(44, 44), angle: -150, length: 10, width: 4, Ink.deadDark)
        g.leaf(pt(55, 50), angle: 175, length: 9, width: 3.6, Ink.dead)
        g.oval(pt(25, 72.5), width: 11, height: 3.4, angle: -8, Ink.dead)
        g.oval(pt(58, 73), width: 8, height: 2.8, angle: 10, Ink.deadDark)
    }
}
