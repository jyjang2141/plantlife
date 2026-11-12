//
//  PlantShapes.swift
//  plantlife
//
//  The colors and building blocks (leaves, stems, petals...) that every plant icon is drawn from.
//
//  Every icon is drawn in an 80 x 80 box. x runs left to right, y runs top to bottom,
//  and the ground is at y = 74. Angles are in degrees: 0 points straight up, positive leans right.
//

import SwiftUI

// MARK: - Colors

enum Ink {
    static let stem        = Color(red: 0.24, green: 0.56, blue: 0.20)
    static let leafDark    = Color(red: 0.22, green: 0.58, blue: 0.22)
    static let leafLight   = Color(red: 0.36, green: 0.74, blue: 0.30)
    static let sprout      = Color(red: 0.50, green: 0.80, blue: 0.35)
    static let vein        = Color(red: 0.72, green: 0.90, blue: 0.60)
    static let bud         = Color(red: 0.62, green: 0.80, blue: 0.32)
    static let dryLeaf     = Color(red: 0.80, green: 0.72, blue: 0.34)
    /// The dried-out rim around a caterpillar bite.
    static let chewedEdge  = Color(red: 0.62, green: 0.50, blue: 0.20)

    static let blueGreen      = Color(red: 0.34, green: 0.62, blue: 0.44)
    static let blueGreenLight = Color(red: 0.46, green: 0.74, blue: 0.54)

    static let blossom       = Color(red: 1.00, green: 0.85, blue: 0.20)
    static let blossomCenter = Color(red: 0.95, green: 0.62, blue: 0.05)
    static let flowerCenter  = Color(red: 1.00, green: 0.78, blue: 0.12)
    static let seedBrown     = Color(red: 0.45, green: 0.27, blue: 0.10)
    static let seedLight     = Color(red: 0.62, green: 0.42, blue: 0.18)

    static let bark     = Color(red: 0.50, green: 0.33, blue: 0.20)
    static let barkDark = Color(red: 0.38, green: 0.24, blue: 0.14)
    static let stake    = Color(red: 0.74, green: 0.56, blue: 0.36)
    static let root     = Color(red: 0.74, green: 0.80, blue: 0.70)

    static let dead     = Color(red: 0.62, green: 0.47, blue: 0.29)
    static let deadDark = Color(red: 0.45, green: 0.33, blue: 0.20)
}

// MARK: - Geometry helpers

func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

/// The point `length` away from `base`, heading in the direction `angle`.
func toward(_ base: CGPoint, _ angle: Double, _ length: CGFloat) -> CGPoint {
    let radians = angle * .pi / 180
    return CGPoint(x: base.x + CGFloat(sin(radians)) * length, y: base.y - CGFloat(cos(radians)) * length)
}

/// A point partway (t from 0 to 1) along the curve from `a` to `b` bent toward `c`.
func curvePoint(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
    let u = 1 - t
    return CGPoint(x: u * u * a.x + 2 * u * t * c.x + t * t * b.x,
                   y: u * u * a.y + 2 * u * t * c.y + t * t * b.y)
}

/// Which way the curve from `a` to `b` (bent toward `c`) is heading at t.
func curveAngle(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, _ t: CGFloat) -> Double {
    let dx = 2 * (1 - t) * (c.x - a.x) + 2 * t * (b.x - c.x)
    let dy = 2 * (1 - t) * (c.y - a.y) + 2 * t * (b.y - c.y)
    return Double(atan2(dx, -dy)) * 180 / .pi
}

private func placed(_ path: Path, at point: CGPoint, angle: Double) -> Path {
    path.applying(CGAffineTransform(rotationAngle: angle * .pi / 180)
        .concatenating(CGAffineTransform(translationX: point.x, y: point.y)))
}

// MARK: - Caterpillar bites

extension EnvironmentValues {
    /// How chewed the leaves being drawn are: 0 = fine, 3 = lots of bites. Set it on the Canvas;
    /// every leaf, blade, lobed leaf and canopy then draws its own chewed version.
    @Entry var leafBites: Int = 0
}

