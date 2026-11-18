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

    static func positions(_ plants: [GardenPlant]) -> [CGPoint] {
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
                result.append(ordered.first { point in
                    !(result + saved).contains { overlaps(point, $0) } &&
                    isAllowed(point, bed: plant.plot, occupied: [])
                } ?? candidates[result.count % candidates.count])
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
            let positions = GardenLayout.positions(plants)
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
