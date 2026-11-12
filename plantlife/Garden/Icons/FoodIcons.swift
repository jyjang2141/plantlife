//
//  FoodIcons.swift
//  plantlife
//
//  Corn, tomato, cucumber, pumpkin and strawberry at each growth stage.
//

import SwiftUI

enum FoodIcons {

    // MARK: Corn

    private static let cornStalk = Color(red: 0.45, green: 0.68, blue: 0.30)
    private static let tassel    = Color(red: 0.85, green: 0.72, blue: 0.35)
    private static let husk      = Color(red: 0.62, green: 0.78, blue: 0.36)
    private static let kernel    = Color(red: 1.00, green: 0.83, blue: 0.25)
    private static let silk      = Color(red: 0.80, green: 0.55, blue: 0.30)

    static func corn(_ stage: GrowthStage, _ g: GraphicsContext) {
        switch stage {
        case .sprout:
            g.blade(from: pt(40, 74), to: pt(38, 60), bend: pt(40, 66), width: 3, Ink.sprout)
            g.blade(from: pt(40, 74), to: pt(46, 64), bend: pt(43, 68), width: 2.4, Ink.leafLight)
        case .seedling:
            g.line(pt(40, 74), pt(40, 58), width: 3, color: cornStalk)
            g.blade(from: pt(40, 66), to: pt(26, 62), bend: pt(31, 57), width: 4, Ink.leafDark)
            g.blade(from: pt(40, 61), to: pt(54, 56), bend: pt(49, 52), width: 4, Ink.leafLight)
            g.blade(from: pt(40, 59), to: pt(38, 44), bend: pt(41, 50), width: 3.5, Ink.leafDark)
        case .vegetating:
            cornPlant(g, top: 14)
        case .budding:
            cornPlant(g, top: 18)
            cornTassel(g, top: 18, color: Ink.bud)
        case .flowering:
            cornPlant(g, top: 18)
            cornTassel(g, top: 18, color: tassel)
            g.oval(pt(45, 47), width: 5, height: 12, angle: 20, husk)
            g.line(pt(47, 41), pt(50, 37), pt(53, 38), width: 0.9, color: silk)
            g.line(pt(47, 41), pt(48, 36), pt(51, 34), width: 0.9, color: silk)
        default:
            cornPlant(g, top: 18, dry: true)
            cornTassel(g, top: 18, color: Ink.seedLight)
            // Ripe ear with the husk peeled back.
            g.leaf(pt(45, 56), angle: -10, length: 16, width: 5, husk)
            g.leaf(pt(45, 56), angle: 45, length: 15, width: 5, husk)
            g.oval(pt(49, 45), width: 9, height: 19, angle: 18, kernel)
            for step in -3...3 {
                let p = toward(pt(49, 45), 18, CGFloat(step) * 2.4)
                g.line(toward(p, 108, 3.4), toward(p, -72, 3.4), width: 0.6, color: Ink.blossomCenter.opacity(0.8))
            }
            g.line(pt(52, 36), pt(55, 32), pt(58, 33), width: 0.9, color: silk)
        }
    }

    private static func cornPlant(_ g: GraphicsContext, top: CGFloat, dry: Bool = false) {
        g.blade(from: pt(40, 66), to: pt(15, 64), bend: pt(24, 50), width: 4.5, dry ? Ink.dryLeaf : Ink.leafDark)
        g.blade(from: pt(40, 58), to: pt(65, 58), bend: pt(56, 44), width: 4.5, Ink.leafLight)
        g.blade(from: pt(40, 48), to: pt(17, 46), bend: pt(24, 34), width: 4, Ink.leafLight)
        g.blade(from: pt(40, 40), to: pt(63, 40), bend: pt(56, 28), width: 4, dry ? Ink.dryLeaf : Ink.leafDark)
        g.blade(from: pt(40, 31), to: pt(26, 24), bend: pt(30, 20), width: 3.5, Ink.leafDark)
        g.blade(from: pt(40, 27), to: pt(53, 20), bend: pt(48, 17), width: 3.5, Ink.leafLight)
        g.line(pt(40, 74), pt(40, top), width: 4, color: cornStalk)
    }