/// A steady "random" pick from 0 to 2 for a leaf, so the same leaf is always bitten in the same place.
private func chewRoll(_ p: CGPoint, _ salt: Double) -> Int {
    let v = abs(sin(Double(p.x) * 12.9898 + Double(p.y) * 78.233 + salt * 37.719) * 43758.5453)
    return min(Int(v.truncatingRemainder(dividingBy: 1) * 3), 2)
}

/// A steady "random" number from 0 to 9, for finer picks than `chewRoll`.
private func chewRoll10(_ p: CGPoint, _ salt: Double) -> Int {
    let v = abs(sin(Double(p.x) * 39.346 + Double(p.y) * 11.135 + salt * 83.155) * 24634.6345)
    return min(Int(v.truncatingRemainder(dividingBy: 1) * 10), 9)
}

/// One scalloped caterpillar bite at `center`: a big round bite with a smaller one on each side.
/// `angle` is the way the leaf edge runs (0 = straight up).
func biteShape(_ center: CGPoint, radius r: CGFloat, angle: Double = 0) -> Path {
    var shape = Path()
    shape.addEllipse(in: CGRect(x: -r, y: -r, width: r * 2, height: r * 2))
    for side: CGFloat in [-1, 1] {
        let small = r * 0.6
        shape.addEllipse(in: CGRect(x: -small, y: side * r * 0.85 - small, width: small * 2, height: small * 2))
    }
    return placed(shape, at: center, angle: angle)
}

// MARK: - Building blocks

extension GraphicsContext {
    func paint(_ path: Path, _ color: Color) {
        fill(path, with: .color(color))
    }

    /// How chewed the leaves are (0 to 3), from the Canvas's `leafBites`.
    var bites: Int { min(max(environment.leafBites, 0), 3) }

    /// Whether a leaf at `spot` gets bitten: two thirds of the leaves at level 1, all of them from level 2.
    func isBitten(_ spot: CGPoint, _ salt: Double = 0) -> Bool {
        bites > 0 && chewRoll(spot, salt) < bites + 1
    }

    /// Which side of a leaf at `spot` gets bitten first (-1 = left, 1 = right).
    func biteSide(_ spot: CGPoint, _ salt: Double = 0) -> CGFloat {
        chewRoll(spot, salt + 5) == 1 ? -1 : 1
    }

    /// Draws `draw` on its own layer, then cuts `cuts` out of it, so only that part of the plant
    /// is bitten (whatever is drawn behind it still shows through the holes). Each bite gets a
    /// dry brown rim, like a real chewed leaf, so it stands out at a glance.
    func chewed(_ cuts: [Path], rim: CGFloat = 1.6, _ draw: (GraphicsContext) -> Void) {
        guard !cuts.isEmpty else { return draw(self) }
        drawLayer { layer in
            draw(layer)
            layer.blendMode = .destinationOut
            for cut in cuts { layer.fill(cut, with: .color(.black)) }
            // Only paints where the plant is still there, so the rim hugs the inside of each bite.
            layer.blendMode = .sourceAtop
            for cut in cuts { layer.stroke(cut, with: .color(Ink.chewedEdge), lineWidth: rim) }
        }
    }

