//
//  GardenPlantDetailView.swift
//  plantlife
//
//  The card that slides up when you tap a plant in the Garden.
//

import SwiftUI
import SwiftData

// MARK: - What you see when you tap a plant in the garden

struct GardenPlantDetailView: View {
    let plant: GardenPlant
    let onRemove: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Query private var journalEntries: [JournalEntry]
    @State private var confirmRemove = false

    /// The journal page saved at the same moment this plant was planted.
    private var journalEntry: JournalEntry? {
        journalEntries
            .filter { $0.name == plant.name }
            .min { abs($0.dateFound.timeIntervalSince(plant.datePlanted)) < abs($1.dateFound.timeIntervalSince(plant.datePlanted)) }
    }

    var body: some View {
        NavigationStack {
            // Ticks every second so the "thirsty in…" countdown stays live.
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                ScrollView {
                    VStack(spacing: 18) {
                        header(now: timeline.date)
                        growthCard
                        if let needs = journalEntry?.info?.needs { needsCard(needs) }
                        statsCard
                        actions
                    }
                    .padding(20)
                }
            }
            .background(Theme.background)
            .navigationTitle(plant.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Remove \(plant.name) from your garden?",
                                isPresented: $confirmRemove, titleVisibility: .visible) {
                Button("Remove", role: .destructive) { onRemove() }
            } message: {
                Text("It will stay in your Journal.")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Pieces

    private func header(now: Date) -> some View {
        let thirsty = plant.isThirsty(at: now)
        return VStack(spacing: 10) {
            PlantSprite(kind: plant.kind, growth: plant.growth, droopy: thirsty, size: 110)
                .frame(height: 130, alignment: .bottom)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(thirsty ? plant.plot.drySoil : plant.plot.wetSoil,
                            in: RoundedRectangle(cornerRadius: 24))

            Text("Lives in the \(plant.plot.emoji) \(plant.plot.title)")
                .font(.headline)

            if thirsty {
                Label("Thirsty! Drag the 🚿 onto the \(plant.plot.title) to water it.", systemImage: "drop")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            } else {
                Label("Happy. Thirsty again in \(timeLeft(now: now)).", systemImage: "drop.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
            }
        }
    }

    private var growthCard: some View {
        card(title: "Growing up", icon: "chart.line.uptrend.xyaxis", tint: Theme.leaf) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 0) {
                    ForEach(0...GardenPlant.maxGrowth, id: \.self) { stage in
                        VStack(spacing: 4) {
                            Text(stage == 0 ? "🌱" : plant.kind.emoji)
                                .font(.title2)
                                .opacity(stage <= plant.growth ? 1 : 0.25)
                            Text(["Seedling", "Sprout", "Growing", "Grown"][stage])
                                .font(.caption2)
                                .foregroundStyle(stage == plant.growth ? .primary : .secondary)
                                .fontWeight(stage == plant.growth ? .bold : .regular)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                Text(plant.growth >= GardenPlant.maxGrowth
                     ? "\(plant.name) is fully grown! Keep watering to keep it happy."
                     : "Water it when it's thirsty to help it grow.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func needsCard(_ needs: PlantNeeds) -> some View {
        card(title: "What it needs", icon: "heart.fill", tint: Theme.leaf) {
            VStack(alignment: .leading, spacing: 12) {
                if let sunlight = needs.sunlight { needRow("sun.max.fill", Theme.sun, "Sunlight", sunlight) }
                if let water = needs.water { needRow("drop.fill", Theme.water, "Water", water) }
                if let soil = needs.soil { needRow("mountain.2.fill", Theme.leaf, "Soil", soil) }
            }
        }
    }

    private var statsCard: some View {
        card(title: "Garden log", icon: "calendar", tint: Theme.leaf) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Planted \(plant.datePlanted.formatted(date: .abbreviated, time: .shortened))")
                Text(plant.timesWatered == 1 ? "Watered 1 time" : "Watered \(plant.timesWatered) times")
                if let last = plant.lastWatered {
                    Text("Last watered \(last.formatted(.relative(presentation: .named)))")
                }
            }
            .font(.subheadline)
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            if let journalEntry {
                NavigationLink {
                    JournalEntryDetailView(entry: journalEntry)
                } label: {
                    Label("Open journal page", systemImage: "list.bullet.clipboard.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }

            Button(role: .destructive) {
                confirmRemove = true
            } label: {
                Label("Remove from garden", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: Helpers

    private func timeLeft(now: Date) -> String {
        guard let last = plant.lastWatered else { return "0s" }
        let seconds = max(0, Int(plant.thirstInterval - now.timeIntervalSince(last)))
        if seconds >= 3600 { return "\(seconds / 3600)h \((seconds % 3600) / 60)m" }
        if seconds >= 60 { return "\(seconds / 60)m \(seconds % 60)s" }
        return "\(seconds)s"
    }

    private func needRow(_ icon: String, _ color: Color, _ label: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.subheadline.weight(.semibold))
                Text(text).font(.subheadline)
            }
        }
    }

    private func card<Content: View>(title: String, icon: String, tint: Color,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(tint)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.card)
        .clipShape(Theme.cardShape)
    }
}
