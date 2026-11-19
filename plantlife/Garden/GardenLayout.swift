import SwiftUI
import SwiftData

/// All coordinates describe a plant's ground anchor in a normalized landscape.
enum GardenLayout {
    static let referenceSize = CGSize(width: 1024, height: 768)
    static let edgeMargin: CGFloat = 14

    static func spriteSize(in size: CGSize) -> CGFloat {
        min(size.width * 0.27, size.height * 0.275)
    }

    /// One nonzero-winding path: overlapping blocked shapes are filled just once.
    /// Both the overlay and the planting validator use this exact geometry.
    static func blockedPath(bed: GardenPlot, size: CGSize, occupied: [CGPoint], full: Bool = false) -> CGPath {
        let path = CGMutablePath()
        let whole = CGRect(origin: .zero, size: size)
        if full {
            path.addRect(whole)
            return path
        }
        let margin = min(edgeMargin, min(size.width, size.height) / 4)
        path.addRect(CGRect(x: 0, y: 0, width: size.width, height: margin))
        path.addRect(CGRect(x: 0, y: size.height - margin, width: size.width, height: margin))
        path.addRect(CGRect(x: 0, y: 0, width: margin, height: size.height))
        path.addRect(CGRect(x: size.width - margin, y: 0, width: margin, height: size.height))
        path.addPath(decorationPath(bed: bed, size: size))

        // Follow each illustration's actual silhouette rather than its old layout box.
        let scenery = sceneryRect(bed, size: size).insetBy(dx: -7, dy: -7)
        if bed == .sunny {
            path.addEllipse(in: scenery)
        } else {
            path.addRoundedRect(in: scenery, cornerWidth: min(18, scenery.height / 4),
                                cornerHeight: min(18, scenery.height / 4))
        }
        let sprite = spriteSize(in: size)
        for point in occupied {
            let footprint = CGRect(x: point.x * size.width - sprite * 0.40 - 6,
                                   y: point.y * size.height - sprite * 0.85 - 6,
                                   width: sprite * 0.80 + 12, height: sprite * 0.95 + 12)
            path.addEllipse(in: footprint)
        }
        return path
    }

    static func sunnyShrubs(in size: CGSize) -> [(origin: CGPoint, scale: CGFloat)] {
        let unit = min(size.width / 750, size.height / 560)
        return [
            (CGPoint(x: 6, y: size.height * 0.97), unit * 1.35),
            (CGPoint(x: size.width - 6, y: size.height * 0.98), unit * 1.40),
            (CGPoint(x: size.width * 0.64, y: -18), unit * 0.75)
        ]
    }

    static func canopyScale(in size: CGSize) -> CGFloat {
        min(size.width / 750, size.height / 560) * 1.32
    }

    static func canopyClusters(in size: CGSize) -> [(CGFloat, CGFloat, Double)] {
        [(-12, 38, 125), (size.width + 12, 27, -125),
         (-18, size.height * 0.96, 48), (size.width + 20, size.height * 0.99, -48)]
    }

    static func leafPath(length: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addQuadCurve(to: CGPoint(x: 0, y: -length),
                          control: CGPoint(x: -length * 0.55, y: -length * 0.64))
        path.addQuadCurve(to: .zero, control: CGPoint(x: length * 0.48, y: -length * 0.55))
        path.closeSubpath()
        return path
    }

    /// Generous rounded zones around each corner group, rather than individual leaf outlines.
    static func decorationPath(bed: GardenPlot, size: CGSize) -> CGPath {
        let path = CGMutablePath()
        let padding = max(14, min(size.width, size.height) * 0.02)
        if bed == .sunny {
            for shrub in sunnyShrubs(in: size).prefix(2) {
                let group = CGMutablePath()
                let transform = CGAffineTransform(translationX: shrub.origin.x, y: shrub.origin.y)
                    .scaledBy(x: shrub.scale, y: shrub.scale)
                for index in 0..<5 {
                    group.addEllipse(in: CGRect(x: CGFloat(index - 2) * 25 - 31,
                        y: -38 - CGFloat(2 - abs(index - 2)) * 17, width: 62, height: 62), transform: transform)
                }
                for index in 0..<7 {
                    group.addEllipse(in: CGRect(x: CGFloat(index - 3) * 20 - 27,
                        y: -CGFloat(3 - abs(index - 3)) * 14 - 30, width: 54, height: 54), transform: transform)
                }
                path.addRoundedRect(in: group.boundingBoxOfPath.insetBy(dx: -padding, dy: -padding),
                                    cornerWidth: 24, cornerHeight: 24)
            }
        } else if bed == .shady {
            let scale = canopyScale(in: size)
            for (index, cluster) in canopyClusters(in: size).enumerated() {
                let group = CGMutablePath()
                // Include the small sweep of the leaves during a breeze.
                for sway in [0.0, 1.0, 2.0] {
                    for blade in 0..<10 {
                        let length = CGFloat(80 + (blade * 19 + index * 13) % 51)
                        let angle = cluster.2 + Double(blade - 5) * 13 + sway
                        let transform = CGAffineTransform(translationX: cluster.0, y: cluster.1)
                            .scaledBy(x: scale, y: scale)
                            .translatedBy(x: CGFloat(blade % 3 * 8), y: CGFloat(blade % 2 * 9))
                            .rotated(by: angle * .pi / 180)
                        group.addPath(leafPath(length: length), transform: transform)
                    }
                }
                path.addRoundedRect(in: group.boundingBoxOfPath.insetBy(dx: -padding, dy: -padding),
                                    cornerWidth: 24, cornerHeight: 24)
            }
        }
        return path
    }
    static func obstacles(_ bed: GardenPlot) -> [CGRect] {
        switch bed {
        case .sunny: [CGRect(x: 0.75, y: 0.37, width: 0.38, height: 0.34)]
        case .shady: [CGRect(x: 0.72, y: 0.12, width: 0.27, height: 0.29)]
        case .desert: [CGRect(x: 0.03, y: 0.78, width: 0.26, height: 0.19)]
        }
    }

