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
    @Binding var path: [JournalEntry]

    @Environment(\.modelContext) private var context
    @Query(sort: \JournalEntry.dateFound, order: .reverse) private var entries: [JournalEntry]
    @State private var searchText = ""
    @State private var favoritesOnly = false
    @State private var showComparison = false

    private var filtered: [JournalEntry] {
        entries.filter { entry in
            (!favoritesOnly || entry.isFavorite) &&
            (searchText.isEmpty || (entry.observationsCompleted && entry.name.localizedCaseInsensitiveContains(searchText)))
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
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
                        if entries.count > 5 {
                            Section {
                                Button {
                                    showComparison = true
                                } label: {
                                    Label("Wonder about your plants", systemImage: "bubble.left.and.bubble.right")
                                }
                            } footer: {
                                Text("An optional question to explore together.")
                            }
                        }
                        Section {
                            ForEach(filtered) { entry in
                                NavigationLink(value: entry) {
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
            .navigationDestination(for: JournalEntry.self) { entry in
                JournalEntryDetailView(entry: entry)
            }
            .sheet(isPresented: $showComparison) {
                JournalComparisonView(entries: entries)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { context.delete(filtered[index]) }
    }
}

private struct JournalComparisonView: View {
    let entries: [JournalEntry]
    @Environment(\.dismiss) private var dismiss
    @AppStorage("journal.nextComparisonPrompt") private var nextPrompt = 0
    @AppStorage("journal.comparisonAnswers") private var savedAnswers = "{}"
    @State private var promptIndex = 0
    @State private var firstPlant = 0
    @State private var secondPlant = 1
    @State private var answer = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(JournalPrompts.comparisons[promptIndex]).font(.title2.bold())
                    Text("Choose plants from your journal and look for clues.")
                        .foregroundStyle(.secondary)
                    Picker("First plant", selection: $firstPlant) {
                        ForEach(entries.indices, id: \.self) { index in
                            Text(entries[index].name).tag(index)
                        }
                    }
                    Picker("Second plant", selection: $secondPlant) {
                        ForEach(entries.indices, id: \.self) { index in
                            Text(entries[index].name).tag(index)
                        }
                    }
                    HStack {
                        JournalRow(entry: entries[firstPlant])
                        JournalRow(entry: entries[secondPlant])
                    }
                    TextField("What do you notice?", text: $answer, axis: .vertical)
                        .lineLimit(3...8).textFieldStyle(.roundedBorder)
                    Button("Save my thoughts") {
                        var answers = (try? JSONDecoder().decode([String: String].self, from: Data(savedAnswers.utf8))) ?? [:]
                        answers[String(promptIndex)] = answer
                        if let data = try? JSONEncoder().encode(answers), let string = String(data: data, encoding: .utf8) {
                            savedAnswers = string
                        }
                        nextPrompt = (promptIndex + 1) % JournalPrompts.comparisons.count
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent).disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Skip for now") {
                        nextPrompt = (promptIndex + 1) % JournalPrompts.comparisons.count
                        dismiss()
                    }
                }
                .padding()
            }
            .navigationTitle("Plant wonders")
            .toolbar { Button("Close") { dismiss() } }
            .onAppear {
                promptIndex = nextPrompt % JournalPrompts.comparisons.count
                let answers = (try? JSONDecoder().decode([String: String].self, from: Data(savedAnswers.utf8))) ?? [:]
                answer = answers[String(promptIndex)] ?? ""
            }
        }
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
                    Text(entry.observationsCompleted ? entry.name : "Mystery plant").font(.headline)
                    if entry.isFavorite {
                        Image(systemName: "heart.fill").font(.caption).foregroundStyle(.pink)
                    }
                }
                if !entry.observationsCompleted {
                    Text("Answer the questions to reveal it!")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                } else if let scientific = entry.info?.scientificName, !scientific.isEmpty {
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
