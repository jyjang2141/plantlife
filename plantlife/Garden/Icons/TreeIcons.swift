//
//  TreeIcons.swift
//  plantlife
//
//  Oak, maple, pine and coconut palm at each growth stage.
//

import SwiftUI

enum TreeIcons {

    // MARK: Oak

    private static let oakDark   = Color(red: 0.20, green: 0.48, blue: 0.22)
    private static let oakLight  = Color(red: 0.32, green: 0.62, blue: 0.28)
    private static let acornNut  = Color(red: 0.66, green: 0.44, blue: 0.18)
    private static let acornCap  = Color(red: 0.45, green: 0.30, blue: 0.14)

    static func oak(_ stage: GrowthStage, _ g: GraphicsContext) {
        switch stage {
        case .sprout:
            acorn(g, pt(31, 70), size: 3.6)
            CommonParts.sprout(g)
        case .seedling:
            acorn(g, pt(31, 70), size: 3.6)
            g.line(pt(40, 74), pt(40, 44), width: 2.4, color: Ink.bark)
            oakLeaf(g, pt(40, 58), angle: -55, length: 15, oakDark)
            oakLeaf(g, pt(40, 52), angle: 50, length: 15, oakLight)
            oakLeaf(g, pt(40, 45), angle: -5, length: 13, oakDark)
        case .vegetating:
            oakTree(g)
        default:
            oakTree(g)
            for spot in [pt(23, 42), pt(34, 46), pt(52, 44), pt(59, 34), pt(44, 30), pt(28, 28)] {
                acorn(g, spot, size: 3.4)
            }
            acorn(g, pt(58, 71), size: 3.2)
        }
    }

    private static func oakTree(_ g: GraphicsContext) {
        var trunk = Path()
        trunk.move(to: pt(33, 74))
        trunk.addQuadCurve(to: pt(37, 42), control: pt(38, 60))
        trunk.addLine(to: pt(43, 42))
        trunk.addQuadCurve(to: pt(47, 74), control: pt(42, 60))
        trunk.closeSubpath()
        g.paint(trunk, Ink.bark)
        g.line(pt(38, 50), pt(30, 44), pt(26, 38), width: 3, color: Ink.bark)
        g.line(pt(42, 48), pt(50, 42), pt(54, 36), width: 3, color: Ink.bark)
        g.canopy([(40, 30, 17), (23, 36, 12), (57, 36, 12), (29, 21, 12), (51, 21, 12), (40, 15, 10)], oakDark)
        g.canopy([(33, 22, 8), (50, 27, 7), (24, 34, 6), (42, 14, 5)], oakLight)
    }

    private static func oakLeaf(_ g: GraphicsContext, _ base: CGPoint, angle: Double, length: CGFloat, _ color: Color) {
        g.leaf(base, angle: angle, length: length, width: length * 0.3, color)
        for t in [0.35, 0.6, 0.82] as [CGFloat] {
            let p = toward(base, angle, length * t)
            let r = length * 0.14 * (1.1 - t * 0.4)
            g.dot(toward(p, angle - 90, length * 0.16 * (1 - t * 0.3)), r, color)
            g.dot(toward(p, angle + 90, length * 0.16 * (1 - t * 0.3)), r, color)
        }
    }

    private static func acorn(_ g: GraphicsContext, _ c: CGPoint, size s: CGFloat) {
        g.oval(pt(c.x, c.y + s * 0.4), width: s * 1.5, height: s * 1.9, acornNut)
        g.oval(pt(c.x, c.y - s * 0.15), width: s * 1.9, height: s * 1.1, acornCap)
        g.line(pt(c.x, c.y - s * 0.6), pt(c.x + 0.6, c.y - s * 1.1), width: 1, color: acornCap)
    }

    // MARK: Maple

