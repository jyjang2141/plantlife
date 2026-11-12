//
//  PlantIcons.swift
//  plantlife
//
//  Looks up the drawing for any plant at any growth stage.
//

import SwiftUI

enum PlantIcons {
    /// Draws `species` at `stage` into an 80 x 80 box. `flowerColor` tints the flowers of
    /// plants that have them (plants without flowers ignore it).
    static func draw(_ species: PlantSpecies, _ stage: GrowthStage, flowerColor: FlowerColor, in g: GraphicsContext) {
        switch species {
        case .daisy:       FlowerIcons.daisy(stage, flowerColor, g)
        case .sunflower:   FlowerIcons.sunflower(stage, g)
        case .cactus:      FlowerIcons.cactus(stage, flowerColor, g)
        case .tulip:       FlowerIcons.tulip(stage, flowerColor, g)
        case .rose:        FlowerIcons.rose(stage, flowerColor, g)
        case .poppy:       FlowerIcons.poppy(stage, flowerColor, g)
        case .orchid:      FlowerIcons.orchid(stage, flowerColor, g)
        case .corn:        FoodIcons.corn(stage, g)
        case .tomato:      FoodIcons.tomato(stage, g)
        case .cucumber:    FoodIcons.cucumber(stage, g)
        case .pumpkin:     FoodIcons.pumpkin(stage, g)
        case .strawberry:  FoodIcons.strawberry(stage, g)
        case .oak:         TreeIcons.oak(stage, g)
        case .maple:       TreeIcons.maple(stage, g)
        case .pine:        TreeIcons.pine(stage, g)
        case .coconutPalm: TreeIcons.coconutPalm(stage, g)
        case .fern:        OtherIcons.fern(stage, g)
        case .grass:       OtherIcons.grass(stage, g)
        case .succulent:   OtherIcons.succulent(stage, g)
        case .basil:       OtherIcons.basil(stage, flowerColor, g)
        case .bush:        OtherIcons.bush(stage, g)
        case .other:       OtherIcons.defaultPlant(stage, flowerColor, g)
        }
    }

    /// The withered plant shown when any plant dies.
    static func drawDead(in g: GraphicsContext) {
        OtherIcons.dead(g)
    }
}

// MARK: - Catalog preview

/// Every icon at every stage, for checking the drawings in Xcode's canvas.
struct PlantIconCatalog: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(PlantSpecies.allCases, id: \.self) { species in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(species.name).font(.headline)
                        ScrollView(.horizontal) {
                            HStack(spacing: 10) {
                                ForEach(species.stages(canFlower: true), id: \.self) { stage in
                                    cell(stage.title) {
                                        PlantSprite(species: species, stage: stage,
                                                    flowerColor: species.classicFlowerColor, size: 72)
                                    }
                                }
                            }
                        }
                    }
                }
                Text("Dead").font(.headline)
                cell("Any plant") { PlantSprite(species: .other, stage: .vegetating, dead: true, size: 72) }
            }
            .padding()
        }
        .background(Theme.background)
    }

    private func cell(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 4) {
            content()
                .padding(6)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

#Preview("Icon catalog") {
    PlantIconCatalog()
}
