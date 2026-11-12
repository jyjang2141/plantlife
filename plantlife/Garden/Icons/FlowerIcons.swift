//
//  FlowerIcons.swift
//  plantlife
//
//  Daisy, sunflower, cactus, tulip, rose, poppy and orchid at each growth stage.
//

import SwiftUI

enum FlowerIcons {

    // MARK: Daisy

    private static let daisyHeads = [pt(27, 32), pt(41, 20), pt(54, 30)]

    static func daisy(_ stage: GrowthStage, _ color: FlowerColor, _ g: GraphicsContext) {
        switch stage {
        case .sprout:     CommonParts.sprout(g)
        case .seedling:   CommonParts.seedling(g)
        case .vegetating: daisyRosette(g, size: 1)
        case .budding:
            daisyStems(g)
            daisyRosette(g, size: 0.75)
            for head in daisyHeads {
                g.dot(head, 3.6, Ink.bud)
                g.oval(pt(head.x, head.y - 2.2), width: 3.6, height: 3, color.petal)
            }
        default:
            daisyStems(g)
            daisyRosette(g, size: 0.75)
            let middle = color == .yellow ? Ink.seedBrown : Ink.flowerCenter
            for head in daisyHeads {
                g.flower(head, radius: 8.5, petals: 12, color.shade, center: nil, petalWidth: 0.5)
                g.flower(head, radius: 7.8, petals: 12, color.petal, center: middle, petalWidth: 0.36, rotation: 2)
            }
        }
    }

    private static func daisyRosette(_ g: GraphicsContext, size s: CGFloat) {
        let angles: [Double] = [-72, -48, -22, 0, 24, 50, 74]
        for (index, angle) in angles.enumerated() {
            let even = index.isMultiple(of: 2)
            g.leaf(pt(40, 74), angle: angle, length: (even ? 24 : 19) * s, width: 6 * s,
                   even ? Ink.leafDark : Ink.leafLight)
        }
    }

    private static func daisyStems(_ g: GraphicsContext) {
        g.line(pt(38, 72), pt(30, 50), pt(27, 32), width: 2)
        g.line(pt(40, 72), pt(41, 46), pt(41, 20), width: 2)
        g.line(pt(42, 72), pt(52, 50), pt(54, 30), width: 2)
    }

    // MARK: Sunflower

    static func sunflower(_ stage: GrowthStage, _ g: GraphicsContext) {
        let petal = Color(red: 1.00, green: 0.78, blue: 0.10)
        switch stage {
        case .sprout:   CommonParts.sprout(g, width: 4.6, length: 11)
        case .seedling: CommonParts.seedling(g, seedLeafWidth: 6)
        case .vegetating:
            sunflowerStalk(g, top: 22)
            g.leaf(pt(40, 23), angle: -28, length: 11, width: 5, Ink.leafLight)
            g.leaf(pt(40, 23), angle: 28, length: 11, width: 5, Ink.leafDark)
        case .budding:
            sunflowerStalk(g, top: 26)
            for index in 0..<10 {
                g.leaf(pt(40, 22), angle: Double(index) * 36, length: 9, width: 3.2, Ink.leafDark)
            }
            g.dot(pt(40, 22), 5.5, Ink.bud)
        case .flowering:
            sunflowerStalk(g, top: 30)
            g.flower(pt(40, 22), radius: 12, petals: 14, petal, center: nil, petalWidth: 0.5)
            g.dot(pt(40, 22), 7, Ink.seedBrown)
            for index in 0..<8 {
                g.dot(toward(pt(40, 22), Double(index) * 45, 4), 0.9, Ink.seedLight)
            }
        default:
            // Ripe: the heavy head full of seeds droops toward the ground.
            g.line(pt(40, 74), pt(39, 42), pt(44, 22), pt(52, 28), width: 3.4)
            sunflowerLeaves(g, lowerColor: Ink.dryLeaf)
            g.flower(pt(52, 35), radius: 12, petals: 12, Color(red: 0.86, green: 0.66, blue: 0.20),
                     center: nil, petalWidth: 0.4, rotation: 15)
            g.dot(pt(52, 35), 8.5, Ink.seedBrown)
            for index in 0..<10 {
                g.dot(toward(pt(52, 35), Double(index) * 36, 5), 1, Ink.seedLight)
            }
            g.dot(pt(52, 35), 1.4, Ink.seedLight)
        }
    }

