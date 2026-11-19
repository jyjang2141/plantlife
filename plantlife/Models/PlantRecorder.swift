//
//  PlantRecorder.swift
//  plantlife
//
//  Saves a scan to the Journal, and later plants it in the Garden.
//

import SwiftData
import UIKit

// MARK: - Saving a scan

enum PlantRecorder {
    /// Saves a scan to the Journal. It isn't in the Garden yet: the kid guesses its bed on the
    /// Journal page, picks a plot, and plants it themselves (see `PlantingView`).
    @MainActor @discardableResult
    static func record(info: PlantInfo, image: UIImage, in context: ModelContext) -> JournalEntry {
        let rawName = info.commonName ?? ""
        let name = rawName.isEmpty ? "Mystery plant" : rawName

        let entry = JournalEntry(
            name: name,
            photoData: image.resizedForUpload(maxDimension: 1600).jpegData(compressionQuality: 0.8),
            infoData: (try? JSONEncoder().encode(info)) ?? Data()
        )
        context.insert(entry)
        try? context.save()
        return entry
    }

    /// Puts a Journal plant into one plot of a garden bed, just watered.
    @MainActor @discardableResult
    static func plant(_ entry: JournalEntry, in bed: GardenPlot, slot: Int, position: CGPoint? = nil,
                      placementSize: CGSize? = nil, context: ModelContext) -> Bool {
        guard !entry.plantedInGarden else { return false }
        guard let existing = try? context.fetch(FetchDescriptor<GardenPlant>()) else { return false }
        let residents = existing.filter { $0.plot == bed }
        guard residents.count < GardenPlot.plotCount else { return false }
        if let position {
            guard GardenLayout.isAllowed(position, bed: bed,
                                         occupied: GardenLayout.positions(residents, size: placementSize ?? GardenLayout.referenceSize),
                                         size: placementSize ?? GardenLayout.referenceSize) else { return false }
        }
        let info = entry.info
        let plant = GardenPlant(name: entry.name,
                                species: info.map(PlantSpecies.match) ?? .other,
                                plot: bed,
                                slot: slot,
                                flowerColor: info?.flowerColor.flatMap(FlowerColor.init(rawValue:)),
                                canFlower: info?.flowers ?? false)
        // The planting activity ends with a drink, so it starts out happy (still a seedling).
        plant.lastWatered = .now
        if let position {
            plant.gardenX = position.x
            plant.gardenY = position.y
        }
        plant.timesWatered = 1
        context.insert(plant)
        entry.plantedInGarden = true
        do { try context.save(); return true }
        catch {
            context.delete(plant)
            entry.plantedInGarden = false
            return false
        }
    }
}
