//
//  GardenPlant.swift
//  plantlife
//
//  A plant in the Garden, which bed it lives in, and how it looks.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - What a garden plant looks like

enum PlantKind: String, Codable {
    case sunflower, cactus, standard

    var emoji: String {
        switch self {
        case .sunflower: "🌻"
        case .cactus:    "🌵"
        case .standard:  "🪴"
        }
    }

    static func from(info: PlantInfo) -> PlantKind {
        let text = "\(info.commonName ?? "") \(info.scientificName ?? "")".lowercased()
        if text.contains("sunflower") || text.contains("helianthus") { return .sunflower }
        if text.contains("cactus") || text.contains("cacti") || text.contains("cactaceae") { return .cactus }
        return .standard
    }
}

// MARK: - Where a plant lives in the garden (based on its needs)

enum GardenPlot: String, Codable, CaseIterable, Identifiable {
    case desert, sunny, shady
    var id: Self { self }

    var title: String {
        switch self {
        case .desert: "Desert Bed"
        case .sunny:  "Sunny Bed"
        case .shady:  "Shady Corner"
        }
    }

    var emoji: String {
        switch self {
        case .desert: "🏜️"
        case .sunny:  "☀️"
        case .shady:  "🌳"
        }
    }

    /// SF Symbol shown for this bed (replaces the emoji).
    var symbol: String {
        switch self {
        case .desert: "sun.haze.fill"
        case .sunny:  "sun.max.fill"
        case .shady:  "tree.fill"
        }
    }

    var tint: Color {
        switch self {
        case .desert: .orange
        case .sunny:  .yellow
        case .shady:  .green
        }
    }

    /// Fixed conditions for each bed, shown on its card and at the top of the bed.
    var sunlight: String {
        switch self {
        case .desert: "10h sun"
        case .sunny:  "8h sun"
        case .shady:  "3h sun"
        }
    }

    var climate: String {
        switch self {
        case .desert: "Hot & dry"
        case .sunny:  "Warm"
        case .shady:  "Cool & damp"
        }
    }

    /// e.g. "Water every 12h", worked out from the real thirst timer.
    var wateringLabel: String {
        let hours = Int((GardenPlant.baseThirstInterval * thirstMultiplier / 3600).rounded())
        return "Water every \(hours)h"
    }

    /// How many plots each bed has (3 x 3).
    static let plotCount = 9

    var needs: String {
        switch self {
        case .desert: "Lots of sun, a little water, sandy soil"
        case .sunny:  "Full sun and regular water"
        case .shady:  "Some shade and damp soil"
        }
    }

    /// Desert plants get thirsty 3x more slowly. Shade keeps soil damp longer too.
    var thirstMultiplier: Double {
        switch self {
        case .desert: 3
        case .sunny:  1
        case .shady:  1.5
        }
    }

    var drySoil: Color {
        switch self {
        case .desert: Color(red: 0.88, green: 0.75, blue: 0.52)
        case .sunny:  Color.brown.opacity(0.88)
        case .shady:  Color(red: 0.36, green: 0.27, blue: 0.20)
        }
    }

    var wetSoil: Color {
        switch self {
        case .desert: Color(red: 0.74, green: 0.58, blue: 0.36)
        case .sunny:  Color.brown.opacity(0.62)
        case .shady:  Color(red: 0.27, green: 0.20, blue: 0.15)
        }
    }

    /// Light sand needs dark text; dark soil needs white text.
    var textOnSoil: Color { self == .desert ? Color(red: 0.35, green: 0.22, blue: 0.08) : .white }

    var emptyHint: String {
        switch self {
        case .desert: "Cacti and succulents will grow here."
        case .sunny:  "Sunflowers and sun-lovers will grow here."
        case .shady:  "Ferns and shade-lovers will grow here."
        }
    }

    var notThirstyTip: String {
        switch self {
        case .desert: "Careful! Desert plants don't like too much water. Soggy soil can rot their roots."
        case .sunny:  "The Sunny Bed has enough water right now."
        case .shady:  "Shade keeps soil damp. The Shady Corner doesn't need water yet."
        }
    }

    /// Sunflowers and cacti always go to their own beds.
    /// For everything else, we use the bed the AI picked from the plant's needs.
    static func from(kind: PlantKind, info: PlantInfo?) -> GardenPlot {
        switch kind {
        case .cactus:    return .desert
        case .sunflower: return .sunny
        case .standard:  return info?.gardenPlot.flatMap(GardenPlot.init(rawValue:)) ?? .sunny
        }
    }
}

// MARK: - Garden plant