    private static let mapleDark   = Color(red: 0.24, green: 0.54, blue: 0.22)
    private static let mapleLight  = Color(red: 0.38, green: 0.68, blue: 0.28)
    private static let mapleFlower = Color(red: 0.88, green: 0.20, blue: 0.22)
    private static let samaraWing  = Color(red: 0.82, green: 0.60, blue: 0.34)
    private static let samaraSeed  = Color(red: 0.62, green: 0.36, blue: 0.18)

    static func maple(_ stage: GrowthStage, _ g: GraphicsContext) {
        switch stage {
        case .sprout:
            CommonParts.sprout(g, width: 2.4, length: 13)
        case .seedling:
            g.line(pt(40, 74), pt(40, 50), width: 2.4)
            g.leaf(pt(40, 64), angle: -72, length: 14, width: 2.6, Ink.sprout)
            g.leaf(pt(40, 64), angle: 72, length: 14, width: 2.6, Ink.leafLight)
            g.line(pt(40, 52), pt(33, 46), width: 1.2)
            g.line(pt(40, 52), pt(47, 46), width: 1.2)
            mapleLeaf(g, pt(32, 44), radius: 7, angle: -30, mapleDark)
            mapleLeaf(g, pt(48, 44), radius: 7, angle: 30, mapleLight)
        case .vegetating:
            mapleTree(g)
        case .flowering:
            mapleTree(g)
            for spot in [pt(26, 30), pt(36, 22), pt(50, 18), pt(56, 34), pt(42, 38), pt(30, 44), pt(46, 8)] {
                g.dot(spot, 1.7, mapleFlower)
                g.dot(pt(spot.x - 2, spot.y + 1.5), 1.5, mapleFlower)
                g.dot(pt(spot.x + 2, spot.y + 1.5), 1.5, mapleFlower)
            }
        default:
            mapleTree(g)
            for (spot, angle) in [(pt(24, 46), 180.0), (pt(56, 46), 180.0), (pt(32, 47), 190.0), (pt(15, 38), 200.0)] {
                samara(g, spot, angle: angle)
            }
            samara(g, pt(64, 62), angle: 120)   // one spinning down to the ground
        }
    }

    private static func mapleTree(_ g: GraphicsContext) {
        var trunk = Path()
        trunk.move(to: pt(35, 74))
        trunk.addQuadCurve(to: pt(38, 40), control: pt(39, 60))
        trunk.addLine(to: pt(42, 40))
        trunk.addQuadCurve(to: pt(45, 74), control: pt(41, 60))
        trunk.closeSubpath()
        g.paint(trunk, Ink.bark)
        g.line(pt(39, 50), pt(32, 44), width: 2.4, color: Ink.bark)
        g.line(pt(41, 47), pt(48, 41), width: 2.4, color: Ink.bark)
        g.canopy([(40, 28, 16), (28, 36, 11), (52, 36, 11), (31, 20, 10), (49, 20, 10), (40, 12, 9)], mapleDark)
        g.canopy([(34, 20, 6), (48, 28, 6), (28, 34, 5)], mapleLight)
        mapleLeaf(g, pt(17, 34), radius: 6, angle: -50, mapleLight)
        mapleLeaf(g, pt(63, 32), radius: 6, angle: 50, mapleLight)
        mapleLeaf(g, pt(40, 3.5), radius: 5, angle: 0, mapleLight)
        mapleLeaf(g, pt(23, 18), radius: 5, angle: -30, mapleDark)
        mapleLeaf(g, pt(57, 16), radius: 5, angle: 30, mapleDark)
    }

    /// A maple leaf: three big pointed lobes and two small ones.
    private static func mapleLeaf(_ g: GraphicsContext, _ c: CGPoint, radius r: CGFloat, angle: Double, _ color: Color) {
        let outline: [(Double, CGFloat)] = [
            (0, 1), (28, 0.45), (62, 0.95), (95, 0.42), (125, 0.6), (180, 0.22),
            (235, 0.6), (265, 0.42), (298, 0.95), (332, 0.45),
        ]
        var shape = Path()
        for (index, (direction, reach)) in outline.enumerated() {
            let p = toward(c, angle + direction, r * reach)
            if index == 0 { shape.move(to: p) } else { shape.addLine(to: p) }
        }
        shape.closeSubpath()
        g.paint(shape, color)
    }

