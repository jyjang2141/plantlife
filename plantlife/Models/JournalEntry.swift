//
//  JournalEntry.swift
//  plantlife
//
//  A saved scan in the Journal: photo, AI facts, notes, favorite.
//

import Foundation
import SwiftData
import UIKit

// MARK: - Journal entry (one scanned plant, saved forever)

@Model
final class JournalEntry {
    var name: String
    var dateFound: Date
    var notes: String
    var isFavorite: Bool
    var observationPromptIndex: Int = -1
    var observationAnswer: String = ""
    var observationSkipped: Bool = false
    var plantTypeAnswer: String = ""
    var plantSizeAnswer: String = ""
    var plantAppearanceAnswer: String = ""
    var plantLocationAnswer: String = ""
    /// The garden bed the kid guessed (a `GardenPlot` raw value), empty until they pick one.
    var terrainAnswer: String = ""
    /// True once the kid has answered the observation questions and seen the plant revealed.
    var observationsCompleted: Bool = false
    /// True once the kid has dug, seeded, covered and watered this plant into the Garden.
    /// Defaults to true so plants saved before this existed (already in the Garden) aren't planted twice;
    /// new scans set it to false in init.
    var plantedInGarden: Bool = true
    @Attribute(.externalStorage) var photoData: Data?
    /// The full AI answer (fun fact, needs, dangers...) saved as JSON.
    var infoData: Data

    init(name: String, photoData: Data?, infoData: Data, dateFound: Date = .now) {
        self.name = name
        self.photoData = photoData
        self.infoData = infoData
        self.dateFound = dateFound
        self.notes = ""
        self.isFavorite = false
        self.plantedInGarden = false
    }

    var info: PlantInfo? { try? JSONDecoder().decode(PlantInfo.self, from: infoData) }
    var image: UIImage? { photoData.flatMap(UIImage.init(data:)) }

    var terrainGuess: GardenPlot? { GardenPlot(rawValue: terrainAnswer) }

    /// The bed this plant really belongs in: the same rule PlantRecorder uses to plant it.
    var correctTerrain: GardenPlot? {
        guard let info else { return nil }
        return GardenPlot.from(kind: PlantKind.from(info: info), info: info)
    }
}
