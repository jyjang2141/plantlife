import SwiftUI
import SwiftData

struct GardenView: View {
    @Binding var selectedTab: Int
    @Environment(\.modelContext) private var context
    @Query(sort: \GardenPlant.datePlanted) private var plants: [GardenPlant]
    @State private var selectedPlant: GardenPlant?
    /// Controlled by the app so returning from planting opens the right garden.
    @Binding var currentArea: Int?
    @AppStorage("gardenName") private var gardenName = ""
    @State private var renamingGarden = false
    @State private var newGardenName = ""
    private var displayGardenName: String { gardenName.isEmpty ? "My little garden" : gardenName }
    @State private var refresh = Date.now
    static let areas: [GardenPlot] = [.desert, .sunny, .shady]
    private var areas: [GardenPlot] { Self.areas }
    private let ink = Color(red: 0.23, green: 0.23, blue: 0.18)
    private let cream = Color(red: 1, green: 0.98, blue: 0.91)
    private let initialArea: Int

    init(selectedTab: Binding<Int>, currentArea: Binding<Int?>) {
        self._selectedTab = selectedTab
        self._currentArea = currentArea
        self.initialArea = min(2, max(0, currentArea.wrappedValue ?? 1))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                        ForEach(Array(areas.enumerated()), id: \.offset) { index, area in
                            GardenGround(bed: area, plants: plants.filter { $0.plot == area },
                                         active: selectedTab == 0 && currentArea == index,
                                         now: refresh,
                                         select: { selectedPlant = $0 })
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.paging)
                .defaultScrollAnchor(UnitPoint(x: CGFloat(initialArea) / 2, y: 0.5))
                .scrollPosition(id: $currentArea, anchor: .center)

                VStack {
                    HStack(spacing: 10) {
                        let area = areas[currentArea ?? 1]
                        GardenMascot(bed: area)
                            .frame(width: 32, height: 32).padding(10).background(cream, in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Button {
                                newGardenName = gardenName
                                renamingGarden = true
                            } label: {
                                HStack(spacing: 4) {
                                    Text(displayGardenName).lineLimit(1)
                                    Image(systemName: "pencil")
                                }
                                .font(.system(.caption, design: .rounded))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(displayGardenName + ". Change garden name")
                            Text(area == .desert ? "Desert" : area == .sunny ? "Sunny Garden" : "Shady Garden")
                                .font(.system(.headline, design: .rounded).bold())
                                .lineLimit(1).minimumScaleFactor(0.75)
                        }
                        .padding(12).background(cream, in: Capsule())
                        Spacer(minLength: 4)
                        Button { selectedTab = 1 } label: {
                            Image(systemName: "camera.fill").font(.title2)
                                .frame(width: 48, height: 48).background(cream, in: Circle())
                        }
                        .accessibilityLabel("Plant Detective")
                        Menu {
                            Button("My journal", systemImage: "book") { selectedTab = 2 }
                            Button("Learn", systemImage: "sparkles") { selectedTab = 3 }
                        } label: {
                            Image(systemName: "book").font(.title2)
                                .frame(width: 48, height: 48).background(cream, in: Circle())
                        }
                        .accessibilityLabel("Journal and learning")
                    }
                    Spacer()
                    if plants.isEmpty {
                        Button { selectedTab = 1 } label: {
                            Label("Find your first plant", systemImage: "camera")
                                .font(.headline).padding(12).background(cream, in: Capsule())
                        }
                    }
                    HStack(spacing: 18) {
                        Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                            .disabled(currentArea == 0)
                            .accessibilityLabel("Previous garden")
                        ForEach(0..<3) { index in
                            Button { withAnimation { currentArea = index } } label: {
                                Circle().fill(currentArea == index ? ink : cream)
                                    .frame(width: 12, height: 12).frame(width: 32, height: 44)
                            }
                            .accessibilityLabel(areas[index].title)
                        }
                        Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                            .disabled(currentArea == 2)
                            .accessibilityLabel("Next garden")
                    }
                    .font(.headline)
                }
                .padding(16)
                .foregroundStyle(ink)
            }
            .background((currentArea == 0 ? Color(red: 0.92, green: 0.83, blue: 0.67) :
                         currentArea == 2 ? Color(red: 0.73, green: 0.82, blue: 0.75) :
                         Color(red: 0.83, green: 0.90, blue: 0.75)).ignoresSafeArea())
        }
        .task(id: selectedTab) {
            guard selectedTab == 0 else { return }
            while !Task.isCancelled {
                BugRules.update(plants)
                refresh = .now
                do { try await Task.sleep(for: .seconds(5)) } catch { break }
            }
        }
        .alert("Name your garden", isPresented: $renamingGarden) {
            TextField("My little garden", text: $newGardenName)
                .textInputAutocapitalization(.words)
            Button("Save") { gardenName = newGardenName.trimmingCharacters(in: .whitespacesAndNewlines) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("What should your garden be called?")
        }
        .fullScreenCover(item: $selectedPlant) { plant in
            GardenPlantDetailView(plant: plant) {
                selectedPlant = nil
                context.delete(plant)
                try? context.save()
            }
        }
    }

    private func move(_ direction: Int) {
        withAnimation { currentArea = min(2, max(0, (currentArea ?? 1) + direction)) }
    }
}

#Preview {
    GardenView(selectedTab: .constant(0), currentArea: .constant(1))
        .modelContainer(for: [JournalEntry.self, GardenPlant.self], inMemory: true)
}
