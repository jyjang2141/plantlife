//
//  JournalEntryDetailView.swift
//  plantlife
//
//  One plant's full journal page: photo, facts, notes, favorite.
//

import SwiftUI
import SwiftData

// MARK: - One plant's journal page (used by Discover, Journal, and Garden)

struct JournalEntryDetailView: View {
    @Bindable var entry: JournalEntry

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let image = entry.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }

                Text("Found on \(entry.dateFound.formatted(date: .long, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let info = entry.info {
                    PlantResultView(info: info)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label("My notes", systemImage: "pencil")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Theme.leaf)
                    TextField("Where did you find it? What did it look or smell like?",
                              text: $entry.notes, axis: .vertical)
                        .lineLimit(3...8)
                        .font(.system(.body, design: .rounded))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Theme.card)
                .clipShape(Theme.cardShape)
            }
            .padding(20)
        }
        .background(Theme.background)
        .navigationTitle(entry.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                entry.isFavorite.toggle()
            } label: {
                Image(systemName: entry.isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(entry.isFavorite ? .pink : .primary)
            }
            .accessibilityLabel(entry.isFavorite ? "Remove from favorites" : "Add to favorites")
        }
    }
}
