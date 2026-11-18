//
//  GardenPlant.swift
//  plantlife
//
//  A plant in the Garden, which bed it lives in, and how it looks.
//

import Foundation
import SwiftData
import SwiftUI

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

    /// Freshly dug dirt (the pile beside the hole, and the mound over the seed):
    /// a few shades darker than each bed's own soil so it stands out.
    var dugSoil: Color {
        switch self {
        case .desert: Color(red: 0.68, green: 0.52, blue: 0.30)
        case .sunny:  Color(red: 0.45, green: 0.31, blue: 0.19)
        case .shady:  Color(red: 0.16, green: 0.10, blue: 0.06)
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

    /// Some plants always go in the same bed (see `PlantSpecies.terrain`).
    /// For everything else, we use the bed the AI picked from the plant's needs.
    static func from(species: PlantSpecies, info: PlantInfo?) -> GardenPlot {
        species.terrain ?? info?.gardenPlot.flatMap(GardenPlot.init(rawValue:)) ?? .sunny
    }
}

// MARK: - Garden plant

@Model
final class GardenPlant {
    /// How long until a plant is thirsty again (before the bed's multiplier).
    /// 60 * 60 * 12 for twice a day.
    static let baseThirstInterval: TimeInterval = 60 * 60 * 12

    /// The plant's common name from the Journal ("Sunflower"). Also links it back to its Journal page.
    var name: String
    /// A name the kid gave their plant ("Sunny"). "" = no nickname yet.
    var nickname: String = ""
    /// The `PlantSpecies` raw value (named before the icon database existed).
    var kindRaw: String
    var plotRaw: String = ""
    var growth: Int
    var timesWatered: Int
    var lastWatered: Date?
    var datePlanted: Date
    /// The flower color the AI saw in the photo ("" if none).
    var flowerColorRaw: String = ""
    /// Whether a default plant gets budding and flowering stages.
    var canFlower: Bool = false
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

    init(name: String, species: PlantSpecies, plot: GardenPlot, slot: Int = -1, flowerColor: FlowerColor? = nil,
         canFlower: Bool = false, datePlanted: Date = .now) {
        self.name = name
        self.kindRaw = species.rawValue
        self.plotRaw = plot.rawValue
        self.slot = slot
        self.flowerColorRaw = flowerColor?.rawValue ?? ""
        self.canFlower = canFlower
        self.growth = 0
        self.timesWatered = 0
        self.lastWatered = nil
        self.datePlanted = datePlanted
    }

    var species: PlantSpecies { PlantSpecies(rawValue: kindRaw) ?? .other }

    /// The kid's nickname if they gave one, otherwise the plant's common name.
    var displayName: String {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? name : trimmed
    }

    /// True when the plant has a nickname, so screens can also show what kind of plant it is.
    var hasNickname: Bool { displayName != name }

    /// Plants saved before beds existed fall back to a bed based on their species.
    var plot: GardenPlot { GardenPlot(rawValue: plotRaw) ?? .from(species: species, info: nil) }

    /// Every stage this plant will grow through, in order.
    var stages: [GrowthStage] { species.stages(canFlower: canFlower) }

    /// Each watering of a thirsty plant moves it one stage along, up to its last stage.
    var maxGrowth: Int { stages.count - 1 }

    var stage: GrowthStage { stages[min(growth, maxGrowth)] }

    /// The photo's flower color for plants that match it; the classic color otherwise.
    var flowerColor: FlowerColor {
        guard species.matchesPhotoFlowerColor, let color = FlowerColor(rawValue: flowerColorRaw) else {
            return species.classicFlowerColor
        }
        return color
    }

    var thirstInterval: TimeInterval { Self.baseThirstInterval * plot.thirstMultiplier }

    var stageName: String { stage.title }

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
        guard isThirsty(at: date), growth < maxGrowth else { return .happy }
        if leafHoles > 0 && !halfGrown {
            halfGrown = true
            return .slowed
        }
        halfGrown = false
        if pollenBoost && growth + 2 <= maxGrowth {
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