    private static func cornTassel(_ g: GraphicsContext, top: CGFloat, color: Color) {
        g.line(pt(40, top + 2), pt(40, top - 10), width: 1.6, color: color)
        g.line(pt(40, top), pt(35, top - 5), pt(31, top - 3), width: 1.2, color: color)
        g.line(pt(40, top), pt(45, top - 5), pt(49, top - 3), width: 1.2, color: color)
        g.line(pt(40, top - 3), pt(37, top - 9), pt(34, top - 9), width: 1.1, color: color)
        g.line(pt(40, top - 3), pt(43, top - 9), pt(46, top - 9), width: 1.1, color: color)
    }

    // MARK: Tomato

    private static let tomatoRed   = Color(red: 0.90, green: 0.22, blue: 0.18)
    private static let tomatoGreen = Color(red: 0.55, green: 0.78, blue: 0.30)
    private static let trusses     = [pt(52, 40), pt(27, 50), pt(26, 30)]

    static func tomato(_ stage: GrowthStage, _ g: GraphicsContext) {
        switch stage {
        case .sprout:     CommonParts.sprout(g, width: 3)
        case .seedling:   CommonParts.seedling(g)
        case .vegetating: tomatoVine(g)
        case .budding:
            tomatoVine(g)
            for spot in trusses {
                for dx in [-2.5, 0, 2.5] as [CGFloat] {
                    g.line(pt(spot.x, spot.y - 3), pt(spot.x + dx, spot.y + 1), width: 1)
                    g.oval(pt(spot.x + dx, spot.y + 2), width: 3.2, height: 4, Ink.bud)
                }
            }
        case .flowering:
            tomatoVine(g)
            for spot in trusses {
                g.flower(pt(spot.x - 3, spot.y + 1), radius: 3.6, petals: 5, Ink.blossom, center: Ink.blossomCenter)
                g.flower(pt(spot.x + 3, spot.y + 3), radius: 3.2, petals: 5, Ink.blossom, center: Ink.blossomCenter)
            }
        default:
            tomatoVine(g)
            tomatoFruit(g, pt(52, 44), radius: 6.5, tomatoRed)
            tomatoFruit(g, pt(27, 54), radius: 6, tomatoRed)
            tomatoFruit(g, pt(26, 33), radius: 5, tomatoGreen)
        }
    }

    private static func tomatoVine(_ g: GraphicsContext) {
        g.line(pt(40, 74), pt(37, 48), pt(40, 20), width: 3.4)
        g.compoundLeaf(pt(39, 64), angle: -70, length: 22, Ink.leafDark)
        g.compoundLeaf(pt(39, 54), angle: 68, length: 22, Ink.leafLight)
        g.compoundLeaf(pt(38, 43), angle: -62, length: 20, Ink.leafLight)
        g.compoundLeaf(pt(39, 33), angle: 60, length: 18, Ink.leafDark)
        g.compoundLeaf(pt(40, 22), angle: -10, length: 14, Ink.leafLight)
    }

    private static func tomatoFruit(_ g: GraphicsContext, _ c: CGPoint, radius r: CGFloat, _ color: Color) {
        g.oval(c, width: r * 2, height: r * 1.8, color)
        g.oval(pt(c.x - r * 0.35, c.y - r * 0.45), width: r * 0.45, height: r * 0.3, .white.opacity(0.45))
        for angle in stride(from: -80.0, through: 80.0, by: 40.0) {
            g.leaf(pt(c.x, c.y - r * 0.8), angle: angle, length: r * 0.6, width: r * 0.2, Ink.leafDark)
        }
    }

    // MARK: Cucumber

    private static let cucumberGreen = Color(red: 0.20, green: 0.48, blue: 0.22)
    private static let cucumberBumps = Color(red: 0.45, green: 0.68, blue: 0.36)
    private static let vineSpots     = [pt(53, 43), pt(42, 30), pt(53, 21)]

