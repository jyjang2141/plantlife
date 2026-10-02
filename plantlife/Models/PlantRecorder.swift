//
//  PlantRecorder.swift
//  plantlife
//
//  Saves a scan to the Journal and plants it in the Garden.
//

import SwiftData
import UIKit

// MARK: - Saving a scan

enum PlantRecorder {
    /// Saves a scan to the Journal AND plants it in the right garden bed.
    @MainActor @discardableResult
    static func record(info: PlantInfo, image: UIImage, in context: ModelContext) -> JournalEntry {
        let rawName = info.commonName ?? ""
        let name = rawName.isEmpty ? "Mystery plant" : rawName

        let entry = JournalEntry(
            name: name,
            photoData: image.resizedForUpload(maxDimension: 1600).jpegData(compressionQuality: 0.8),
            infoData: (try? JSONEncoder().encode(info)) ?? Data()
        )
        let kind = PlantKind.from(info: info)
        context.insert(entry)
        context.insert(GardenPlant(name: name, kind: kind, plot: .from(kind: kind, info: info)))
        try? context.save()
        return entry
    }
}
