import SwiftUI

@main
struct PlantLifePrototypeApp: App {
    var body: some Scene {
        WindowGroup { PlantLifeHome() }
    }
}

struct PlantLifeHome: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GardenRescueView()
                .tabItem { Label("Garden", systemImage: "leaf.fill") }
                .tag(0)
            DiscoverView(selectedTab: $selectedTab)
                .tabItem { Label("Discover", systemImage: "camera.fill") }
                .tag(1)
            LearnView()
                .tabItem { Label("Learn", systemImage: "book.fill") }
                .tag(2)
        }
        .tint(.green)
    }
}

// MARK: - One tactile garden rescue

struct GardenRescueView: View {
    @State private var waterProgress = 0.0
    @State private var hosePosition = CGPoint.zero
    @State private var hoseStart: CGPoint?
    @State private var lastWateringTime: Date?

    var isFinished: Bool { waterProgress >= 1 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Garden Rescue")
                        .font(.largeTitle.bold())
                    Text(isFinished ? "Sunny is standing tall again!" : "Oh no! Sunny's leaves are droopy. The soil looks dry.")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    GeometryReader { proxy in
                        let size = proxy.size
                        let soilArea = CGRect(x: 24, y: size.height * 0.54, width: size.width - 48, height: size.height * 0.37)
                        let isWatering = soilArea.contains(hosePosition) && !isFinished

                        ZStack {
                            LinearGradient(colors: [Color.cyan.opacity(0.28), Color.green.opacity(0.16)], startPoint: .top, endPoint: .bottom)
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 46)).foregroundStyle(.yellow)
                                .position(x: size.width - 47, y: 46)
                            RoundedRectangle(cornerRadius: 22)
                                .fill(isFinished ? Color.brown.opacity(0.62) : Color.brown.opacity(0.88))
                                .frame(width: soilArea.width, height: soilArea.height)
                                .position(x: soilArea.midX, y: soilArea.midY)
                            Text(isFinished ? "Fresh, damp soil" : "Dry soil")
                                .font(.headline).foregroundStyle(.white.opacity(0.92))
                                .position(x: soilArea.midX, y: soilArea.maxY - 26)

                            PlantBuddy(isDroopy: !isFinished)
                                .position(x: size.width / 2, y: size.height * 0.48)

                            ZStack {
                                Text("🚿")
                                    .font(.system(size: 76))
                                    .offset(y: -43)
                                if isWatering {
                                    WaterDrips()
                                        .offset(x: 18, y: 43)
                                }
                            }
                            .frame(width: 112, height: 175)
                            .position(hosePosition)
                                .gesture(hoseDrag(in: size, soil: soilArea))
                                .accessibilityLabel("Watering hose")

                            if isFinished {
                                Label("All better!", systemImage: "heart.fill")
                                    .font(.title2.bold()).foregroundStyle(.white)
                                    .padding(.horizontal, 18).padding(.vertical, 10)
                                    .background(.green, in: Capsule())
                                    .position(x: size.width / 2, y: 42)
                            }
                        }
                        .onAppear {
                            if hosePosition == .zero { hosePosition = CGPoint(x: 58, y: size.height - 58) }
                        }
                    }
                    .frame(height: 430)
                    .clipShape(RoundedRectangle(cornerRadius: 28))

                    VStack(alignment: .leading, spacing: 9) {
                        Text(isFinished ? "You helped Sunny!" : "Pick up the shower and water the dry soil.")
                            .font(.title2.bold())
                        Text(isFinished ? "Plants use water to keep their leaves and stems firm." : "Drag 🚿 over the brown garden bed. Keep it there until the soil is damp.")
                            .font(.title3)
                        ProgressView(value: waterProgress).tint(.blue)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 22))
                    .shadow(color: .black.opacity(0.07), radius: 8, y: 3)

                    if isFinished {
                        Button {
                            waterProgress = 0
                            hosePosition = .zero
                            lastWateringTime = nil
                        } label: {
                            Label("Play Again", systemImage: "arrow.counterclockwise")
                                .font(.title3.bold()).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).tint(.green)
                    }
                }
                .padding()
            }
            .background(Color.green.opacity(0.07))
        }
    }

    private func hoseDrag(in size: CGSize, soil: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let origin = hoseStart ?? hosePosition
                if hoseStart == nil { hoseStart = origin }
                hosePosition = clamped(origin.moved(by: value.translation), in: size)
                if soil.contains(hosePosition) {
                    let now = Date()
                    if let lastWateringTime {
                        let elapsed = min(now.timeIntervalSince(lastWateringTime), 0.15)
                        waterProgress = min(1, waterProgress + elapsed * 0.12)
                    }
                    lastWateringTime = now
                } else {
                    lastWateringTime = nil
                }
            }
            .onEnded { _ in
                hoseStart = nil
                lastWateringTime = nil
            }
    }

    private func clamped(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: min(max(point.x, 30), size.width - 30), y: min(max(point.y, 30), size.height - 30))
    }
}

