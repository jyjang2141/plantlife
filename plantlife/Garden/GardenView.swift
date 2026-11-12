import SwiftUI
import SwiftData

struct GardenView: View {
    @Binding var selectedTab: Int
    @Environment(\.modelContext) private var context
    @Query(sort: \GardenPlant.datePlanted) private var plants: [GardenPlant]
    @State private var now = Date.now
    @State private var selectedPlant: GardenPlant?
    @State private var currentArea: Int? = 1

    private let areas: [GardenPlot] = [.desert, .sunny, .shady]

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack {
                Color(red: 0.56, green: 0.74, blue: 0.39).ignoresSafeArea()
                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                        ForEach(Array(areas.enumerated()), id: \.offset) { index, area in
                            GardenClearing(
                                area: area,
                                plants: plants.filter { $0.plot == area },
                                now: now,
                                size: CGSize(width: width, height: height),
                                select: { selectedPlant = $0 },
                                findPlant: { selectedTab = 1 }
                            )
                            .frame(width: width, height: height)
                            .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                // Continuous scrolling: clearings are landmarks, not snapping pages.
                .scrollPosition(id: $currentArea, anchor: .center)

                VStack {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("My little garden").font(.system(.title2, design: .rounded).bold())
                            Label("Drag to explore", systemImage: "hand.draw")
                                .font(.subheadline)
                        }
                        .padding(14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
                        Spacer()
                        Button { selectedTab = 1 } label: {
                            Image(systemName: "camera.fill")
                                .font(.title2).padding(17)
                                .background(.regularMaterial, in: Circle())
                        }
                        .accessibilityLabel("Discover a new plant")
                        Menu {
                            Button("My journal", systemImage: "book") { selectedTab = 2 }
                            Button("Learn", systemImage: "sparkles") { selectedTab = 3 }
                        } label: {
                            Image(systemName: "backpack.fill")
                                .font(.title2).padding(17)
                                .background(.regularMaterial, in: Circle())
                        }
                        .accessibilityLabel("Open journal and learning menu")
                    }
                    Spacer()
                    if plants.isEmpty {
                        Button { selectedTab = 1 } label: {
                            Label("Find a plant for your garden", systemImage: "plus.circle.fill")
                                .font(.headline).padding(14)
                                .background(.regularMaterial, in: Capsule())
                        }
                    }
                    HStack(spacing: 10) {
                        ForEach(Array(areas.enumerated()), id: \.offset) { index, area in
                            Button {
                                withAnimation(.easeInOut(duration: 0.7)) { currentArea = index }
                            } label: {
                                Text(area.emoji).font(.title2)
                                    .frame(width: 48, height: 44)
                                    .background(currentArea == index ? Color.white.opacity(0.85) : .clear, in: RoundedRectangle(cornerRadius: 14))
                            }
                            .accessibilityLabel("Visit " + area.title)
                        }
                    }
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 25))
                }
                .padding(16)
                .foregroundStyle(Color(red: 0.15, green: 0.27, blue: 0.15))
            }
        }
        .task {
            while !Task.isCancelled {
                BugRules.update(plants)
                now = .now
                do { try await Task.sleep(for: .seconds(5)) }
                catch { break }
            }
        }
        .fullScreenCover(item: $selectedPlant) { plant in
            GardenPlantDetailView(plant: plant) {
                selectedPlant = nil
                context.delete(plant)
                try? context.save()
            }
        }
    }
}

private struct GardenClearing: View {
    let area: GardenPlot
    let plants: [GardenPlant]
    let now: Date
    let size: CGSize
    let select: (GardenPlant) -> Void
    let findPlant: () -> Void

    private var ground: Color {
        switch area {
        case .desert: Color(red: 0.85, green: 0.75, blue: 0.49)
        case .sunny: Color(red: 0.64, green: 0.80, blue: 0.43)
        case .shady: Color(red: 0.39, green: 0.62, blue: 0.41)
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [ground.opacity(0.7), ground], startPoint: .top, endPoint: .bottom)
            // The path crosses every clearing at the same height to join the world.
            Rectangle()
                .fill(Color(red: 0.88, green: 0.80, blue: 0.60))
                .frame(height: 65)
                .position(x: size.width / 2, y: size.height * 0.77)
            ForEach(0..<14, id: \.self) { index in
                Ellipse().fill(.white.opacity(0.20))
                    .frame(width: 16, height: 7)
                    .position(x: CGFloat(index) * size.width / 13, y: size.height * 0.77 + (index.isMultiple(of: 2) ? 14 : -14))
            }
            TimelineView(.animation(minimumInterval: 1.0 / 20)) { timeline in
                let phase = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    Text(area == .shady ? "🌳" : area == .desert ? "🏜️" : "🌻")
                        .font(.system(size: min(size.width * 0.20, 120)))
                        .rotationEffect(.degrees(sin(phase * 0.7) * 2))
                        .position(x: size.width * 0.80, y: size.height * 0.23)
                    Text("🦋").font(.system(size: 27))
                        .position(x: size.width * 0.23 + sin(phase * 0.4) * 40,
                                  y: size.height * 0.31 + cos(phase * 0.7) * 17)
                }
                .accessibilityHidden(true)
                .allowsHitTesting(false)
            }
            Text(area.title)
                .font(.system(.title2, design: .rounded).bold())
                .foregroundStyle(Color(red: 0.30, green: 0.20, blue: 0.12))
                .padding(.horizontal, 22).padding(.vertical, 12)
                .background(Color(red: 0.96, green: 0.88, blue: 0.67), in: RoundedRectangle(cornerRadius: 9))
                .rotationEffect(.degrees(-3))
                .position(x: size.width * 0.36, y: size.height * 0.24)

            ZStack {
                    RoundedRectangle(cornerRadius: 36)
                        .fill(Color(red: 0.48, green: 0.30, blue: 0.17))
                        .shadow(color: .black.opacity(0.22), radius: 0, y: 9)
                    RoundedRectangle(cornerRadius: 28)
                        .fill(area.drySoil)
                        .padding(10)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 5) {
                        ForEach(Array(GardenPlant.arrange(plants).enumerated()), id: \.offset) { _, plant in
                            if let plant {
                                Button { select(plant) } label: {
                                VStack(spacing: 0) {
                                    PlantWithBugs(plant: plant, droopy: plant.isThirsty(at: now), size: 48, now: now)
                                        .allowsHitTesting(false)
                                    if plant.isThirsty(at: now) {
                                        Text("💧").font(.caption)
                                    }
                                }
                                .frame(height: 62)
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Care for " + plant.name)
                            } else {
                                Button(action: findPlant) {
                                Ellipse().fill(.black.opacity(0.13))
                                    .frame(width: 34, height: 15)
                                    .frame(height: 62)
                                    .frame(maxWidth: .infinity)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Find a plant for this empty spot")
                            }
                        }
                    }
                    .padding(18)
            }
            .frame(width: min(size.width * 0.78, 520), height: min(size.height * 0.37, 280))
            .position(x: size.width / 2, y: size.height * 0.51)

            Text("Tap a plant to care for it")
                .font(.system(.subheadline, design: .rounded).bold())
                .foregroundStyle(Color(red: 0.21, green: 0.28, blue: 0.15))
                .position(x: size.width / 2, y: size.height * 0.73)
        }
    }
}

#Preview {
    GardenView(selectedTab: .constant(0))
        .modelContainer(for: [JournalEntry.self, GardenPlant.self], inMemory: true)
}