    /// A maple "helicopter": a seed with two wings.
    private static func samara(_ g: GraphicsContext, _ seed: CGPoint, angle: Double) {
        g.leaf(seed, angle: angle - 24, length: 12, width: 3.6, samaraWing)
        g.leaf(seed, angle: angle + 24, length: 12, width: 3.6, samaraWing)
        g.dot(seed, 2, samaraSeed)
    }

    // MARK: Pine

    private static let pineDark  = Color(red: 0.12, green: 0.42, blue: 0.28)
    private static let pineLight = Color(red: 0.22, green: 0.56, blue: 0.36)
    private static let pineStem  = Color(red: 0.58, green: 0.40, blue: 0.26)
    private static let cone      = Color(red: 0.56, green: 0.36, blue: 0.18)
    private static let coneDark  = Color(red: 0.40, green: 0.24, blue: 0.12)

    static func pine(_ stage: GrowthStage, _ g: GraphicsContext) {
        switch stage {
        case .sprout:
            g.line(pt(40, 74), pt(40, 62), width: 1.8, color: pineStem)
            needles(g, at: pt(40, 62), from: -70, to: 70, length: 8, pineLight)
            g.oval(pt(40, 56), width: 3.4, height: 4.4, Ink.seedBrown)   // the seed coat, still stuck on top
        case .seedling:
            g.line(pt(40, 74), pt(40, 46), width: 2, color: pineStem)
            needles(g, at: pt(40, 62), from: -80, to: 80, length: 10, pineDark)
            needles(g, at: pt(40, 53), from: -60, to: 60, length: 9, pineLight)
            needles(g, at: pt(40, 47), from: -30, to: 30, length: 7, pineLight)
        case .vegetating:
            pineTree(g)
        default:
            pineTree(g)
            for (spot, tilt) in [(pt(27, 58), 10.0), (pt(53, 57), -10.0), (pt(33, 44), 0.0), (pt(49, 30), 0.0)] {
                pineCone(g, spot, size: 4.4, angle: tilt)
            }
            pineCone(g, pt(62, 71), size: 4, angle: 80)
        }
    }

    private static let pineTiers: [(top: CGFloat, bottom: CGFloat, half: CGFloat)] = [(38, 64, 25), (22, 50, 19), (6, 35, 13)]

    private static func pineTree(_ g: GraphicsContext) {
        g.paint(Path(CGRect(x: 37, y: 60, width: 6, height: 14)), Ink.bark)
        // Chewed pines lose bites along the sloping edges of their tiers, two more for each level.
        var spots: [(CGPoint, Double)] = []
        for (index, tier) in pineTiers.enumerated() {
            for (side, f) in [(-1.0, 0.7), (1.0, 0.5), (1.0, 0.85)] as [(CGFloat, CGFloat)] {
                let flip = index % 2 == 0 ? side : -side
                let edge = pt(40 + flip * tier.half * f, tier.top + (tier.bottom - tier.top) * f)
                let slope = Double(atan2(tier.half, tier.bottom - tier.top)) * 180 / .pi
                spots.append((pt(edge.x + flip * 1.5, edge.y), Double(flip) * -slope))
            }
        }
        let bites = spots.prefix(g.bites * 3).map { biteShape($0.0, radius: 3.4, angle: $0.1) }
        g.chewed(Array(bites)) { pineTiersShape($0) }
    }