private struct PlantBuddy: View {
    let isDroopy: Bool
    var body: some View {
        Text(isDroopy ? "🌱" : "🌻")
            .font(.system(size: 100))
            .frame(width: 140, height: 180)
    }
}

private struct WaterDrips: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { proxy in
                let time = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<12, id: \.self) { index in
                        let progress = (time * 1.8 + Double(index) * 0.085).truncatingRemainder(dividingBy: 1)
                        let column = Double(index % 4)
                        Text("💧")
                            .font(.system(size: 11 + progress * 5))
                            .position(
                                x: proxy.size.width * (0.13 + column * 0.25),
                                y: proxy.size.height * progress
                            )
                            .opacity(0.45 + progress * 0.55)
                    }
                }
            }
        }
        .frame(width: 72, height: 120)
        .allowsHitTesting(false)
    }
}

private extension CGPoint {
    func moved(by translation: CGSize) -> CGPoint {
        CGPoint(x: x + translation.width, y: y + translation.height)
    }
}

// MARK: - Photo discovery journal

struct DiscoverView: View {
    @Binding var selectedTab: Int
    @State private var selectedPhoto = 0

    private let photos = [PlantPhoto(id: 1), PlantPhoto(id: 2), PlantPhoto(id: 3)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("My Plant Photos")
                    .font(.largeTitle.bold())
                Text("Swipe to look through plants you found.")
                    .font(.title3).foregroundStyle(.secondary)

                SwipeablePhotoJournal(photos: photos, selectedPhoto: $selectedPhoto)
                .frame(height: 395)

                Button { selectedTab = 0 } label: {
                    Label("Help a Plant in the Garden", systemImage: "leaf.fill")
                        .font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(.green)
                .padding(.horizontal)

                Button { selectedPhoto = 0 } label: {
                    Label("Take Another Plant Photo", systemImage: "camera.fill")
                }
                .buttonStyle(.bordered)
            }
            .padding(.vertical)
            .navigationTitle("Plant Detective")
        }
    }
}

private struct PlantPhoto: Identifiable {
    let id: Int
    let name = "Sunflower"
    let summary = "Sunflowers turn their bright faces toward the sun. They like sunny spots and regular drinks of water."
}

private struct PlantPhotoCard: View {
    let photo: PlantPhoto
    let number: Int
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 28).fill(LinearGradient(colors: [.blue.opacity(0.24), .green.opacity(0.25)], startPoint: .top, endPoint: .bottom))
                Text("🌻").font(.system(size: 145))
                Text("Photo " + String(number)).font(.headline).foregroundStyle(.white).padding(10).background(.black.opacity(0.25), in: Capsule()).frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 235)
            Text(photo.name).font(.title.bold())
            Text(photo.summary).font(.body).multilineTextAlignment(.center).foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.white, in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.10), radius: 12, y: 5)
    }
}

private struct SwipeablePhotoJournal: View {
    let photos: [PlantPhoto]
    @Binding var selectedPhoto: Int
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 12) {
            PlantPhotoCard(photo: photos[selectedPhoto], number: selectedPhoto + 1)
                .padding(.horizontal, 18)
                .offset(x: dragOffset)
                .rotationEffect(.degrees(Double(dragOffset / 36)))
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in state = value.translation.width }
                        .onEnded { value in
                            guard abs(value.translation.width) > 45 else { return }
                            let direction = value.translation.width < 0 ? 1 : -1
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                                selectedPhoto = (selectedPhoto + direction + photos.count) % photos.count
                            }
                        }
                )
                .accessibilityHint("Swipe left or right to browse your plant photos")

            HStack(spacing: 7) {
                ForEach(photos.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == selectedPhoto ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: index == selectedPhoto ? 24 : 9, height: 9)
                }
            }
            Text("Swipe left or right to see all three photos")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

struct LearnView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Plants need") {
                    Label("Water to drink", systemImage: "drop.fill").foregroundStyle(.blue)
                    Label("Sunshine for energy", systemImage: "sun.max.fill").foregroundStyle(.orange)
                    Label("Soil to hold their roots", systemImage: "square.3.layers.3d.down.right.fill").foregroundStyle(.brown)
                    Label("A safe temperature", systemImage: "thermometer.medium").foregroundStyle(.pink)
                }
                Section("Remember") { Text("Every plant is different. Look for clues about what yours needs!").font(.title3) }
            }
            .navigationTitle("Plant Power")
        }
    }
}

#Preview { PlantLifeHome() }