    /// A stem or branch: 2 points draw a straight line, 3 a gentle curve, 4 an S-curve.
    func line(_ points: CGPoint..., width: CGFloat = 3, color: Color = Ink.stem) {
        var path = Path()
        path.move(to: points[0])
        switch points.count {
        case 2:  path.addLine(to: points[1])
        case 3:  path.addQuadCurve(to: points[2], control: points[1])
        default: path.addCurve(to: points[3], control1: points[1], control2: points[2])
        }
        stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    func dot(_ center: CGPoint, _ radius: CGFloat, _ color: Color) {
        paint(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                     width: radius * 2, height: radius * 2)), color)
    }

    func oval(_ center: CGPoint, width: CGFloat, height: CGFloat, angle: Double = 0, _ color: Color) {
        let shape = Path(ellipseIn: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
        paint(placed(shape, at: center, angle: angle), color)
    }

    /// An almond-shaped leaf growing from `base`.
    /// Chewed leaves (see `leafBites`) have bites out of their edges.
    func leaf(_ base: CGPoint, angle: Double, length: CGFloat, width: CGFloat, _ color: Color, vein: Bool = false) {
        var shape = Path()
        shape.move(to: .zero)
        shape.addCurve(to: CGPoint(x: 0, y: -length),
                       control1: CGPoint(x: width, y: -length * 0.3), control2: CGPoint(x: width * 0.6, y: -length * 0.8))
        shape.addCurve(to: .zero,
                       control1: CGPoint(x: -width * 0.6, y: -length * 0.8), control2: CGPoint(x: -width, y: -length * 0.3))

        // The leaf is widest about halfway up, at about 0.6 of `width` from the middle.
        var cuts: [Path] = []
        if length >= 5, width >= 2.5, isBitten(base, angle) {
            let side = biteSide(base, angle)
            cuts.append(biteShape(CGPoint(x: side * width * 0.6, y: -length * 0.48), radius: width * 0.5))
            if bites >= 2 && length >= 9 {
                cuts.append(biteShape(CGPoint(x: -side * width * 0.52, y: -length * 0.7), radius: width * 0.4))
            }
            if bites >= 3 && length >= 12 {
                // A bite off the tip and a hole chewed through the middle.
                cuts.append(biteShape(CGPoint(x: 0, y: -length * 0.98), radius: width * 0.35, angle: 90))
                cuts.append(Path(ellipseIn: CGRect(x: -side * width * 0.22 - width * 0.17, y: -length * 0.3 - width * 0.14,
                                                   width: width * 0.34, height: width * 0.28)))
            }
        }

        chewed(cuts.map { placed($0, at: base, angle: angle) }, rim: min(1.6, width * 0.22)) { g in
            g.paint(placed(shape, at: base, angle: angle), color)
            if vein {
                var midrib = Path()
                midrib.move(to: CGPoint(x: 0, y: -length * 0.1))
                midrib.addLine(to: CGPoint(x: 0, y: -length * 0.82))
                g.stroke(placed(midrib, at: base, angle: angle), with: .color(Ink.vein), lineWidth: 0.9)
            }
        }
    }

    /// A long strap leaf (grass, corn, palm sprouts) from `a` to `b`, bent toward `bend`.
    func blade(from a: CGPoint, to b: CGPoint, bend c: CGPoint, width: CGFloat, _ color: Color) {
        let dx = b.x - a.x, dy = b.y - a.y
        let length = max(hypot(dx, dy), 0.001)
        let n = CGPoint(x: -dy / length * width / 2, y: dx / length * width / 2)
        var shape = Path()
        shape.move(to: pt(a.x + n.x, a.y + n.y))
        shape.addQuadCurve(to: b, control: pt(c.x + n.x, c.y + n.y))
        shape.addQuadCurve(to: pt(a.x - n.x, a.y - n.y), control: pt(c.x - n.x, c.y - n.y))
        shape.closeSubpath()

        var cuts: [Path] = []
        if length >= 8, width >= 2, isBitten(a, Double(b.x)) {
            let side = biteSide(a, Double(b.x))
            let spots: [CGFloat] = switch bites {
            case 1:  [0.5]
            case 2:  [0.4, 0.7]
            default: [0.3, 0.55, 0.78]
            }
            for (index, t) in spots.enumerated() where length >= 8 * CGFloat(index + 1) {
                let edge = curvePoint(a, c, b, t)
                let heading = curveAngle(a, c, b, t)
                let flip = index % 2 == 0 ? side : -side
                cuts.append(biteShape(pt(edge.x + flip * n.x * 1.1, edge.y + flip * n.y * 1.1),
                                      radius: width * 0.55, angle: heading))
            }
        }
        chewed(cuts, rim: min(1.6, width * 0.3)) { $0.paint(shape, color) }
    }

    /// A flower seen from the front: `petals` petals around a center.
    func flower(_ center: CGPoint, radius: CGFloat, petals: Int, _ petal: Color, center middle: Color?,
                petalWidth: CGFloat = 0.9, centerSize: CGFloat = 0.35, rotation: Double = 0) {
        let shape = Path(ellipseIn: CGRect(x: -radius * petalWidth / 2, y: -radius,
                                           width: radius * petalWidth, height: radius))
        for index in 0..<petals {
            paint(placed(shape, at: center, angle: rotation + Double(index) * 360 / Double(petals)), petal)
        }
        if let middle { dot(center, radius * centerSize, middle) }
    }

    /// A leaf made of small leaflets on a stalk (tomato, rose).
    func compoundLeaf(_ base: CGPoint, angle: Double, length: CGFloat, _ color: Color) {
        let tip = toward(base, angle, length * 0.55)
        line(base, tip, width: 1.6)
        leaf(tip, angle: angle, length: length * 0.5, width: length * 0.22, color)
        let middle = toward(base, angle, length * 0.3)
        leaf(middle, angle: angle - 55, length: length * 0.35, width: length * 0.16, color)
        leaf(middle, angle: angle + 55, length: length * 0.35, width: length * 0.16, color)
    }

    /// Three leaflets on one stalk (strawberry).
    func trifoliate(_ base: CGPoint, angle: Double, size: CGFloat, _ color: Color) {
        let end = toward(base, angle, size * 0.6)
        line(base, end, width: 1.4)
        leaf(end, angle: angle - 50, length: size * 0.42, width: size * 0.22, color)
        leaf(end, angle: angle + 50, length: size * 0.42, width: size * 0.22, color)
        leaf(end, angle: angle, length: size * 0.5, width: size * 0.26, color, vein: true)
    }

    /// A big round leaf with lobes (cucumber, pumpkin).
    func lobedLeaf(_ c: CGPoint, radius r: CGFloat, _ color: Color) {
        var cuts: [Path] = []
        if r >= 5, isBitten(c) {
            let side = biteSide(c)
            cuts.append(biteShape(pt(c.x + side * r * 0.92, c.y - r * 0.15), radius: r * 0.42))
            if bites >= 2 {
                cuts.append(biteShape(pt(c.x - side * r * 0.35, c.y - r * 0.98), radius: r * 0.36, angle: 90))
            }
            if bites >= 3 {
                cuts.append(biteShape(pt(c.x - side * r * 0.85, c.y + r * 0.3), radius: r * 0.34))
                cuts.append(Path(ellipseIn: CGRect(x: c.x + side * r * 0.2 - r * 0.15, y: c.y - r * 0.5,
                                                   width: r * 0.3, height: r * 0.26)))
            }
        }
        chewed(cuts) { g in
            g.dot(pt(c.x, c.y - r * 0.45), r * 0.55, color)
            g.dot(pt(c.x - r * 0.5, c.y - r * 0.1), r * 0.5, color)
            g.dot(pt(c.x + r * 0.5, c.y - r * 0.1), r * 0.5, color)
            g.dot(pt(c.x - r * 0.3, c.y + r * 0.3), r * 0.45, color)
            g.dot(pt(c.x + r * 0.3, c.y + r * 0.3), r * 0.45, color)
            let bottom = pt(c.x, c.y + r * 0.55)
            for target in [pt(c.x, c.y - r * 0.8), pt(c.x - r * 0.8, c.y - r * 0.2), pt(c.x + r * 0.8, c.y - r * 0.2)] {
                g.line(bottom, target, width: 0.8, color: Ink.vein.opacity(0.8))
            }
        }
    }

    /// A curved stalk with small leaflets along both sides (ferns, palm fronds).
    func frond(from a: CGPoint, bend c: CGPoint, to b: CGPoint, leaflet: CGFloat, count: Int,
               spread: Double = 55, _ color: Color) {
        line(a, c, b, width: 1.4, color: color)
        for index in 0..<count {
            let t = 0.18 + 0.78 * CGFloat(index) / CGFloat(max(count - 1, 1))
            let point = curvePoint(a, c, b, t)
            let heading = curveAngle(a, c, b, t)
            let length = leaflet * (1.15 - t * 0.7)
            // Leaflets are too thin to bite, so chewed fronds lose whole leaflets instead
            // (20% of them per level), leaving a brown stub where each one was.
            for side in [-1.0, 1.0] {
                let leafletAngle = heading + side * spread
                if bites > 0 && chewRoll10(point, leafletAngle) < bites * 2 {
                    line(point, toward(point, leafletAngle, length * 0.3), width: 1.1, color: Ink.chewedEdge)
                } else {
                    leaf(point, angle: leafletAngle, length: length, width: length * 0.32, color)
                }
            }
        }
        leaf(curvePoint(a, c, b, 0.94), angle: curveAngle(a, c, b, 0.94),
             length: leaflet * 0.5, width: leaflet * 0.16, color)
    }

    /// A clump of overlapping circles (tree tops, bushes). Each entry is (x, y, radius).
    /// Chewed canopies have bites out of their outside edge.
    func canopy(_ circles: [(CGFloat, CGFloat, CGFloat)], _ color: Color) {
        var cuts: [Path] = []
        if bites > 0, !circles.isEmpty {
            let middle = pt(circles.map(\.0).reduce(0, +) / CGFloat(circles.count),
                            circles.map(\.1).reduce(0, +) / CGFloat(circles.count))
            for (x, y, r) in circles where r >= 5 && isBitten(pt(x, y)) {
                // Bite the side of the circle that faces away from the middle of the canopy.
                let dx = x - middle.x, dy = y - middle.y
                let away = hypot(dx, dy) < 3 ? -90.0 : Double(atan2(dy, dx)) * 180 / .pi
                let turns = [away, away - 40, away + 40].prefix(bites)
                for turn in turns {
                    let radians = turn * .pi / 180
                    let edge = pt(x + CGFloat(cos(radians)) * r, y + CGFloat(sin(radians)) * r)
                    cuts.append(biteShape(edge, radius: r * 0.34, angle: turn))
                }
            }
        }
        chewed(cuts) { g in
            for (x, y, r) in circles { g.dot(pt(x, y), r, color) }
        }
    }

    /// A small curly tendril (cucumber, pumpkin).
    func tendril(_ start: CGPoint, right: Bool) {
        let side: CGFloat = right ? 1 : -1
        var path = Path()
        path.move(to: start)
        path.addQuadCurve(to: pt(start.x + side * 4, start.y - 3), control: pt(start.x + side * 1, start.y - 4))
        path.addArc(center: pt(start.x + side * 4, start.y - 1.5), radius: 1.5,
                    startAngle: .degrees(right ? -90 : 270), endAngle: .degrees(right ? 160 : 20), clockwise: !right)
        stroke(path, with: .color(Ink.leafLight), lineWidth: 0.9)
    }
}

