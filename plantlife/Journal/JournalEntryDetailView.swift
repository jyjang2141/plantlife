import SwiftUI
import SwiftData

/// A plant's Journal page. The first time it opens, the kid answers the
/// observation questions and only then is the plant revealed. After that the
/// page just shows the plant along with their saved answers.
struct JournalEntryDetailView: View {
    @Bindable var entry: JournalEntry
    @Environment(\.modelContext) private var context
    @State private var saveFailed = false

    var body: some View {
        Group {
            if entry.observationsCompleted {
                overviewPage
            } else {
                questionsPage
            }
        }
        .background(Theme.background)
        .navigationTitle(entry.observationsCompleted ? entry.name : "New plant")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { saveAnswers() }
        .alert("Your answers couldn't be saved yet", isPresented: $saveFailed) {
            Button("Try again") { saveAnswers() }
        } message: { Text("Please try saving again.") }
        .toolbar {
            if entry.observationsCompleted {
                Button { entry.isFavorite.toggle() } label: {
                    Image(systemName: entry.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(entry.isFavorite ? .pink : .primary)
                }
                .accessibilityLabel(entry.isFavorite ? "Remove from favorites" : "Add to favorites")
            }
        }
    }

    private var questionsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Let's look closely!").font(.title2.bold())
                Text("Tell us what you notice. Then we'll reveal your plant!")
                    .foregroundStyle(.secondary)
                photo
                question(JournalPrompts.observations[0], answer: $entry.plantTypeAnswer, hint: "I think it is…")
                question(JournalPrompts.observations[1], answer: $entry.plantSizeAnswer, hint: "Tiny, tall, or somewhere in between…")
                question(JournalPrompts.observations[2], answer: $entry.plantAppearanceAnswer, hint: "I see these colors and shapes…")
                question(JournalPrompts.observations[3], answer: $entry.plantLocationAnswer, hint: "I found it…")
                terrainQuestion
                Text("A few words are enough!")
                    .font(.footnote).foregroundStyle(.secondary)
                Button {
                    withAnimation { entry.observationsCompleted = true }
                    saveAnswers()
                } label: {
                    Label("Reveal my plant!", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(Theme.leaf)
                .disabled(entry.terrainGuess == nil)
                if entry.terrainGuess == nil {
                    Text("Pick a terrain to reveal your plant.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var overviewPage: some View {
        ScrollView {
            VStack(spacing: 16) {
                photo
                Text("Found on " + entry.dateFound.formatted(date: .long, time: .shortened))
                    .font(.footnote).foregroundStyle(.secondary)
                if let info = entry.info { PlantResultView(info: info) }
                terrainFeedback
                observationsCard
                if !entry.observationAnswer.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("My earlier observation").font(.headline)
                        Text(entry.observationAnswer)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.card).clipShape(Theme.cardShape)
                }
                question("My notes", answer: $entry.notes, hint: "Anything else you want to remember?")
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    /// The kid's answers from before the reveal, shown read-only.
    private var observationsCard: some View {
        let answers = [entry.plantTypeAnswer, entry.plantSizeAnswer, entry.plantAppearanceAnswer, entry.plantLocationAnswer,
                       entry.terrainGuess?.title ?? ""]
        return VStack(alignment: .leading, spacing: 14) {
            Label("My observations", systemImage: "magnifyingglass")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Theme.leaf)
            ForEach(Array(zip(JournalPrompts.observations + [JournalPrompts.terrain], answers)), id: \.0) { prompt, answer in
                VStack(alignment: .leading, spacing: 4) {
                    Text(prompt)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    Text(answer.isEmpty ? "No answer" : answer)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(answer.isEmpty ? .secondary : .primary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card).clipShape(Theme.cardShape)
    }

    // MARK: Terrain question

    /// Multiple choice: one button per garden bed.
    private var terrainQuestion: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(JournalPrompts.terrain).font(.system(.headline, design: .rounded))
            ForEach(GardenPlot.allCases) { plot in
                let selected = entry.terrainGuess == plot
                Button {
                    entry.terrainAnswer = plot.rawValue
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: plot.symbol)
                            .font(.title2).foregroundStyle(plot.tint)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plot.title)
                                .font(.system(.body, design: .rounded, weight: .semibold))
                            Text(plot.needs)
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(selected ? Theme.leaf : .secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(selected ? Theme.leaf.opacity(0.12) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(selected ? Theme.leaf : Color.secondary.opacity(0.3), lineWidth: selected ? 2 : 1))
                    .contentShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card).clipShape(Theme.cardShape)
    }

    /// After the reveal: tells the kid if their terrain guess was right, and if not, why.
    @ViewBuilder private var terrainFeedback: some View {
        if let guess = entry.terrainGuess, let correct = entry.correctTerrain {
            let isRight = guess == correct
            VStack(alignment: .leading, spacing: 10) {
                Label(isRight ? "You got the terrain right!" : "Not quite the right terrain",
                      systemImage: isRight ? "checkmark.seal.fill" : "arrow.triangle.2.circlepath")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(isRight ? Theme.leaf : Theme.alert)
                ForEach(terrainFeedbackLines(guess: guess, correct: correct), id: \.self) { line in
                    Text(line).font(.system(.body, design: .rounded))
                }
                Label("\(entry.name) is growing in the \(correct.title) in your garden.", systemImage: correct.symbol)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(correct.tint)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card).clipShape(Theme.cardShape)
        }
    }

    private func terrainFeedbackLines(guess: GardenPlot, correct: GardenPlot) -> [String] {
        let needs = entry.info?.needs
        let plantNeeds = [needs?.sunlight, needs?.water].compactMap { $0?.isEmpty == false ? $0 : nil }
        var lines: [String] = []
        if guess == correct {
            lines.append("You picked the \(correct.title). That's where \(entry.name) belongs!")
        } else {
            lines.append("You picked the \(guess.title). That bed is for plants that need \(guess.needs.lowercased()). "
                         + "\(entry.name) needs something different.")
        }
        if !plantNeeds.isEmpty {
            lines.append(plantNeeds.joined(separator: " "))
        }
        if guess != correct {
            lines.append("That's why it grows best in the \(correct.title): \(correct.needs.lowercased()).")
        }
        return lines
    }

    @ViewBuilder private var photo: some View {
        if let image = entry.image {
            Image(uiImage: image)
                .resizable().scaledToFill()
                .frame(height: 200).frame(maxWidth: .infinity).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 22))
        }
    }

    private func question(_ title: String, answer: Binding<String>, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(.headline, design: .rounded))
            TextField(hint, text: answer, axis: .vertical)
                .lineLimit(2...5).font(.system(.body, design: .rounded))
                .textFieldStyle(.roundedBorder).accessibilityLabel(title)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card).clipShape(Theme.cardShape)
    }

    private func saveAnswers() {
        do { try context.save() }
        catch { saveFailed = true }
    }
}