    private static func pineTiersShape(_ g: GraphicsContext) {
        for (top, bottom, half) in pineTiers {
            var tier = Path()
            tier.move(to: pt(40, top))
            tier.addLine(to: pt(40 + half, bottom))
            tier.addLine(to: pt(40 - half, bottom))
            tier.closeSubpath()
            g.paint(tier, pineDark)
            g.stroke(tier, with: .color(pineDark), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
            var shine = Path()
            shine.move(to: pt(40, top + 3))
            shine.addLine(to: pt(40 - half + 5, bottom - 1.5))
            shine.addLine(to: pt(40 - half * 0.35, bottom - 1.5))
            shine.closeSubpath()
            g.paint(shine, pineLight)
        }
    }

    private static func needles(_ g: GraphicsContext, at base: CGPoint, from: Double, to: Double, length: CGFloat, _ color: Color) {
        for angle in stride(from: from, through: to, by: 20) {
            g.line(base, toward(base, angle, length), width: 1.2, color: color)
        }
    }

    private static func pineCone(_ g: GraphicsContext, _ c: CGPoint, size s: CGFloat, angle: Double) {
        g.oval(c, width: s * 1.3, height: s * 2.1, angle: angle, cone)
        for step in -1...1 {
            let p = toward(c, angle, CGFloat(step) * s * 0.55)
            g.line(toward(p, angle - 120, s * 0.55), p, toward(p, angle + 120, s * 0.55),
                   width: 0.8, color: coneDark)
        }
    }

    // MARK: Coconut palm

    private static let husk       = Color(red: 0.62, green: 0.45, blue: 0.25)
    private static let coconut    = Color(red: 0.48, green: 0.32, blue: 0.18)
    private static let greenNut   = Color(red: 0.50, green: 0.64, blue: 0.26)
    private static let palmTrunk  = Color(red: 0.68, green: 0.52, blue: 0.34)
    private static let palmRing   = Color(red: 0.50, green: 0.36, blue: 0.22)
    private static let frondDark  = Color(red: 0.24, green: 0.56, blue: 0.24)
    private static let frondLight = Color(red: 0.36, green: 0.68, blue: 0.30)

    static func coconutPalm(_ stage: GrowthStage, _ g: GraphicsContext) {
        switch stage {
        case .sprout:
            // Coconut palms sprout straight out of a coconut lying on the ground.
            g.blade(from: pt(40, 68), to: pt(44, 52), bend: pt(40, 58), width: 3.4, Ink.sprout)
            g.oval(pt(37, 70), width: 16, height: 11, angle: -10, husk)
        case .seedling:
            g.blade(from: pt(40, 68), to: pt(28, 42), bend: pt(30, 54), width: 5.5, frondDark)
            g.blade(from: pt(40, 68), to: pt(54, 44), bend: pt(50, 54), width: 5.5, frondLight)
            g.blade(from: pt(40, 68), to: pt(41, 38), bend: pt(37, 52), width: 5, frondDark)
            g.oval(pt(35, 70), width: 16, height: 11, angle: -10, husk)
        case .vegetating:
            palmTree(g)
        default:
            palmTree(g)
            g.dot(pt(42, 28), 4, coconut)
            g.dot(pt(49, 28), 4, coconut)
            g.dot(pt(45.5, 33), 4, greenNut)
        }
    }

    private static func palmTree(_ g: GraphicsContext) {
        let base = pt(34, 74), bend = pt(30, 46), crown = pt(46, 24)
        g.line(base, bend, crown, width: 6.5, color: palmTrunk)
        for index in 1..<9 {
            let t = CGFloat(index) / 9
            let p = curvePoint(base, bend, crown, t)
            let heading = curveAngle(base, bend, crown, t)
            g.line(toward(p, heading - 90, 3), toward(p, heading + 90, 3), width: 0.9, color: palmRing)
        }
        let fronds: [(CGPoint, CGPoint, Color)] = [
            (pt(22, 50), pt(24, 20), frondDark), (pt(72, 50), pt(68, 20), frondDark),
            (pt(10, 34), pt(26, 12), frondLight), (pt(78, 32), pt(64, 10), frondLight),
            (pt(34, 6), pt(38, 14), frondDark), (pt(62, 8), pt(54, 12), frondLight),
        ]
        for (tip, bendPoint, color) in fronds {
            g.frond(from: crown, bend: bendPoint, to: tip, leaflet: 7, count: 9, spread: 50, color)
        }
    }
}