    static func cucumber(_ stage: GrowthStage, _ g: GraphicsContext) {
        switch stage {
        case .sprout:     CommonParts.sprout(g, width: 5, length: 9)
        case .seedling:   CommonParts.vineSeedling(g)
        case .vegetating: cucumberVine(g)
        case .budding:
            cucumberVine(g)
            for spot in vineSpots { g.oval(spot, width: 3, height: 4.5, Ink.bud) }
        case .flowering:
            cucumberVine(g)
            for spot in vineSpots {
                g.flower(spot, radius: 4.2, petals: 5, Ink.blossom, center: Ink.blossomCenter, petalWidth: 1)
            }
        default:
            cucumberVine(g)
            for (center, height, tilt) in [(pt(52, 50), 19.0, -8.0), (pt(38, 38), 14.0, 10.0)] as [(CGPoint, CGFloat, Double)] {
                g.oval(center, width: height * 0.36, height: height, angle: tilt, cucumberGreen)
                for step in -2...2 {
                    g.dot(toward(center, tilt, CGFloat(step) * height * 0.17), 0.7, cucumberBumps)
                }
                g.dot(toward(center, tilt + 180, height * 0.5), 1.4, Ink.blossom)
            }
        }
    }

    private static func cucumberVine(_ g: GraphicsContext) {
        g.paint(Path(roundedRect: CGRect(x: 46, y: 12, width: 3, height: 63), cornerRadius: 1.5), Ink.stake)
        g.line(pt(40, 74), pt(58, 58), pt(34, 38), pt(48, 16), width: 2.2)
        g.line(pt(46, 62), pt(36, 60), width: 1.4)
        g.lobedLeaf(pt(31, 57), radius: 9, Ink.leafDark)
        g.line(pt(48, 52), pt(58, 48), width: 1.4)
        g.lobedLeaf(pt(61, 45), radius: 8.5, Ink.leafLight)
        g.line(pt(41, 40), pt(32, 36), width: 1.4)
        g.lobedLeaf(pt(29, 33), radius: 7.5, Ink.leafLight)
        g.line(pt(45, 26), pt(55, 28), width: 1.4)
        g.lobedLeaf(pt(58, 26), radius: 6.5, Ink.leafDark)
        g.tendril(pt(50, 58), right: true)
        g.tendril(pt(43, 34), right: false)
        g.tendril(pt(48, 18), right: true)
    }

    // MARK: Pumpkin

    private static let pumpkinOrange = Color(red: 0.96, green: 0.56, blue: 0.12)
    private static let pumpkinLight  = Color(red: 1.00, green: 0.66, blue: 0.22)
    private static let pumpkinRib    = Color(red: 0.84, green: 0.42, blue: 0.08)
    private static let pumpkinFlower = Color(red: 1.00, green: 0.72, blue: 0.12)

    static func pumpkin(_ stage: GrowthStage, _ g: GraphicsContext) {
        switch stage {
        case .sprout:     CommonParts.sprout(g, width: 5.5, length: 10)
        case .seedling:   CommonParts.vineSeedling(g)
        case .vegetating: pumpkinVine(g)
        case .budding:
            pumpkinVine(g)
            g.oval(pt(31, 63), width: 3.5, height: 5, Ink.bud)
            g.oval(pt(50, 62), width: 3.5, height: 5, Ink.bud)
        case .flowering:
            pumpkinVine(g)
            g.flower(pt(31, 60), radius: 6.5, petals: 5, pumpkinFlower, center: Ink.blossomCenter, petalWidth: 1.1)
            g.flower(pt(51, 58), radius: 6.5, petals: 5, pumpkinFlower, center: Ink.blossomCenter, petalWidth: 1.1)
        default:
            pumpkinVine(g, dry: true)
            g.oval(pt(40, 62), width: 34, height: 22, pumpkinRib)
            g.oval(pt(32, 62), width: 15, height: 21, pumpkinOrange)
            g.oval(pt(48, 62), width: 15, height: 21, pumpkinOrange)
            g.oval(pt(40, 62), width: 12, height: 22, pumpkinLight)
            g.paint(Path(roundedRect: CGRect(x: 38, y: 47, width: 4, height: 7), cornerRadius: 1.5), Ink.bark)
            g.tendril(pt(42, 49), right: true)
        }
    }

