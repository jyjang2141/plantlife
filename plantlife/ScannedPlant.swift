import SwiftUI
import PhotosUI

// MARK: - A real scanned plant
// Replaces the old hardcoded `PlantPhoto` (which always said "Sunflower").
// `info` is the same `PlantInfo` the AI call already returns — see plantIdentifier.swift.

struct ScannedPlant: Identifiable {
    let id = UUID()
    let image: UIImage
    let info: PlantInfo
}

// MARK: - Photo discovery journal

struct DiscoverView: View {
    @Binding var selectedTab: Int

    @State private var entries: [ScannedPlant] = []
    @State private var selectedIndex = 0

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var showCamera = false
    @State private var photoItem: PhotosPickerItem?

    private let identifier = PlantIdentifier()
    private let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text("Take a photo of a plant to add it to your journal.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                if entries.isEmpty {
                    emptyState
                } else {
                    SwipeablePhotoJournal(entries: entries, selectedIndex: $selectedIndex)
                }

                statusArea

                HStack(spacing: 12) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(.green)
                    .disabled(!cameraAvailable || isLoading)

                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Choose Photo", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                }
                .padding(.horizontal)

                if !entries.isEmpty {
                    Button { selectedTab = 0 } label: {
                        Label("Help a Plant in the Garden", systemImage: "leaf.fill")
                            .font(.headline).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).tint(.green)
                    .padding(.horizontal)
                }
            }
                .padding(.vertical)
            }
            .navigationTitle("Plant Detective")
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker(isPresented: $showCamera) { photo in
                    Task { await identify(photo) }
                }
                .ignoresSafeArea()
            }
            .task(id: photoItem) {
                guard let photoItem else { return }
                defer { self.photoItem = nil }
                do {
                    guard let data = try await photoItem.loadTransferable(type: Data.self),
                          let uiImage = UIImage(data: data) else {
                        errorMessage = "Couldn't open that photo. Try a different one."
                        return
                    }
                    await identify(uiImage)
                } catch {
                    errorMessage = "Couldn't open that photo. Try a different one."
                }
            }
        }
    }

    // MARK: Pieces

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("🌱")
                .font(.system(size: 80))
            Text("No plants yet")
                .font(.title2.bold())
            Text("Snap a photo of a real plant to start your journal!")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            if !cameraAvailable {
                Text("(The Simulator has no camera — use Choose Photo instead.)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 395)
        .frame(maxWidth: .infinity)
        .background(Color.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal)
    }

    @ViewBuilder
    private var statusArea: some View {
        if isLoading {
            HStack(spacing: 10) {
                ProgressView()
                Text("Looking closely at your plant...")
                    .font(.subheadline)
            }
        } else if let errorMessage {
            VStack(spacing: 6) {
                Label("Something went wrong", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
        }
    }

    // MARK: AI call

    private func identify(_ image: UIImage) async {
        isLoading = true
        errorMessage = nil
        do {
            let info = try await identifier.identify(image: image)
            isLoading = false
            if info.isPlant {
                entries.append(ScannedPlant(image: image, info: info))
                selectedIndex = entries.count - 1
            } else {
                errorMessage = info.message?.isEmpty == false
                    ? info.message!
                    : "That doesn't look like a plant. Try another photo!"
            }
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - One card in the swipeable journal

private struct PlantPhotoCard: View {
    let entry: ScannedPlant
    let number: Int

    var body: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottom) {
                Image(uiImage: entry.image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 235)
                    .clipped()
                Text("Photo \(number)")
                    .font(.headline).foregroundStyle(.white)
                    .padding(10).background(.black.opacity(0.25), in: Capsule())
                    .padding(.bottom, 10)
            }
            .frame(height: 235)
            .clipShape(RoundedRectangle(cornerRadius: 28))

            Text(displayName)
                .font(.title.bold())
            if let summary = entry.info.summary, !summary.isEmpty {
                Text(summary)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            NavigationLink {
                PlantDetailScreen(entry: entry)
            } label: {
                Label("See full details", systemImage: "chevron.right.circle.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(.green)
        }
        .padding(18)
        .background(.white, in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.10), radius: 12, y: 5)
    }

    private var displayName: String {
        let name = entry.info.commonName ?? ""
        return name.isEmpty ? "Mystery plant" : name
    }
}

// MARK: - Full facts screen (fun fact, needs, dangers, safety)

private struct PlantDetailScreen: View {
    let entry: ScannedPlant

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(uiImage: entry.image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                PlantResultView(info: entry.info)
            }
            .padding(20)
        }
        .navigationTitle(entry.info.commonName ?? "Plant")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Swipe container (same gesture as before, now over real entries)

private struct SwipeablePhotoJournal: View {
    let entries: [ScannedPlant]
    @Binding var selectedIndex: Int
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 12) {
            PlantPhotoCard(entry: entries[selectedIndex], number: selectedIndex + 1)
                .padding(.horizontal, 18)
                .offset(x: dragOffset)
                .rotationEffect(.degrees(Double(dragOffset / 36)))
                .highPriorityGesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in state = value.translation.width }
                        .onEnded { value in
                            guard abs(value.translation.width) > 45 else { return }
                            let direction = value.translation.width < 0 ? 1 : -1
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                                selectedIndex = (selectedIndex + direction + entries.count) % entries.count
                            }
                        }
                )
                .accessibilityHint("Swipe left or right to browse your plant photos")

            HStack(spacing: 24) {
                Button {
                    advance(by: -1)
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                }
                .font(.system(size: 30))
                .disabled(entries.count < 2)

                HStack(spacing: 7) {
                    ForEach(entries.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == selectedIndex ? Color.green : Color.gray.opacity(0.3))
                            .frame(width: index == selectedIndex ? 24 : 9, height: 9)
                    }
                }

                Button {
                    advance(by: 1)
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                }
                .font(.system(size: 30))
                .disabled(entries.count < 2)
            }
            .tint(.green)
            Text("Swipe, or tap the arrows, to see all your photos")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .onChange(of: entries.count) { _, newCount in
            if selectedIndex >= newCount { selectedIndex = max(0, newCount - 1) }
        }
    }

    private func advance(by direction: Int) {
        guard entries.count > 1 else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            selectedIndex = (selectedIndex + direction + entries.count) % entries.count
        }
    }
}