// MARK: - Stages many plants share

enum CommonParts {
    /// A tiny shoot with two seed leaves.
    static func sprout(_ g: GraphicsContext, leaf: Color = Ink.sprout, width: CGFloat = 3.6, length: CGFloat = 10) {
        g.line(pt(40, 74), pt(41, 69), pt(40, 64), width: 2.6)
        g.leaf(pt(40, 65), angle: -62, length: length, width: width, leaf)
        g.leaf(pt(40, 65), angle: 62, length: length, width: width, Ink.leafLight)
    }

    /// Seed leaves plus the first pair of true leaves.
    static func seedling(_ g: GraphicsContext, trueLeaf: Color = Ink.leafDark, seedLeafWidth: CGFloat = 5) {
        g.line(pt(40, 74), pt(40, 50))
        g.leaf(pt(40, 62), angle: -70, length: 15, width: seedLeafWidth, Ink.sprout)
        g.leaf(pt(40, 62), angle: 70, length: 15, width: seedLeafWidth, Ink.leafLight)
        g.leaf(pt(40, 51), angle: -18, length: 13, width: 5, trueLeaf, vein: true)
        g.leaf(pt(40, 51), angle: 22, length: 11, width: 4.5, trueLeaf, vein: true)
    }

    /// Seed leaves plus one round lobed leaf (cucumber, pumpkin).
    static func vineSeedling(_ g: GraphicsContext) {
        g.line(pt(40, 74), pt(40, 54))
        g.leaf(pt(40, 64), angle: -72, length: 13, width: 7, Ink.sprout)
        g.leaf(pt(40, 64), angle: 72, length: 13, width: 7, Ink.leafLight)
        g.lobedLeaf(pt(40, 47), radius: 9, Ink.leafDark)
    }
}
