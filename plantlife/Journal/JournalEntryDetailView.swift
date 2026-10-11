import SwiftUI
import SwiftData

struct JournalEntryDetailView: View {
    @Bindable var entry: JournalEntry
    @Environment(\.modelContext) private var context
    @State private var page = 0
    @State private var saveFailed = false

    var body: some View {
        VStack(spacing: 0) {
            Text(page == 0 ? "My observations • Swipe left for the overview" : "Plant overview • Swipe right for your answers")
                .font(.subheadline).foregroundStyle(.secondary).padding(12)
            TabView(selection: $page) {
                questionsPage.tag(0)
                overviewPage.tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            HStack(spacing: 16) {
                Button("My observations") { page = 0 }
                    .fontWeight(page == 0 ? .bold : .regular)
                Button("Plant overview") { page = 1 }
                    .fontWeight(page == 1 ? .bold : .regular)
            }
            .padding(12)
        }
        .background(Theme.background)
        .navigationTitle(entry.name)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: page) { _, _ in saveAnswers() }
        .onDisappear { saveAnswers() }
        .alert("Your answers couldn't be saved yet", isPresented: $saveFailed) {
            Button("Try again") { saveAnswers() }
        } message: { Text("Please try saving again.") }
        .toolbar {
            Button { entry.isFavorite.toggle() } label: {
                Image(systemName: entry.isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(entry.isFavorite ? .pink : .primary)
            }
            .accessibilityLabel(entry.isFavorite ? "Remove from favorites" : "Add to favorites")
        }
    }

    private var questionsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Let's look closely!").font(.title2.bold())
                Text("Tell us what you notice. It's okay to wonder!")
                    .foregroundStyle(.secondary)
                photo
                question(JournalPrompts.observations[0], answer: $entry.plantTypeAnswer, hint: "I think it is…")
                question(JournalPrompts.observations[1], answer: $entry.plantSizeAnswer, hint: "Tiny, tall, or somewhere in between…")
                question(JournalPrompts.observations[2], answer: $entry.plantAppearanceAnswer, hint: "I see these colors and shapes…")
                question(JournalPrompts.observations[3], answer: $entry.plantLocationAnswer, hint: "I found it…")
                Text("A few words are enough. You can come back later!")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("See the plant overview →") {
                    saveAnswers()
                    withAnimation { page = 1 }
                }
                .buttonStyle(.borderedProminent).tint(Theme.leaf)
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
