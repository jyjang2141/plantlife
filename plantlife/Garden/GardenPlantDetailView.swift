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
    @State private var detent: PresentationDetent = .large
    @State private var draggingBug = false
    /// A helper bug (ladybug, bee, butterfly) the kid dragged off; asks "are you sure?".
    @State private var helperToRemove: BugKind?
    @State private var notice: String?

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
                            .zIndex(1)   // a dragged bug stays on top of the cards below
                        growthCard
                        bugsCard(now: timeline.date)
                        if let needs = journalEntry?.info?.needs { needsCard(needs) }
                        statsCard
                        actions
                    }
                    .padding(20)
                }
                .scrollDisabled(draggingBug)
            }
            .background(Theme.background)
            .navigationTitle(plant.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Ouch! That's a helper bug", isPresented: Binding(
                get: { helperToRemove != nil },
                set: { if !$0 { helperToRemove = nil } }
            ), presenting: helperToRemove) { kind in
                Button("Let it stay", role: .cancel) {}
                Button("Move it anyway", role: .destructive) { moveAway(kind) }
            } message: { kind in
                Text(Self.helperReason(kind))
            }
            .task(id: notice) {
                guard notice != nil else { return }
                try? await Task.sleep(for: .seconds(4))
                withAnimation { notice = nil }
            }
            .confirmationDialog("Remove \(plant.name) from your garden?",
                                isPresented: $confirmRemove, titleVisibility: .visible) {
                Button("Remove", role: .destructive) { onRemove() }
            } message: {
                Text("It will stay in your Journal.")
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(draggingBug)
    }

    // MARK: Pieces

    private func header(now: Date) -> some View {
        let thirsty = plant.isThirsty(at: now)
        return VStack(spacing: 10) {
            closeup(now: now, thirsty: thirsty)

            if let notice {
                Label(notice, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.leaf)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            } else if !plant.bugs(at: now).isEmpty {
                Label("Drag a bug off the plant to move it away.", systemImage: "hand.draw")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Label("Lives in the \(plant.plot.title)", systemImage: plant.plot.symbol)
                .font(.headline)

            if thirsty {
                Label("Thirsty! Drag the watering can onto it in the \(plant.plot.title).", systemImage: "drop")
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

    /// The plant up close, standing in its soil, with its bugs on it. Kids drag bugs off to move them away.
    private func closeup(now: Date, thirsty: Bool) -> some View {
        PlantWithBugs(plant: plant, droopy: thirsty, size: 220, now: now,
                      onDragOff: { kind in draggedOff(kind) },
                      onDragging: { draggingBug = $0 })
            .frame(maxWidth: .infinity)
            .frame(height: 236, alignment: .bottom)
            // Only the background is clipped, so a bug can be dragged out past the edge.
            .background {
                ZStack(alignment: .bottom) {
                    LinearGradient(colors: [Color.cyan.opacity(0.22), Color.green.opacity(0.10)],
                                   startPoint: .top, endPoint: .bottom)
                    Rectangle()
                        .fill(thirsty ? plant.plot.drySoil : plant.plot.wetSoil)
                        .frame(height: 34)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            .zIndex(1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(closeupDescription(now: now))
            .accessibilityActions {
                ForEach(plant.bugs(at: now)) { kind in
                    Button("Move the \(kind.name.lowercased()) away") { draggedOff(kind) }
                }
            }
    }

    private func closeupDescription(now: Date) -> String {
        let bugs = plant.bugs(at: now).map { "a " + $0.name.lowercased() }
        var text = "\(plant.name), \(plant.stageName)"
        if plant.leafHoles > 0 { text += ", with chewed, wilted leaves" }
        text += bugs.isEmpty ? ". No bugs on it." : ". On it: " + bugs.joined(separator: ", ") + "."
        return text
    }

    /// A bug was dragged off the plant. Caterpillars go; helper bugs ask first.
    private func draggedOff(_ kind: BugKind) {
        if kind == .caterpillar {
            moveAway(kind)
        } else {
            helperToRemove = kind
        }
    }

    private func moveAway(_ kind: BugKind) {
        withAnimation(.spring(duration: 0.4)) {
            switch kind {
            case .caterpillar:
                plant.removeCaterpillar()
                notice = "You moved the caterpillar away! The leaves grow back in \(BugRules.healText)."
            case .ladybug:
                plant.shooLadybug()
                notice = "The ladybug flew away. Caterpillars might come back now."
            case .bee, .butterfly:
                plant.shooPollinator()
                notice = "The \(kind.name.lowercased()) flew away."
            }
        }
    }

    static func helperReason(_ kind: BugKind) -> String {
        switch kind {
        case .ladybug:
            "Ladybugs are good for your garden! They eat tiny bug eggs, so caterpillars stay away. Try to let it stay."
        case .bee:
            "Bees are good for your garden! They carry pollen from flower to flower so plants can make seeds. Try to let it stay."
        case .butterfly:
            "Butterflies are good for your garden! They carry pollen from flower to flower so plants can make seeds. Try to let it stay."
        case .caterpillar:
            ""
        }
    }

    private var growthCard: some View {
        card(title: "Growing up", icon: "chart.line.uptrend.xyaxis", tint: Theme.leaf) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 0) {
                    ForEach(0...GardenPlant.maxGrowth, id: \.self) { stage in
                        VStack(spacing: 4) {
                            PlantSprite(kind: plant.kind, growth: stage, droopy: false, size: 36)
                                .frame(height: 40, alignment: .bottom)
                                .opacity(stage <= plant.growth ? 1 : 0.25)
                            Text(["Seedling", "Sprout", "Growing", "Grown"][stage])
                                .font(.caption2)
                                .foregroundStyle(stage == plant.growth ? .primary : .secondary)
                                .fontWeight(stage == plant.growth ? .bold : .regular)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                Text(growthHint)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var growthHint: String {
        if plant.growth >= GardenPlant.maxGrowth { return "\(plant.name) is fully grown! Keep watering to keep it happy." }
        if plant.leafHoles > 0 {
            return plant.halfGrown
                ? "Halfway to the next stage! Chewed leaves mean it needs 2 drinks to grow."
                : "Chewed leaves slow it down: it needs 2 drinks to grow each stage."
        }
        return "Water it when it's thirsty to help it grow."
    }

    // MARK: Bugs

    private func bugsCard(now: Date) -> some View {
        let quiet = !plant.hasCaterpillar && plant.leavesHealDate == nil
            && !plant.hasLadybug(at: now) && !plant.isPollinated(at: now)
        return card(title: "Bugs", icon: "ladybug.fill", tint: Theme.alert) {
            VStack(alignment: .leading, spacing: 12) {
                if plant.hasCaterpillar {
                    bugRow(.caterpillar, "A caterpillar is chewing holes in the leaves, so they're wilting and falling off. Chewed plants grow more slowly. Drag it off the plant up top to move it away.")
                } else if let heal = plant.leavesHealDate {
                    bugRow(.caterpillar, "The caterpillar is gone! The chewed leaves grow back \(heal.formatted(.relative(presentation: .named))).")
                }
                if plant.hasLadybug(at: now) {
                    bugRow(.ladybug, "A ladybug is guarding it. Ladybugs eat tiny bug eggs, so new caterpillars stay away.")
                }
                if let pollinator = plant.pollinator(at: now) {
                    bugRow(pollinator, "A \(pollinator.name.lowercased()) is resting on its flowers.")
                }
                if plant.isPollinated(at: now) {
                    bugRow(.bee, plant.pollenBoost
                           ? "A pollinator visited its flowers today! Water it when it's thirsty for a growth boost."
                           : "A pollinator visited its flowers today. Pollen helps plants make seeds.")
                }
                if quiet {
                    Text("No bugs right now. Bees and butterflies visit flowers, and ladybugs keep caterpillars away. Invite them from the Bugs tray in the bed.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func bugRow(_ kind: BugKind, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            BugSprite(kind: kind).frame(width: 30, height: 30)
            Text(text).font(.subheadline)
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
                if plant.timesPollinated > 0 {
                    Text(plant.timesPollinated == 1 ? "Pollinated 1 time" : "Pollinated \(plant.timesPollinated) times")
                }
                if plant.caterpillarsMoved > 0 {
                    Text(plant.caterpillarsMoved == 1 ? "Moved 1 caterpillar away" : "Moved \(plant.caterpillarsMoved) caterpillars away")
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
