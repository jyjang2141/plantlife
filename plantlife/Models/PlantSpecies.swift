//
//  PlantSpecies.swift
//  plantlife
//
//  The icon database: every plant with a built-in icon, which growth stages it has,
//  and which bed it belongs in. The drawings themselves live in Garden/Icons.
//

import SwiftUI

// MARK: - Growth stages

/// The stages a plant can grow through, in order. Each plant only uses the ones that make sense for it.
enum GrowthStage: String, CaseIterable, Codable {
    case sprout, seedling, vegetating, budding, flowering, ripening

    var title: String { rawValue.capitalized }
}

// MARK: - Flower colors

/// Flower colors the AI can report. Flowers are tinted to match the plant the student photographed.
enum FlowerColor: String, CaseIterable, Codable {
    case red, pink, orange, yellow, white, purple, blue

    /// The main petal color.
    var petal: Color {
        switch self {
        case .red:    Color(red: 0.90, green: 0.20, blue: 0.22)
        case .pink:   Color(red: 0.99, green: 0.50, blue: 0.65)
        case .orange: Color(red: 1.00, green: 0.58, blue: 0.15)
        case .yellow: Color(red: 1.00, green: 0.84, blue: 0.18)
        case .white:  Color(red: 0.99, green: 0.98, blue: 0.95)
        case .purple: Color(red: 0.68, green: 0.44, blue: 0.88)
        case .blue:   Color(red: 0.40, green: 0.58, blue: 0.96)
        }
    }

    /// A deeper shade for back petals and edges, so even white flowers stand out.
    var shade: Color {
        switch self {
        case .red:    Color(red: 0.70, green: 0.10, blue: 0.15)
        case .pink:   Color(red: 0.88, green: 0.30, blue: 0.48)
        case .orange: Color(red: 0.88, green: 0.40, blue: 0.05)
        case .yellow: Color(red: 0.90, green: 0.64, blue: 0.05)
        case .white:  Color(red: 0.82, green: 0.82, blue: 0.80)
        case .purple: Color(red: 0.48, green: 0.26, blue: 0.70)
        case .blue:   Color(red: 0.22, green: 0.38, blue: 0.80)
        }
    }
}

// MARK: - Plants with a built-in icon

/// Raw values are saved with each garden plant. `.other` keeps the old "standard" value
/// so plants saved before the icon database still load.
enum PlantSpecies: String, CaseIterable, Codable {
    // Plants
    case daisy, sunflower, cactus, tulip, rose, poppy, orchid
    // Vegetables & fruits
    case corn, tomato, cucumber, pumpkin, strawberry
    // Trees
    case oak, maple, pine, coconutPalm = "coconut_palm"
    // Other
    case fern, grass, succulent, basil, bush
    // Everything else uses the default plant icon.
    case other = "standard"

    var name: String {
        switch self {
        case .coconutPalm: "Coconut Palm"
        case .bush:        "Berry Bush"
        case .other:       "Default Plant"
        default:           rawValue.capitalized
        }
    }

    /// The growth stages this plant goes through, in order.
    /// `canFlower` only matters for `.other`: default plants flower only when the AI says they do.
    func stages(canFlower: Bool = false) -> [GrowthStage] {
        switch self {
        case .sunflower, .corn, .tomato, .cucumber, .pumpkin, .strawberry, .bush:
            [.sprout, .seedling, .vegetating, .budding, .flowering, .ripening]
        case .daisy, .tulip, .rose, .poppy, .orchid, .cactus, .basil:
            [.sprout, .seedling, .vegetating, .budding, .flowering]
        case .maple:
            [.sprout, .seedling, .vegetating, .flowering, .ripening]
        case .oak, .pine, .coconutPalm:
            [.sprout, .seedling, .vegetating, .ripening]
        case .fern, .grass, .succulent:
            [.sprout, .seedling, .vegetating]
        case .other:
            canFlower ? [.sprout, .seedling, .vegetating, .budding, .flowering]
                      : [.sprout, .seedling, .vegetating]
        }
    }