@Model
final class GardenPlant {
    /// How long until a plant is thirsty again (before the bed's multiplier).
    /// 60 * 60 * 12 for twice a day.
    static let baseThirstInterval: TimeInterval = 60 * 60 * 12
    static let maxGrowth = 3

    var name: String
    var kindRaw: String
    var plotRaw: String = ""
    var growth: Int
    var timesWatered: Int
    var lastWatered: Date?
    var datePlanted: Date
    /// Which of the bed's 9 plots it's in (0 = top left, 8 = bottom right).
    /// -1 for plants planted before kids could pick a plot; they fill the first free plots.
    var slot: Int = -1

    // Bugs (the rules are in Bugs.swift)
    /// When a caterpillar moved onto this plant. nil = no caterpillar.
    var caterpillarSince: Date? = nil
    /// When the last caterpillar was moved away. Chewed leaves grow back a day later.
    var caterpillarGoneAt: Date? = nil
    /// How chewed the leaves are: 0 = fine, 3 = lots of holes.
    var leafHoles: Int = 0
    /// Chewed plants need two drinks to grow a stage. True after the first one.
    var halfGrown: Bool = false
    /// A ladybug guards the plant until this time.
    var ladybugUntil: Date? = nil
    /// A bee or butterfly sitting on its flowers (a BugKind raw value), until `pollinatorUntil`.
    var pollinatorRaw: String = ""
    var pollinatorUntil: Date? = nil
    /// The last time a bee or butterfly pollinated its flowers.
    var lastPollinated: Date? = nil
    /// Pollinated plants grow an extra stage on their next drink.
    var pollenBoost: Bool = false
    /// When the garden next rolls the dice for a caterpillar on this plant.
    var nextBugRoll: Date? = nil
    var timesPollinated: Int = 0
    var caterpillarsMoved: Int = 0

    init(name: String, kind: PlantKind, plot: GardenPlot, slot: Int = -1, datePlanted: Date = .now) {
        self.name = name
        self.kindRaw = kind.rawValue
        self.plotRaw = plot.rawValue
        self.slot = slot
        self.growth = 0
        self.timesWatered = 0
        self.lastWatered = nil
        self.datePlanted = datePlanted
    }

    var kind: PlantKind { PlantKind(rawValue: kindRaw) ?? .standard }

    /// Plants saved before beds existed fall back to a bed based on their kind.
    var plot: GardenPlot { GardenPlot(rawValue: plotRaw) ?? .from(kind: kind, info: nil) }

    var thirstInterval: TimeInterval { Self.baseThirstInterval * plot.thirstMultiplier }

    var stageName: String {
        ["Seedling", "Sprout", "Growing", "Fully grown"][min(growth, Self.maxGrowth)]
    }

    func isThirsty(at date: Date = .now) -> Bool {
        guard let lastWatered else { return true }
        return date.timeIntervalSince(lastWatered) > thirstInterval
    }

    enum WaterResult {
        case grew        // one stage
        case grewExtra   // two stages, thanks to pollinated flowers
        case slowed      // chewed leaves: halfway there, needs another drink
        case happy       // wasn't thirsty, or already fully grown
    }

    /// Watering a thirsty plant makes it grow one stage.
    /// Chewed leaves slow it down to one stage every two drinks.
    @discardableResult
    func water(at date: Date = .now) -> WaterResult {
        defer {
            lastWatered = date
            timesWatered += 1
        }
        guard isThirsty(at: date), growth < Self.maxGrowth else { return .happy }
        if leafHoles > 0 && !halfGrown {
            halfGrown = true
            return .slowed
        }
        halfGrown = false
        if pollenBoost && growth + 2 <= Self.maxGrowth {
            pollenBoost = false
            growth += 2
            return .grewExtra
        }
        pollenBoost = false
        growth += 1
        return .grew
    }

    /// Lays one bed's plants out in its plots. Index = plot number, nil = open plot.
    /// Plants that picked a plot keep it; older plants fill the first free plots.
    /// Always at least 9 long; a bed with more than 9 plants gets extra plots on the end.
    static func arrange(_ plants: [GardenPlant]) -> [GardenPlant?] {
        var plots = [GardenPlant?](repeating: nil, count: GardenPlot.plotCount)
        var unplaced: [GardenPlant] = []
        for plant in plants {
            if plots.indices.contains(plant.slot), plots[plant.slot] == nil {
                plots[plant.slot] = plant
            } else {
                unplaced.append(plant)
            }
        }
        for plant in unplaced {
            if let free = plots.firstIndex(where: { $0 == nil }) {
                plots[free] = plant
            } else {
                plots.append(plant)
            }
        }
        return plots
    }
}
