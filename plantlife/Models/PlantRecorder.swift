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
    @MainActor
    static func plant(_ entry: JournalEntry, in bed: GardenPlot, slot: Int, context: ModelContext) {
        guard !entry.plantedInGarden else { return }
        let kind = entry.info.map(PlantKind.from(info:)) ?? .standard
        let plant = GardenPlant(name: entry.name, kind: kind, plot: bed, slot: slot)
        // The planting activity ends with a drink, so it starts out happy (still a seedling).
        plant.lastWatered = .now
        plant.timesWatered = 1
        context.insert(plant)
        entry.plantedInGarden = true
        try? context.save()
    }
}