    /// The bed this plant always goes in. `nil` means use the bed the AI picked.
    var terrain: GardenPlot? {
        switch self {
        case .cactus, .succulent:
            .desert
        case .fern, .orchid:
            .shady
        case .sunflower, .corn, .tomato, .cucumber, .pumpkin, .strawberry:
            .sunny
        default:
            nil
        }
    }

    /// Whether the flowers are tinted to match the photo. Other plants always use their classic color.
    var matchesPhotoFlowerColor: Bool {
        switch self {
        case .daisy, .tulip, .rose, .poppy, .orchid, .other: true
        default: false
        }
    }

    /// The flower color used when the photo's color is unknown (or isn't matched).
    var classicFlowerColor: FlowerColor {
        switch self {
        case .daisy, .strawberry, .basil, .bush: .white
        case .tulip, .rose, .poppy:              .red
        case .orchid:                            .purple
        case .sunflower, .tomato, .cucumber, .pumpkin, .corn: .yellow
        case .cactus, .other:                    .pink
        default:                                 .white
        }
    }

    // MARK: Matching an identified plant to an icon

    /// Words (common or scientific names) that point to each icon.
    private var keywords: [String] {
        switch self {
        case .daisy:       ["daisy", "daisies", "bellis", "leucanthemum"]
        case .sunflower:   ["sunflower", "helianthus"]
        case .cactus:      ["cactus", "cacti", "cactaceae", "opuntia", "prickly pear", "saguaro", "carnegiea",
                            "echinocactus", "ferocactus", "mammillaria"]
        case .tulip:       ["tulip", "tulipa"]
        case .rose:        ["rose", "rosa"]
        case .poppy:       ["poppy", "poppies", "papaver", "eschscholzia"]
        case .orchid:      ["orchid", "orchidaceae", "phalaenopsis", "dendrobium", "cattleya"]
        case .corn:        ["corn", "maize", "zea"]
        case .tomato:      ["tomato", "tomatoes", "lycopersicum"]
        case .cucumber:    ["cucumber", "cucumis"]
        case .pumpkin:     ["pumpkin", "cucurbita", "squash"]
        case .strawberry:  ["strawberry", "strawberries", "fragaria"]
        case .oak:         ["oak", "quercus"]
        case .maple:       ["maple", "acer"]
        case .pine:        ["pine", "pinus"]
        case .coconutPalm: ["coconut", "cocos"]
        case .fern:        ["fern", "pteridophyta", "polypodiopsida", "nephrolepis", "maidenhair"]
        case .grass:       ["grass", "grasses", "poaceae", "lawn", "turfgrass"]
        case .succulent:   ["succulent", "echeveria", "crassula", "sedum", "aloe", "haworthia",
                            "sempervivum", "jade plant", "hens and chicks"]
        case .basil:       ["basil", "ocimum"]
        case .bush:        ["blueberry", "blueberries", "vaccinium", "raspberry", "blackberry", "rubus", "berry bush"]
        case .other:       []
        }
    }

    /// Names that contain a keyword but are a different plant (e.g. poison oak is not an oak).
    private static let lookalikes = [
        "poison oak", "moss rose", "desert rose", "rose of sharon", "flowering maple", "corn plant", "sea grass",
    ]

    /// Picks the icon for an identified plant. Uses the AI's pick when there is one,
    /// otherwise (for plants saved before the AI picked icons) matches on the plant's names.
    static func match(_ info: PlantInfo) -> PlantSpecies {
        if let pick = info.iconMatch, !pick.isEmpty {
            return pick == "other" ? .other : PlantSpecies(rawValue: pick) ?? .other
        }

        var text = " \(info.commonName ?? "") \(info.scientificName ?? "") ".lowercased()
        for lookalike in lookalikes { text = text.replacingOccurrences(of: lookalike, with: " ") }
        let words = Set(text.split { !$0.isLetter }.map(String.init))

        for species in allCases {
            for keyword in species.keywords {
                let found = keyword.contains(" ")
                    ? text.contains(keyword)
                    : words.contains(keyword) || words.contains(keyword + "s") || words.contains(keyword + "es")
                if found { return species }
            }
        }
        return .other
    }
}