    private static func sunflowerStalk(_ g: GraphicsContext, top: CGFloat) {
        g.line(pt(40, 74), pt(40, 50), pt(40, top), width: 3.4)
        sunflowerLeaves(g, lowerColor: Ink.leafLight)
    }

    private static func sunflowerLeaves(_ g: GraphicsContext, lowerColor: Color) {
        g.leaf(pt(40, 64), angle: -62, length: 18, width: 9, lowerColor, vein: true)
        g.leaf(pt(40, 55), angle: 62, length: 18, width: 9, Ink.leafDark, vein: true)
        g.leaf(pt(40, 45), angle: -58, length: 16, width: 8, Ink.leafDark, vein: true)
        g.leaf(pt(40, 37), angle: 55, length: 14, width: 7, Ink.leafLight, vein: true)
    }

    // MARK: Cactus

    private static let cactusGreen = Color(red: 0.33, green: 0.68, blue: 0.38)
    private static let cactusRib   = Color(red: 0.22, green: 0.50, blue: 0.27)

    static func cactus(_ stage: GrowthStage, _ color: FlowerColor, _ g: GraphicsContext) {
        switch stage {
        case .sprout:
            g.paint(Path(roundedRect: CGRect(x: 35, y: 63, width: 10, height: 11), cornerRadius: 5), cactusGreen)
            spines(g, [pt(37, 66), pt(43, 66), pt(40, 64)])
        case .seedling:
            // Chewed seedlings lose bites from the sides of the pad.
            let bites = [pt(33, 58), pt(47, 66), pt(33, 68), pt(47, 55)].prefix(g.bites + 1).map { biteShape($0, radius: 3.2) }
            g.chewed(Array(bites)) { g in
                g.paint(Path(roundedRect: CGRect(x: 33, y: 50, width: 14, height: 24), cornerRadius: 7), cactusGreen)
                ribs(g, xs: [37.5, 42.5], top: 54, bottom: 72)
                spines(g, [pt(35, 56), pt(45, 56), pt(35, 64), pt(45, 64), pt(40, 52)])
            }
        case .vegetating:
            cactusBody(g)
        case .budding:
            cactusBody(g)
            g.oval(pt(40, 19), width: 6, height: 8, Ink.bud)
            g.oval(pt(40, 17), width: 4, height: 4, color.petal)
        default:
            cactusBody(g)
            g.flower(pt(40, 19), radius: 7.5, petals: 8, color.petal, center: Ink.flowerCenter, petalWidth: 0.6)
            g.flower(pt(55, 28), radius: 5, petals: 7, color.petal, center: Ink.flowerCenter, petalWidth: 0.6)
        }
    }

    /// Bites out of the edges of the cactus (arms first), two more for each level of chewing.
    private static let cactusBites: [(CGPoint, CGFloat)] = [
        (pt(21, 45), 3.6), (pt(59, 37), 3.6), (pt(33, 62), 3.8),
        (pt(47, 30), 3.6), (pt(21, 53), 3.0), (pt(47, 52), 3.4),
        (pt(33, 36), 3.4), (pt(59, 45), 3.0), (pt(47, 66), 3.4),
    ]

    private static func cactusBody(_ g: GraphicsContext) {
        let bites = cactusBites.prefix(g.bites * 3).map { biteShape($0.0, radius: $0.1) }
        g.chewed(Array(bites)) { cactusBodyShape($0) }
    }

