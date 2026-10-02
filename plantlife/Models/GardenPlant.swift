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

    init(name: String, kind: PlantKind, plot: GardenPlot, datePlanted: Date = .now) {
        self.name = name
        self.kindRaw = kind.rawValue
        self.plotRaw = plot.rawValue
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

    /// Watering a thirsty plant makes it grow one stage.
    func water(at date: Date = .now) {
        if isThirsty(at: date) && growth < Self.maxGrowth { growth += 1 }
        lastWatered = date
        timesWatered += 1
    }
}
