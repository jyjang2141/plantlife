//
//  JournalView.swift
//  plantlife
//
//  The Journal tab: a searchable list of every plant you've scanned.
//

import SwiftUI
import SwiftData

// MARK: - Journal: every plant you've ever scanned

struct JournalView: View {
    @Binding var selectedTab: Int

    @Environment(\.modelContext) private var context
    @Query(sort: \JournalEntry.dateFound, order: .reverse) private var entries: [JournalEntry]
    @State private var searchText = ""
    @State private var favoritesOnly = false

    private var filtered: [JournalEntry] {
        entries.filter { entry in
            (!favoritesOnly || entry.isFavorite) &&
            (searchText.isEmpty || entry.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView {
                        Label("Your journal is empty", systemImage: "book.closed")
                    } description: {
                        Text("Every plant you scan on Discover is saved here.")
                    } actions: {
                        Button("Scan a plant") { selectedTab = 1 }
                            .buttonStyle(.borderedProminent).tint(.green)
                    }
                } else {
                    List {
                        Section {
                            ForEach(filtered) { entry in
                                NavigationLink {
                                    JournalEntryDetailView(entry: entry)
                                } label: {
                                    JournalRow(entry: entry)
                                }
                            }
                            .onDelete(perform: delete)
                        } header: {
                            Text(entries.count == 1 ? "You've found 1 plant" : "You've found \(entries.count) plants")
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search your plants")
                    .overlay {
                        if filtered.isEmpty {
                            if searchText.isEmpty {
                                ContentUnavailableView("No favorites yet", systemImage: "heart",
                                    description: Text("Tap the heart on a plant's page to add it here."))
                            } else {
                                ContentUnavailableView.search(text: searchText)
                            }
                        }
                    }
                    .toolbar {
                        Button {
                            withAnimation { favoritesOnly.toggle() }
                        } label: {
                            Image(systemName: favoritesOnly ? "heart.fill" : "heart")
                                .foregroundStyle(favoritesOnly ? .pink : .primary)
                        }
                        .accessibilityLabel(favoritesOnly ? "Show all plants" : "Show favorites only")
                    }
                }
            }
            .navigationTitle("My Journal")
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { context.delete(filtered[index]) }
    }
}

// MARK: - Row

private struct JournalRow: View {
    let entry: JournalEntry

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let image = entry.image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Text("🌱").font(.title)
                }
            }
            .frame(width: 62, height: 62)
            .background(Color.green.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.name).font(.headline)
                    if entry.isFavorite {
                        Image(systemName: "heart.fill").font(.caption).foregroundStyle(.pink)
                    }
                }
                if let scientific = entry.info?.scientificName, !scientific.isEmpty {
                    Text(scientific)
                        .font(.subheadline.italic())
                        .foregroundStyle(.secondary)
                }
                Text(entry.dateFound, format: .dateTime.month().day().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