    private static func pumpkinVine(_ g: GraphicsContext, dry: Bool = false) {
        g.line(pt(8, 72), pt(40, 66), pt(72, 71), width: 2.4)
        g.line(pt(21, 69), pt(21, 52), width: 1.8)
        g.line(pt(40, 67), pt(40, 42), width: 1.8)
        g.line(pt(59, 69), pt(59, 54), width: 1.8)
        g.lobedLeaf(pt(21, 48), radius: 10, dry ? Ink.dryLeaf : Ink.leafDark)
        g.lobedLeaf(pt(59, 50), radius: 10, Ink.leafDark)
        g.lobedLeaf(pt(40, 38), radius: 11, Ink.leafLight)
        g.tendril(pt(29, 68), right: false)
        g.tendril(pt(52, 68), right: true)
    }

    // MARK: Strawberry

    private static let berryRed    = Color(red: 0.92, green: 0.18, blue: 0.22)
    private static let berryUnripe = Color(red: 0.86, green: 0.93, blue: 0.70)
    private static let berrySeed   = Color(red: 1.00, green: 0.88, blue: 0.40)

    static func strawberry(_ stage: GrowthStage, _ g: GraphicsContext) {
        switch stage {
        case .sprout:     CommonParts.sprout(g, width: 3.4, length: 8)
        case .seedling:   strawberryClump(g, size: 0.55)
        case .vegetating: strawberryClump(g, size: 1)
        case .budding:
            strawberryStalks(g)
            strawberryClump(g, size: 0.9)
            for spot in [pt(20, 57), pt(60, 55), pt(48, 61)] { g.dot(spot, 2.4, Ink.bud) }
        case .flowering:
            strawberryStalks(g)
            strawberryClump(g, size: 0.9)
            for spot in [pt(20, 56), pt(60, 54), pt(48, 60)] {
                g.flower(spot, radius: 5, petals: 5, FlowerColor.white.shade, center: nil, petalWidth: 1.05)
                g.flower(spot, radius: 4.4, petals: 5, FlowerColor.white.petal, center: Ink.flowerCenter, petalWidth: 0.95)
            }
        default:
            strawberryStalks(g)
            strawberryClump(g, size: 0.9)
            strawberryFruit(g, pt(20, 62), size: 6, berryRed)
            strawberryFruit(g, pt(60, 60), size: 6.5, berryRed)
            strawberryFruit(g, pt(48, 65), size: 4.5, berryUnripe)
        }
    }

    private static func strawberryClump(_ g: GraphicsContext, size s: CGFloat) {
        let stalks: [(Double, CGFloat, Color)] = [
            (-55, 22, Ink.leafDark), (-25, 26, Ink.leafLight), (5, 28, Ink.leafDark),
            (35, 24, Ink.leafLight), (62, 20, Ink.leafDark),
        ]
        for (angle, length, color) in stalks {
            g.trifoliate(pt(40, 74), angle: angle, size: length * s, color)
        }
    }

    private static func strawberryStalks(_ g: GraphicsContext) {
        g.line(pt(40, 72), pt(24, 46), pt(20, 56), width: 1.2)
        g.line(pt(40, 72), pt(58, 44), pt(60, 54), width: 1.2)
        g.line(pt(40, 72), pt(48, 56), pt(48, 60), width: 1.2)
    }

    private static func strawberryFruit(_ g: GraphicsContext, _ c: CGPoint, size s: CGFloat, _ color: Color) {
        var berry = Path()
        berry.move(to: pt(c.x, c.y + s))
        berry.addCurve(to: pt(c.x, c.y - s * 0.55), control1: pt(c.x - s * 1.2, c.y + s * 0.1),
                       control2: pt(c.x - s * 0.9, c.y - s * 0.7))
        berry.addCurve(to: pt(c.x, c.y + s), control1: pt(c.x + s * 0.9, c.y - s * 0.7),
                       control2: pt(c.x + s * 1.2, c.y + s * 0.1))
        g.paint(berry, color)
        for offset in [pt(-0.35, -0.1), pt(0.35, -0.1), pt(0, 0.25), pt(-0.25, 0.5), pt(0.25, 0.5), pt(0, -0.3)] {
            g.dot(pt(c.x + offset.x * s, c.y + offset.y * s), s * 0.08, berrySeed)
        }
        for angle in stride(from: -70.0, through: 70.0, by: 35.0) {
            g.leaf(pt(c.x, c.y - s * 0.5), angle: angle, length: s * 0.6, width: s * 0.2, Ink.leafDark)
        }
    }
}
