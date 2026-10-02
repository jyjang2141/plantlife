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
    }

    var info: PlantInfo? { try? JSONDecoder().decode(PlantInfo.self, from: infoData) }
    var image: UIImage? { photoData.flatMap(UIImage.init(data:)) }
}