    /// Fit landmarks without stretching their illustration when the device rotates.
    static func sceneryRect(_ bed: GardenPlot, size: CGSize) -> CGRect {
        let box = obstacles(bed)[0].scaled(to: size)
        let aspect: CGFloat = bed == .sunny ? 1.60 : bed == .desert ? 2.20 : 1.12
        let width = min(box.width, box.height * aspect)
        let height = width / aspect
        return CGRect(x: box.midX - width / 2, y: box.midY - height / 2, width: width, height: height)
    }

    static func positions(_ plants: [GardenPlant], size: CGSize = referenceSize) -> [CGPoint] {
        var result = [CGPoint]()
        let saved = plants.filter { $0.gardenX >= 0 && $0.gardenY >= 0 }
            .map { CGPoint(x: $0.gardenX, y: $0.gardenY) }
        for plant in plants {
            if plant.gardenX >= 0, plant.gardenY >= 0 {
                result.append(CGPoint(x: plant.gardenX, y: plant.gardenY))
            } else {
                // Legacy plots become natural ground positions without changing saved growth.
                let candidates = fallbackPoints
                let start = max(0, plant.slot) % candidates.count
                let ordered = Array(candidates[start...] + candidates[..<start])
                let occupied = result + saved
                let fits: (CGPoint) -> Bool = { point in
                    !occupied.contains { overlaps(point, $0) } &&
                    isAllowed(point, bed: plant.plot, occupied: occupied, size: size)
                }
                // Broader corner zones may cover a legacy default. Find another open
                // location rather than placing multiple older plants on the same spot.
                let alternatives = (0..<25).flatMap { row in
                    (0..<25).map { column in
                        CGPoint(x: 0.06 + Double(column) * 0.036,
                                y: 0.18 + Double(row) * 0.029)
                    }
                }
                result.append(ordered.first(where: fits) ?? alternatives.first(where: fits)
                              ?? candidates[result.count % candidates.count])
            }
        }
        return result
    }

    static let fallbackPoints: [CGPoint] = [
        CGPoint(x: 0.17, y: 0.36), CGPoint(x: 0.39, y: 0.39), CGPoint(x: 0.62, y: 0.34),
        CGPoint(x: 0.20, y: 0.56), CGPoint(x: 0.43, y: 0.59), CGPoint(x: 0.65, y: 0.55),
        CGPoint(x: 0.18, y: 0.74), CGPoint(x: 0.40, y: 0.79), CGPoint(x: 0.64, y: 0.77)
    ]

    static func overlaps(_ a: CGPoint, _ b: CGPoint) -> Bool {
        let dx = (a.x - b.x) / 0.19
        let dy = (a.y - b.y) / 0.18
        return dx * dx + dy * dy < 1
    }

    static func isAllowed(_ point: CGPoint, bed: GardenPlot, occupied: [CGPoint],
                          size: CGSize = referenceSize) -> Bool {
        let pixel = CGPoint(x: point.x * size.width, y: point.y * size.height)
        return CGRect(origin: .zero, size: size).contains(pixel) &&
            !blockedPath(bed: bed, size: size, occupied: occupied).contains(pixel)
    }
}

/// Shared scenery and plant layer, used both while exploring and choosing a spot.
struct GardenGround: View {
    let bed: GardenPlot
    let plants: [GardenPlant]
    var active = true
    var placement = false
    var now = Date.now
    var select: (GardenPlant) -> Void = { _ in }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let positions = GardenLayout.positions(plants, size: size)
            ZStack {
                GardenScenery(bed: bed, active: active)
                if placement {
                    Canvas { context, canvas in
                        let blocked = Path(GardenLayout.blockedPath(bed: bed, size: canvas,
                                           occupied: positions, full: plants.count >= GardenPlot.plotCount))
                        context.fill(Path(CGRect(origin: .zero, size: canvas)), with: .color(.green.opacity(0.20)))
                        // Remove green beneath the entire blocked mask, then tint it once.
                        context.blendMode = .destinationOut
                        context.fill(blocked, with: .color(.white))
                        context.blendMode = .normal
                        context.fill(blocked, with: .color(.red.opacity(0.28)))
                    }
                    .allowsHitTesting(false)
                }
                ForEach(Array(plants.enumerated()), id: \.element.persistentModelID) { index, plant in
                    let point = positions[index]
                    let spriteSize = GardenLayout.spriteSize(in: size)
                    Button { select(plant) } label: {
                        ZStack(alignment: .bottom) {
                            Ellipse().fill(.black.opacity(0.055))
                                .frame(width: spriteSize * 0.78, height: spriteSize * 0.13).offset(y: 3)
                            Ellipse().fill(bed.wetSoil.opacity(0.55))
                                .frame(width: spriteSize * 0.64, height: spriteSize * 0.11)
                            PlantWithBugs(plant: plant, droopy: plant.isThirsty(at: now), size: spriteSize, now: now)
                                .allowsHitTesting(false)
                        }
                        .frame(width: max(44, spriteSize), height: max(44, spriteSize))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(placement)
                    .accessibilityLabel("Care for " + plant.displayName)
                    .position(x: point.x * size.width, y: point.y * size.height - spriteSize * 0.40)
                }
            }
        }
    }
}

extension CGRect {
    func scaled(to size: CGSize) -> CGRect {
        CGRect(x: minX * size.width, y: minY * size.height, width: width * size.width, height: height * size.height)
    }
}
