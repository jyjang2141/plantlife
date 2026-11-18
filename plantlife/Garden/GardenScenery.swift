import SwiftUI

/// Scenery is drawn in local illustration coordinates: rotating the device never stretches it.
struct GardenScenery: View {
    let bed: GardenPlot
    var active = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !active || reduceMotion || scenePhase != .active)) { timeline in
            Canvas { context, size in
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let cycle = time.truncatingRemainder(dividingBy: 8)
                let gust = cycle < 1.8 ? sin(cycle / 1.8 * .pi) : 0
                let ground = bed == .desert ? Color(red: 0.93, green: 0.83, blue: 0.67)
                    : bed == .sunny ? Color(red: 0.83, green: 0.90, blue: 0.75)
                    : Color(red: 0.73, green: 0.81, blue: 0.74)
                fill(&context, Path(CGRect(origin: .zero, size: size)), ground)

                // Broad, very quiet color patches give the ground depth without painted texture.
                for index in 0..<9 {
                    let x = CGFloat((index * 29 + 7) % 100) / 100 * size.width
                    let y = CGFloat((index * 17 + 13) % 100) / 100 * size.height
                    oval(&context, CGRect(x: x - 45, y: y - 16, width: 120, height: 43),
                         (bed == .desert ? Color.white : Color.green).opacity(0.035))
                }
                let unit = min(size.width / 750, size.height / 560)
                let details: [CGPoint] = [
                    CGPoint(x: 0.11, y: 0.22), CGPoint(x: 0.27, y: 0.17), CGPoint(x: 0.44, y: 0.21),
                    CGPoint(x: 0.69, y: 0.19), CGPoint(x: 0.89, y: 0.29), CGPoint(x: 0.06, y: 0.38),
                    CGPoint(x: 0.28, y: 0.42), CGPoint(x: 0.51, y: 0.33), CGPoint(x: 0.72, y: 0.37),
                    CGPoint(x: 0.09, y: 0.62), CGPoint(x: 0.31, y: 0.66), CGPoint(x: 0.53, y: 0.47),
                    CGPoint(x: 0.69, y: 0.68), CGPoint(x: 0.13, y: 0.86), CGPoint(x: 0.33, y: 0.91),
                    CGPoint(x: 0.55, y: 0.88), CGPoint(x: 0.79, y: 0.87), CGPoint(x: 0.94, y: 0.79),
                    CGPoint(x: 0.06, y: 0.76), CGPoint(x: 0.91, y: 0.18), CGPoint(x: 0.57, y: 0.74),
                    CGPoint(x: 0.93, y: 0.65), CGPoint(x: 0.46, y: 0.93), CGPoint(x: 0.76, y: 0.28)
                ]
                for (index, normalized) in details.enumerated() {
                    let p = CGPoint(x: normalized.x * size.width, y: normalized.y * size.height)
                    if index.isMultiple(of: 4) {
                        var stoneContext = context
                        stoneContext.translateBy(x: p.x, y: p.y)
                        stoneContext.scaleBy(x: unit, y: unit)
                        stone(&stoneContext, x: 0, y: 0, size: 9 + CGFloat(index % 3) * 3)
                        stone(&stoneContext, x: 16, y: 6, size: 6)
                    } else if bed != .desert {
                        grass(&context, at: p, scale: unit, bend: gust * (index.isMultiple(of: 2) ? 6 : 9), muted: bed == .sunny)
                    } else {
                        var sand = Path()
                        sand.move(to: p)
                        sand.addCurve(to: CGPoint(x: p.x + 35 * unit, y: p.y + 3 * unit),
                                      control1: CGPoint(x: p.x + 10 * unit, y: p.y - 7 * unit),
                                      control2: CGPoint(x: p.x + 26 * unit, y: p.y + 3 * unit))
                        context.stroke(sand, with: .color(.brown.opacity(0.10)),
                                       style: StrokeStyle(lineWidth: 4 * unit, lineCap: .round))
                        if index.isMultiple(of: 3) {
                            desertWeed(&context, at: p, scale: unit * 0.75, bend: gust * 4)
                        }
                    }
                }
                switch bed {
                case .sunny:
                    pond(&context, rect: GardenLayout.sceneryRect(bed, size: size), time: time, gust: gust)
                    shrub(&context, origin: CGPoint(x: 6, y: size.height * 0.97), scale: unit * 1.35)
                    shrub(&context, origin: CGPoint(x: size.width - 6, y: size.height * 0.98), scale: unit * 1.40)
                    shrub(&context, origin: CGPoint(x: size.width * 0.64, y: -18), scale: unit * 0.75)
                case .shady:
                    // Shadows are ground decoration; the leaf canopy is foreground at the edges.
                    canopy(&context, size: size, shadows: true, gust: gust)
                    stump(&context, rect: GardenLayout.sceneryRect(bed, size: size), gust: gust, time: time)
                    canopy(&context, size: size, shadows: false, gust: gust)
                case .desert:
                    desertDetails(&context, size: size, unit: unit, gust: gust)
                    log(&context, rect: GardenLayout.sceneryRect(bed, size: size))
                    if gust > 0 {
                        for index in 0..<32 {
                            let phase = (cycle / 1.8 + Double(index) * 0.032).truncatingRemainder(dividingBy: 1)
                            let x = (phase * 1.3 - 0.15) * size.width
                            let y = (0.22 + Double((index * 17) % 59) / 100) * size.height - sin(phase * .pi) * 12
                            oval(&context, CGRect(x: x, y: y, width: (3 + Double(index % 3)) * unit, height: 2 * unit),
                                 Color.brown.opacity(gust * 0.23))
                        }
                    }
                }
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func fill(_ context: inout GraphicsContext, _ path: Path, _ color: Color) {
        context.fill(path, with: .color(color))
    }

    private func oval(_ context: inout GraphicsContext, _ rect: CGRect, _ color: Color) {
        fill(&context, Path(ellipseIn: rect), color)
    }

    private func line(_ context: inout GraphicsContext, _ points: [CGPoint], _ color: Color, width: CGFloat = 2) {
        guard let first = points.first else { return }
        var path = Path()
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private func leaf(_ context: inout GraphicsContext, x: CGFloat, y: CGFloat, length: CGFloat,
                      angle: Double, color: Color, vein: Bool = false) {
        var local = context
        local.translateBy(x: x, y: y)
        local.rotate(by: .degrees(angle))
        fill(&local, leafOutline(length: length), color)
        if vein {
            line(&local, [.zero, CGPoint(x: 0, y: -length * 0.88)], .white.opacity(0.16), width: 1.5)
        }
    }

    private func leafOutline(length: CGFloat) -> Path {
        var path = Path()
        path.move(to: .zero)
        path.addQuadCurve(to: CGPoint(x: 0, y: -length),
                          control: CGPoint(x: -length * 0.55, y: -length * 0.64))
        path.addQuadCurve(to: .zero, control: CGPoint(x: length * 0.48, y: -length * 0.55))
        path.closeSubpath()
        return path
    }

    private func stone(_ context: inout GraphicsContext, x: CGFloat, y: CGFloat, size: CGFloat) {
        oval(&context, CGRect(x: x - size * 0.6, y: y + 3, width: size * 1.4, height: size * 0.65), .black.opacity(0.045))
        oval(&context, CGRect(x: x - size * 0.6, y: y - size * 0.3, width: size * 1.3, height: size * 0.75),
             Color(red: 0.62, green: 0.63, blue: 0.57))
        oval(&context, CGRect(x: x - size * 0.42, y: y - size * 0.25, width: size * 0.8, height: size * 0.35),
             Color(red: 0.75, green: 0.75, blue: 0.68))
    }

    private func grass(_ context: inout GraphicsContext, at point: CGPoint, scale: CGFloat, bend: Double, muted: Bool = false) {
        var local = context
        local.translateBy(x: point.x, y: point.y)
        local.scaleBy(x: scale, y: scale)
        for blade in -1...1 {
            leaf(&local, x: CGFloat(blade * 2), y: 0, length: CGFloat(18 - abs(blade) * 3),
                 angle: Double(blade * 25) + bend,
                 color: muted ? Color(red: 0.65, green: 0.77, blue: 0.54).opacity(0.65)
                    : Color(red: 0.40 + Double(blade + 1) * 0.035, green: 0.64, blue: 0.34))
        }
    }

    private func shrub(_ context: inout GraphicsContext, origin: CGPoint, scale: CGFloat) {
        var local = context
        local.translateBy(x: origin.x, y: origin.y)
        local.scaleBy(x: scale, y: scale)
        // Back foliage adds volume; the front lobes conceal their joins.
        for index in 0..<5 {
            oval(&local, CGRect(x: CGFloat(index - 2) * 25 - 31, y: -38 - CGFloat(2 - abs(index - 2)) * 17,
                               width: 62, height: 62),
                 Color(red: 0.35, green: 0.56, blue: 0.29))
        }
        for index in 0..<7 {
            let x = CGFloat(index - 3) * 20
            let y = -CGFloat(3 - abs(index - 3)) * 14
            oval(&local, CGRect(x: x - 27, y: y - 30, width: 54, height: 54),
                 Color(red: 0.39 + Double(index % 3) * 0.025, green: 0.62 + Double(index % 2) * 0.025, blue: 0.31))
        }
    }

    private func pond(_ context: inout GraphicsContext, rect: CGRect, time: Double, gust: Double) {
        // One local 300 x 162 illustration retains its horizontal proportions.
        var local = context
        local.translateBy(x: rect.minX, y: rect.minY)
        local.scaleBy(x: rect.width / 300, y: rect.height / 162)
        var shore = Path()
        shore.move(to: CGPoint(x: 15, y: 57))
        shore.addCurve(to: CGPoint(x: 115, y: 5), control1: CGPoint(x: 25, y: 16), control2: CGPoint(x: 68, y: 12))
        shore.addCurve(to: CGPoint(x: 286, y: 37), control1: CGPoint(x: 184, y: -6), control2: CGPoint(x: 256, y: 5))
        shore.addCurve(to: CGPoint(x: 274, y: 136), control1: CGPoint(x: 335, y: 76), control2: CGPoint(x: 302, y: 119))
        shore.addCurve(to: CGPoint(x: 71, y: 150), control1: CGPoint(x: 218, y: 177), control2: CGPoint(x: 135, y: 164))
        shore.addCurve(to: CGPoint(x: 15, y: 57), control1: CGPoint(x: 10, y: 148), control2: CGPoint(x: -8, y: 98))
        fill(&local, shore, Color(red: 0.51, green: 0.69, blue: 0.40))
        var water = local
        water.translateBy(x: 150, y: 81)
        water.scaleBy(x: 0.94, y: 0.88)
        water.translateBy(x: -150, y: -81)
        fill(&water, shore, Color(red: 0.37, green: 0.72, blue: 0.86))
        for i in 0..<4 {
            let x = CGFloat(45 + i * 60)
            let y = CGFloat(48 + (i % 2) * 65)
            var ripple = Path()
            ripple.move(to: CGPoint(x: x, y: y))
            ripple.addQuadCurve(to: CGPoint(x: x + 28, y: y), control: CGPoint(x: x + 14, y: y + 9))
            water.stroke(ripple, with: .color(.white.opacity(0.55)),
                         style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        for point in [CGPoint(x: 28, y: 35), CGPoint(x: 72, y: 13), CGPoint(x: 51, y: 145), CGPoint(x: 253, y: 147)] {
            grass(&local, at: point, scale: 1.6, bend: gust * 5, muted: true)
        }
        stone(&local, x: 18, y: 59, size: 19)
        stone(&local, x: 42, y: 26, size: 12)
        stone(&local, x: 76, y: 154, size: 15)
        stone(&local, x: 95, y: 157, size: 9)
        // Duck swims inside the central part of the water rather than over the shore.
        var duck = local
        duck.translateBy(x: 145 + sin(time * 0.25) * 33, y: 85 + cos(time * 0.32) * 16)
        duck.scaleBy(x: 1, y: 1.60 / 1.85)
        oval(&duck, CGRect(x: -26, y: 12, width: 53, height: 9), .white.opacity(0.60))
        oval(&duck, CGRect(x: -22, y: -3, width: 46, height: 26), Color(red: 1, green: 0.82, blue: 0.12))
        leaf(&duck, x: 16, y: 6, length: 17, angle: 55, color: Color(red: 1, green: 0.84, blue: 0.14))
        oval(&duck, CGRect(x: -21, y: -22, width: 27, height: 27), Color(red: 1, green: 0.86, blue: 0.18))
        oval(&duck, CGRect(x: -29, y: -7, width: 14, height: 6), .orange)
        oval(&duck, CGRect(x: -15, y: -12, width: 3.5, height: 3.5), Color(red: 0.26, green: 0.22, blue: 0.14))
        oval(&duck, CGRect(x: -1, y: 4, width: 19, height: 12), Color(red: 0.98, green: 0.73, blue: 0.08))
    }

    private func stump(_ context: inout GraphicsContext, rect: CGRect, gust: Double, time: Double) {
        var local = context
        local.translateBy(x: rect.minX, y: rect.minY)
        local.scaleBy(x: rect.width / 200, y: rect.height / 180)
        oval(&local, CGRect(x: 2, y: 145, width: 195, height: 24), .black.opacity(0.10))
        // Flared roots and an irregular silhouette, with a darker side face.
        var trunk = Path()
        trunk.move(to: CGPoint(x: 45, y: 27))
        trunk.addLine(to: CGPoint(x: 151, y: 23))
        trunk.addCurve(to: CGPoint(x: 184, y: 149), control1: CGPoint(x: 150, y: 83), control2: CGPoint(x: 166, y: 128))
        trunk.addLine(to: CGPoint(x: 200, y: 164))
        trunk.addLine(to: CGPoint(x: 159, y: 159))
        trunk.addLine(to: CGPoint(x: 148, y: 171))
        trunk.addLine(to: CGPoint(x: 66, y: 162))
        trunk.addLine(to: CGPoint(x: 30, y: 171))
        trunk.addLine(to: CGPoint(x: 34, y: 153))
        trunk.addLine(to: CGPoint(x: 4, y: 158))
        trunk.addCurve(to: CGPoint(x: 45, y: 27), control1: CGPoint(x: 36, y: 124), control2: CGPoint(x: 41, y: 73))
        trunk.closeSubpath()
        fill(&local, trunk, Color(red: 0.59, green: 0.50, blue: 0.39))
        var side = Path()
        side.move(to: CGPoint(x: 127, y: 31))
        side.addLine(to: CGPoint(x: 151, y: 26))
        side.addCurve(to: CGPoint(x: 197, y: 161), control1: CGPoint(x: 153, y: 93), control2: CGPoint(x: 163, y: 125))
        side.addLine(to: CGPoint(x: 149, y: 166))
        side.closeSubpath()
        fill(&local, side, Color(red: 0.49, green: 0.41, blue: 0.32))
        oval(&local, CGRect(x: 43, y: 10, width: 110, height: 40), Color(red: 0.78, green: 0.69, blue: 0.56))
        for inset in [0.0, 9.0, 18.0] {
            let ring = CGRect(x: 52 + inset, y: 16 + inset * 0.2, width: 90 - inset * 2, height: 26 - inset * 0.4)
            local.stroke(Path(ellipseIn: ring), with: .color(Color.brown.opacity(0.27)), lineWidth: 1.5)
        }
        for x in [48.0, 65.0, 142.0, 158.0] {
            var bark = Path()
            bark.move(to: CGPoint(x: x, y: 57))
            bark.addCurve(to: CGPoint(x: x + (x < 100 ? -11 : 10), y: 143),
                          control1: CGPoint(x: x + 4, y: 83), control2: CGPoint(x: x - 5, y: 112))
            local.stroke(bark, with: .color(.black.opacity(0.13)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        var hole = Path()
        hole.move(to: CGPoint(x: 68, y: 155))
        hole.addLine(to: CGPoint(x: 69, y: 114))
        hole.addCurve(to: CGPoint(x: 131, y: 114), control1: CGPoint(x: 73, y: 70), control2: CGPoint(x: 127, y: 72))
        hole.addLine(to: CGPoint(x: 134, y: 155))
        hole.closeSubpath()
        local.stroke(hole, with: .color(Color(red: 0.44, green: 0.35, blue: 0.26)), lineWidth: 7)
        fill(&local, hole, Color(red: 0.26, green: 0.22, blue: 0.17))
        var rabbit = local
        // Slow breathing and occasional curious shifts, always contained by the doorway.
        rabbit.clip(to: hole)
        let peekCycle = time.truncatingRemainder(dividingBy: 13)
        let peek = peekCycle < 3 ? sin(peekCycle / 3 * .pi) : 0
        rabbit.translateBy(x: 100 + sin(time * 0.45) * 1.8 + peek * 2.5,
                           y: 146 + sin(time * 1.4) * 0.65 - peek * 2)
        rabbit.rotate(by: .degrees(sin(time * 0.38) * 2))
        for side in [-1.0, 1.0] {
            var ear = rabbit
            ear.translateBy(x: side * 8, y: -17)
            let twitchCycle = (time + (side < 0 ? 0 : 1.7)).truncatingRemainder(dividingBy: 9)
            let twitch = twitchCycle < 0.8 ? sin(twitchCycle / 0.8 * .pi) * 5 : 0
            ear.rotate(by: .degrees(side * (8 + twitch)))
            oval(&ear, CGRect(x: -5, y: -27, width: 10, height: 30), .white)
            oval(&ear, CGRect(x: -2, y: -23, width: 4, height: 21), .pink.opacity(0.40))
        }
        oval(&rabbit, CGRect(x: -19, y: -21, width: 38, height: 29), Color(red: 1, green: 0.98, blue: 0.92))
        let blinkPhase = time.truncatingRemainder(dividingBy: 6.7)
        for x in [-7.0, 7.0] {
            if !reduceMotion && blinkPhase > 6.52 {
                line(&rabbit, [CGPoint(x: x - 1.8, y: -9.5), CGPoint(x: x + 1.8, y: -9.5)], .black, width: 1.1)
            } else {
                oval(&rabbit, CGRect(x: x - 1.5, y: -11, width: 3, height: 3), .black)
            }
        }
        oval(&rabbit, CGRect(x: -2, y: -5, width: 4, height: 3), .pink)
        oval(&rabbit, CGRect(x: -23, y: 1, width: 12, height: 7), .white)
        oval(&rabbit, CGRect(x: 12, y: 1, width: 12, height: 7), .white)
        for index in 0..<5 {
            oval(&local, CGRect(x: 22 + index * 32, y: 151 + index % 2 * 6, width: 25, height: 10),
                 Color(red: 0.43, green: 0.58, blue: 0.31))
        }
        grass(&local, at: CGPoint(x: 15, y: 160), scale: 1.3, bend: gust * 4)
        grass(&local, at: CGPoint(x: 178, y: 159), scale: 1.5, bend: gust * 5)
        stone(&local, x: 37, y: 164, size: 10)
    }

    private func canopy(_ context: inout GraphicsContext, size: CGSize, shadows: Bool, gust: Double) {
        let unit = min(size.width / 750, size.height / 560) * 1.32
        var shadow = Path()
        let clusters: [(CGFloat, CGFloat, Double)] = [
            (-12, 38, 125), (size.width + 12, 27, -125),
            (-18, size.height * 0.96, 48), (size.width + 20, size.height * 0.99, -48)
        ]
        for (index, cluster) in clusters.enumerated() {
            var local = context
            local.translateBy(x: cluster.0 + (shadows ? 32 * unit : 0),
                              y: cluster.1 + (shadows ? 54 * unit : 0))
            local.scaleBy(x: unit * (shadows ? 1.5 : 1), y: unit * (shadows ? 1.5 : 1))
            for blade in 0..<10 {
                let length = CGFloat(80 + (blade * 19 + index * 13) % 51)
                let angle = cluster.2 + Double(blade - 5) * 13 + gust * 2
                if shadows {
                    let transform = CGAffineTransform(translationX: cluster.0 + 32 * unit, y: cluster.1 + 54 * unit)
                        .scaledBy(x: unit * 1.5, y: unit * 1.5)
                        .translatedBy(x: CGFloat(blade % 3 * 8), y: CGFloat(blade % 2 * 9))
                        .rotated(by: angle * .pi / 180)
                    shadow.addPath(leafOutline(length: length).applying(transform))
                } else {
                    leaf(&local, x: CGFloat(blade % 3 * 8), y: CGFloat(blade % 2 * 9),
                         length: length, angle: angle,
                         color: Color(red: 0.27 + Double(blade % 3) * 0.04, green: 0.49 + Double(blade % 2) * 0.045, blue: 0.32),
                         vein: true)
                }
            }
        }
        if shadows {
            fill(&context, shadow, Color(red: 0.26, green: 0.43, blue: 0.31).opacity(0.10))
        }
    }

    private func desertWeed(_ context: inout GraphicsContext, at point: CGPoint, scale: CGFloat, bend: Double) {
        var local = context
        local.translateBy(x: point.x, y: point.y)
        local.scaleBy(x: scale, y: scale)
        oval(&local, CGRect(x: -11, y: -1, width: 27, height: 5), .brown.opacity(0.12))
        let olive = Color(red: 0.55, green: 0.59, blue: 0.36)
        for side in [-1.0, 0, 1.0] {
            var stem = Path()
            let tip = CGPoint(x: side * 8 + bend * 0.5, y: -17 - (side == 0 ? 6 : 0))
            stem.move(to: .zero)
            stem.addQuadCurve(to: tip, control: CGPoint(x: side * 3, y: -11))
            local.stroke(stem, with: .color(olive.opacity(0.72)),
                         style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            leaf(&local, x: side * 4, y: -7, length: 7, angle: side * 50,
                 color: olive.opacity(0.58))
            oval(&local, CGRect(x: tip.x - 1.5, y: tip.y - 3, width: 3, height: 5),
                 Color(red: 0.67, green: 0.58, blue: 0.36).opacity(0.70))
        }
    }

    private func desertDetails(_ context: inout GraphicsContext, size: CGSize, unit: CGFloat, gust: Double) {
        for point in [CGPoint(x: 0.06, y: 0.26), CGPoint(x: 0.87, y: 0.21),
                      CGPoint(x: 0.95, y: 0.73), CGPoint(x: 0.13, y: 0.91),
                      CGPoint(x: 0.46, y: 0.85)] {
            let origin = CGPoint(x: point.x * size.width, y: point.y * size.height)
            var local = context
            local.translateBy(x: origin.x, y: origin.y)
            local.scaleBy(x: unit, y: unit)
            var dune = Path()
            dune.move(to: CGPoint(x: -28, y: 0))
            dune.addCurve(to: CGPoint(x: 65, y: 12), control1: CGPoint(x: 5, y: -19), control2: CGPoint(x: 40, y: 7))
            dune.addQuadCurve(to: CGPoint(x: -28, y: 0), control: CGPoint(x: 14, y: 10))
            fill(&local, dune, Color(red: 0.65, green: 0.48, blue: 0.28).opacity(0.075))
            desertWeed(&context, at: origin, scale: unit * 0.8, bend: gust * 3)
            stone(&local, x: 22, y: 7, size: 7)
            oval(&local, CGRect(x: -35, y: 3, width: 100, height: 15), .brown.opacity(0.035))
        }
    }

    private func log(_ context: inout GraphicsContext, rect: CGRect) {
        var local = context
        local.translateBy(x: rect.minX, y: rect.minY)
        local.scaleBy(x: rect.width / 260, y: rect.height / 84)
        oval(&local, CGRect(x: 3, y: 60, width: 252, height: 18), .black.opacity(0.065))
        // A branch stub interrupts the silhouette and makes the fallen trunk recognizable.
        var branch = Path()
        branch.move(to: CGPoint(x: 124, y: 28))
        branch.addLine(to: CGPoint(x: 165, y: 0))
        branch.addQuadCurve(to: CGPoint(x: 181, y: 10), control: CGPoint(x: 179, y: -4))
        branch.addLine(to: CGPoint(x: 151, y: 38))
        branch.closeSubpath()
        fill(&local, branch, Color(red: 0.83, green: 0.71, blue: 0.52))
        var trunk = Path()
        trunk.move(to: CGPoint(x: 31, y: 14))
        trunk.addCurve(to: CGPoint(x: 237, y: 26), control1: CGPoint(x: 96, y: 3), control2: CGPoint(x: 178, y: 23))
        trunk.addQuadCurve(to: CGPoint(x: 238, y: 74), control: CGPoint(x: 266, y: 48))
        trunk.addCurve(to: CGPoint(x: 27, y: 71), control1: CGPoint(x: 159, y: 83), control2: CGPoint(x: 94, y: 62))
        trunk.closeSubpath()
        fill(&local, trunk, Color(red: 0.88, green: 0.77, blue: 0.59))
        var underside = Path()
        underside.move(to: CGPoint(x: 31, y: 55))
        underside.addCurve(to: CGPoint(x: 246, y: 58), control1: CGPoint(x: 97, y: 50), control2: CGPoint(x: 189, y: 74))
        underside.addLine(to: CGPoint(x: 238, y: 74))
        underside.addCurve(to: CGPoint(x: 27, y: 71), control1: CGPoint(x: 160, y: 83), control2: CGPoint(x: 94, y: 62))
        underside.closeSubpath()
        fill(&local, underside, Color(red: 0.76, green: 0.63, blue: 0.44))
        oval(&local, CGRect(x: 218, y: 25, width: 36, height: 49), Color(red: 0.79, green: 0.66, blue: 0.47))
        oval(&local, CGRect(x: 4, y: 12, width: 48, height: 62), Color(red: 0.72, green: 0.59, blue: 0.41))
        oval(&local, CGRect(x: 10, y: 17, width: 36, height: 51), Color(red: 0.91, green: 0.80, blue: 0.62))
        for inset in [0.0, 7.0, 13.0] {
            local.stroke(Path(ellipseIn: CGRect(x: 13 + inset, y: 21 + inset * 0.8, width: 29 - inset * 1.6, height: 42 - inset * 1.6)),
                         with: .color(Color(red: 0.74, green: 0.61, blue: 0.43)), lineWidth: 2)
        }
        for y in [26.0, 40.0, 56.0] {
            var grain = Path()
            grain.move(to: CGPoint(x: 55, y: y))
            grain.addCurve(to: CGPoint(x: 211, y: y + 8), control1: CGPoint(x: 94, y: y - 8), control2: CGPoint(x: 156, y: y + 13))
            local.stroke(grain, with: .color(Color.brown.opacity(0.20)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        line(&local, [CGPoint(x: 55, y: 46), CGPoint(x: 78, y: 43), CGPoint(x: 90, y: 48)], .white.opacity(0.28))
        stone(&local, x: 257, y: 73, size: 8)
    }
}

struct GardenMascot: View {
    let bed: GardenPlot
    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 40, y: size.height / 40)
            if bed == .sunny {
                for x in [4.0, 23.0] {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: 6, width: 14, height: 17)), with: .color(.purple.opacity(0.7)))
                    context.fill(Path(ellipseIn: CGRect(x: x + 2, y: 22, width: 11, height: 12)), with: .color(.purple.opacity(0.5)))
                }
                context.fill(Path(roundedRect: CGRect(x: 18, y: 9, width: 5, height: 25), cornerRadius: 3), with: .color(.brown))
            } else if bed == .shady {
                context.fill(Path(ellipseIn: CGRect(x: 8, y: 5, width: 24, height: 31)), with: .color(.red))
                context.fill(Path(ellipseIn: CGRect(x: 14, y: 2, width: 12, height: 10)), with: .color(.black.opacity(0.8)))
                var line = Path()
                line.move(to: CGPoint(x: 20, y: 12)); line.addLine(to: CGPoint(x: 20, y: 35))
                context.stroke(line, with: .color(.black.opacity(0.8)), lineWidth: 2)
                for point in [CGPoint(x: 14, y: 17), CGPoint(x: 26, y: 24), CGPoint(x: 13, y: 28)] {
                    context.fill(Path(ellipseIn: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)), with: .color(.black.opacity(0.8)))
                }
            } else {
                context.fill(Path(ellipseIn: CGRect(x: 10, y: 19, width: 20, height: 11)), with: .color(.orange))
                var tail = Path()
                tail.move(to: CGPoint(x: 27, y: 23))
                tail.addCurve(to: CGPoint(x: 25, y: 5), control1: CGPoint(x: 42, y: 16), control2: CGPoint(x: 36, y: 0))
                context.stroke(tail, with: .color(.orange), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                for y in [20.0, 26.0, 31.0] {
                    var legs = Path()
                    legs.move(to: CGPoint(x: 14, y: 25)); legs.addLine(to: CGPoint(x: 5, y: y))
                    legs.move(to: CGPoint(x: 22, y: 26)); legs.addLine(to: CGPoint(x: 29, y: y + 3))
                    context.stroke(legs, with: .color(.orange), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