    private static func cactusBodyShape(_ g: GraphicsContext) {
        let parts = [
            CGRect(x: 33, y: 22, width: 14, height: 52),   // trunk
            CGRect(x: 21, y: 38, width: 8, height: 18),    // left arm
            CGRect(x: 21, y: 49, width: 16, height: 7),
            CGRect(x: 51, y: 30, width: 8, height: 18),    // right arm
            CGRect(x: 43, y: 41, width: 16, height: 7),
        ]
        for rect in parts {
            g.paint(Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) / 2), cactusGreen)
        }
        ribs(g, xs: [36.5, 40, 43.5], top: 28, bottom: 72)
        spines(g, [pt(34, 30), pt(46, 34), pt(34, 46), pt(46, 58), pt(34, 64), pt(22, 42), pt(58, 34)])
    }

    private static func ribs(_ g: GraphicsContext, xs: [CGFloat], top: CGFloat, bottom: CGFloat) {
        for x in xs { g.line(pt(x, top), pt(x, bottom), width: 1, color: cactusRib.opacity(0.7)) }
    }

    private static func spines(_ g: GraphicsContext, _ points: [CGPoint]) {
        for p in points {
            g.line(p, pt(p.x - 1.8, p.y - 1.8), width: 0.7, color: .white.opacity(0.9))
            g.line(p, pt(p.x + 1.8, p.y - 1.8), width: 0.7, color: .white.opacity(0.9))
        }
    }

    // MARK: Tulip

    private static let tulipLeaf      = Ink.blueGreen
    private static let tulipLeafLight = Ink.blueGreenLight

    static func tulip(_ stage: GrowthStage, _ color: FlowerColor, _ g: GraphicsContext) {
        switch stage {
        case .sprout:
            g.leaf(pt(38, 74), angle: -8, length: 12, width: 4, tulipLeaf)
            g.leaf(pt(42, 74), angle: 12, length: 10, width: 4, tulipLeafLight)
        case .seedling:
            tulipLeaves(g, scale: 0.65)
        case .vegetating:
            tulipLeaves(g, scale: 1)
            g.leaf(pt(40, 74), angle: 2, length: 40, width: 9, tulipLeafLight)
        case .budding:
            g.line(pt(40, 74), pt(41, 50), pt(40, 30))
            tulipLeaves(g, scale: 1)
            var bud = Path()
            bud.move(to: pt(40, 32))
            bud.addCurve(to: pt(40, 14), control1: pt(33, 30), control2: pt(35, 18))
            bud.addCurve(to: pt(40, 32), control1: pt(45, 18), control2: pt(47, 30))
            g.fill(bud, with: .linearGradient(Gradient(colors: [color.petal, Ink.bud]),
                                              startPoint: pt(40, 14), endPoint: pt(40, 32)))
        default:
            g.line(pt(40, 74), pt(41, 50), pt(40, 30))
            tulipLeaves(g, scale: 1)
            var back = Path()
            back.move(to: pt(40, 32))
            back.addCurve(to: pt(28, 13), control1: pt(30, 31), control2: pt(26, 22))
            back.addLine(to: pt(34, 19)); back.addLine(to: pt(40, 11))
            back.addLine(to: pt(46, 19)); back.addLine(to: pt(52, 13))
            back.addCurve(to: pt(40, 32), control1: pt(54, 22), control2: pt(50, 31))
            g.paint(back, color.shade)
            var front = Path()
            front.move(to: pt(40, 32))
            front.addCurve(to: pt(40, 15), control1: pt(33, 29), control2: pt(34, 19))
            front.addCurve(to: pt(40, 32), control1: pt(46, 19), control2: pt(47, 29))
            g.paint(front, color.petal)
        }
    }

    private static func tulipLeaves(_ g: GraphicsContext, scale s: CGFloat) {
        g.leaf(pt(39, 74), angle: -24, length: 34 * s, width: 10 * s, tulipLeaf)
        g.leaf(pt(41, 74), angle: 26, length: 30 * s, width: 10 * s, tulipLeafLight)
    }

    // MARK: Rose

    private static let roseStem = Color(red: 0.26, green: 0.46, blue: 0.20)
    private static let roseTips = [pt(26, 34), pt(40, 22), pt(55, 30)]

    static func rose(_ stage: GrowthStage, _ color: FlowerColor, _ g: GraphicsContext) {
        switch stage {
        case .sprout:   CommonParts.sprout(g)
        case .seedling: CommonParts.seedling(g)
        case .vegetating:
            roseBush(g)
            for tip in roseTips {
                g.leaf(tip, angle: -25, length: 8, width: 3.5, Ink.leafLight)
                g.leaf(tip, angle: 25, length: 8, width: 3.5, Ink.leafDark)
            }
        case .budding:
            roseBush(g)
            for tip in roseTips {
                g.leaf(pt(tip.x, tip.y + 4), angle: 0, length: 10, width: 5, color.petal)
                g.leaf(pt(tip.x, tip.y + 4), angle: 0, length: 6, width: 6, Ink.bud)
                g.leaf(pt(tip.x, tip.y + 2), angle: -40, length: 5, width: 1.6, Ink.leafDark)
                g.leaf(pt(tip.x, tip.y + 2), angle: 40, length: 5, width: 1.6, Ink.leafDark)
            }
        default:
            roseBush(g)
            for tip in roseTips { roseHead(g, tip, radius: 7.5, color) }
        }
    }

    private static func roseBush(_ g: GraphicsContext) {
        g.line(pt(40, 74), pt(40, 50), pt(40, 24), width: 3, color: roseStem)
        g.line(pt(40, 60), pt(30, 50), pt(26, 36), width: 2.4, color: roseStem)
        g.line(pt(40, 52), pt(52, 44), pt(55, 32), width: 2.4, color: roseStem)
        for (p, right) in [(pt(40, 68), true), (pt(40, 44), false), (pt(29, 46), true), (pt(52, 42), false)] {
            var thorn = Path()
            let side: CGFloat = right ? 1 : -1
            thorn.move(to: pt(p.x, p.y - 1.5))
            thorn.addLine(to: pt(p.x + side * 3, p.y - 2.5))
            thorn.addLine(to: pt(p.x, p.y + 1))
            g.paint(thorn, roseStem)
        }
        g.compoundLeaf(pt(40, 64), angle: -75, length: 16, Ink.leafDark)
        g.compoundLeaf(pt(40, 56), angle: 72, length: 16, Ink.leafLight)
        g.compoundLeaf(pt(30, 48), angle: -60, length: 13, Ink.leafLight)
        g.compoundLeaf(pt(51, 43), angle: 70, length: 13, Ink.leafDark)
        g.compoundLeaf(pt(40, 36), angle: -40, length: 12, Ink.leafDark)
    }

    private static func roseHead(_ g: GraphicsContext, _ c: CGPoint, radius r: CGFloat, _ color: FlowerColor) {
        g.dot(c, r, color.shade)
        for index in 0..<5 {
            g.dot(toward(c, Double(index) * 72 + 36, r * 0.42), r * 0.55, color.petal)
        }
        g.dot(c, r * 0.48, color.shade)
        var swirl = Path()
        swirl.addArc(center: c, radius: r * 0.28, startAngle: .degrees(0), endAngle: .degrees(270), clockwise: false)
        g.stroke(swirl, with: .color(color.petal), lineWidth: 1.2)
    }

    // MARK: Poppy

    static func poppy(_ stage: GrowthStage, _ color: FlowerColor, _ g: GraphicsContext) {
        switch stage {
        case .sprout:     CommonParts.sprout(g, leaf: Ink.blueGreen, width: 2.6)
        case .seedling:   poppyLeaves(g, size: 0.55)
        case .vegetating: poppyLeaves(g, size: 1)
        case .budding:
            // Poppy buds hang upside down until they open.
            g.line(pt(38, 72), pt(30, 30), pt(20, 24), pt(23, 32), width: 1.8, color: Ink.blueGreen)
            g.line(pt(42, 72), pt(48, 28), pt(58, 22), pt(55, 30), width: 1.8, color: Ink.blueGreen)
            poppyLeaves(g, size: 0.8)
            for (center, tilt) in [(pt(23, 36), 15.0), (pt(55, 34), -15.0)] {
                g.oval(center, width: 7, height: 10, angle: tilt, Ink.blueGreen)
                g.oval(pt(center.x, center.y + 3), width: 4, height: 3, angle: tilt, color.petal)
            }
        default:
            g.line(pt(38, 72), pt(30, 46), pt(28, 30), width: 1.8, color: Ink.blueGreen)
            g.line(pt(42, 72), pt(50, 46), pt(53, 24), width: 1.8, color: Ink.blueGreen)
            poppyLeaves(g, size: 0.8)
            poppyHead(g, pt(28, 26), radius: 10, color)
            poppyHead(g, pt(53, 20), radius: 11, color)
        }
    }

    private static func poppyLeaves(_ g: GraphicsContext, size s: CGFloat) {
        let angles: [Double] = [-65, -35, -10, 15, 40, 68]
        for (index, angle) in angles.enumerated() {
            let even = index.isMultiple(of: 2)
            let length = (even ? 21 : 17) * s
            g.leaf(pt(40, 74), angle: angle, length: length, width: 5 * s, even ? Ink.blueGreen : Ink.blueGreenLight)
            // little side lobes make the leaves look frilly
            let lobe = toward(pt(40, 74), angle, length * 0.55)
            g.leaf(lobe, angle: angle - 45, length: 5 * s, width: 2 * s, even ? Ink.blueGreen : Ink.blueGreenLight)
            g.leaf(lobe, angle: angle + 45, length: 5 * s, width: 2 * s, even ? Ink.blueGreen : Ink.blueGreenLight)
        }
    }

    private static func poppyHead(_ g: GraphicsContext, _ c: CGPoint, radius r: CGFloat, _ color: FlowerColor) {
        g.dot(pt(c.x - r * 0.42, c.y - r * 0.22), r * 0.6, color.shade)
        g.dot(pt(c.x + r * 0.42, c.y - r * 0.22), r * 0.6, color.shade)
        g.dot(pt(c.x - r * 0.36, c.y + r * 0.16), r * 0.6, color.petal)
        g.dot(pt(c.x + r * 0.36, c.y + r * 0.16), r * 0.6, color.petal)
        g.dot(c, r * 0.28, Color(red: 0.15, green: 0.12, blue: 0.12))
        g.dot(c, r * 0.12, Color(red: 0.55, green: 0.60, blue: 0.45))
    }

    // MARK: Orchid

    private static let orchidLeaf      = Color(red: 0.20, green: 0.50, blue: 0.26)
    private static let orchidLeafLight = Color(red: 0.30, green: 0.62, blue: 0.32)
    private static let spike = (start: pt(42, 68), bend: pt(36, 10), end: pt(66, 26))

    static func orchid(_ stage: GrowthStage, _ color: FlowerColor, _ g: GraphicsContext) {
        switch stage {
        case .sprout:
            g.leaf(pt(40, 73), angle: -70, length: 9, width: 5, orchidLeaf)
            g.leaf(pt(40, 73), angle: 70, length: 8, width: 5, orchidLeafLight)
        case .seedling:
            orchidLeaves(g, size: 0.6)
        case .vegetating:
            orchidLeaves(g, size: 1)
        case .budding:
            orchidSpike(g)
            orchidLeaves(g, size: 1)
            for (t, size) in [(0.55, 5.5), (0.7, 5.0), (0.84, 4.4), (0.97, 3.6)] as [(CGFloat, CGFloat)] {
                let p = curvePoint(spike.start, spike.bend, spike.end, t)
                g.oval(p, width: size, height: size * 1.3, angle: 20, t < 0.8 ? color.petal : Ink.bud)
            }
        default:
            orchidSpike(g)
            orchidLeaves(g, size: 1)
            for (t, size) in [(0.5, 8.5), (0.73, 8.0), (0.95, 7.0)] as [(CGFloat, CGFloat)] {
                orchidFlower(g, curvePoint(spike.start, spike.bend, spike.end, t), radius: size, color)
            }
        }
    }

    private static func orchidLeaves(_ g: GraphicsContext, size s: CGFloat) {
        g.line(pt(38, 72), pt(30, 75), pt(22, 72), width: 1.6, color: Ink.root)
        g.line(pt(42, 72), pt(52, 76), pt(58, 73), width: 1.6, color: Ink.root)
        g.leaf(pt(40, 72), angle: -58, length: 22 * s, width: 9 * s, orchidLeafLight, vein: true)
        g.leaf(pt(40, 72), angle: 60, length: 22 * s, width: 9 * s, orchidLeaf, vein: true)
        g.leaf(pt(40, 73), angle: -80, length: 20 * s, width: 8 * s, orchidLeaf, vein: true)
        g.leaf(pt(40, 73), angle: 80, length: 20 * s, width: 8 * s, orchidLeafLight, vein: true)
    }

    private static func orchidSpike(_ g: GraphicsContext) {
        g.line(spike.start, spike.bend, spike.end, width: 1.6, color: Ink.stem)
    }

    private static func orchidFlower(_ g: GraphicsContext, _ c: CGPoint, radius r: CGFloat, _ color: FlowerColor) {
        g.oval(pt(c.x, c.y - r * 0.55), width: r * 0.55, height: r * 1.0, color.shade)
        g.oval(toward(c, 140, r * 0.55), width: r * 0.5, height: r * 1.0, angle: 140, color.shade)
        g.oval(toward(c, 220, r * 0.55), width: r * 0.5, height: r * 1.0, angle: 220, color.shade)
        g.dot(pt(c.x - r * 0.48, c.y - r * 0.05), r * 0.52, color.petal)
        g.dot(pt(c.x + r * 0.48, c.y - r * 0.05), r * 0.52, color.petal)
        g.oval(pt(c.x, c.y + r * 0.38), width: r * 0.5, height: r * 0.55, color.shade)
        g.dot(pt(c.x, c.y - r * 0.05), r * 0.16, Ink.flowerCenter)
    }
}
