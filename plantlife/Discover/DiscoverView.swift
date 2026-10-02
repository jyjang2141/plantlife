//
//  DiscoverView.swift
//  plantlife
//
//  The Discover tab: snap or pick a photo, identify the plant, save it.
//

import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Discover: scan one plant at a time
// No swiping. The screen shows your most recent find; every scan is
// saved to the Journal and planted in the Garden automatically.

struct DiscoverView: View {
    @Binding var selectedTab: Int

    @Environment(\.modelContext) private var context
    @Query(sort: \JournalEntry.dateFound, order: .reverse) private var entries: [JournalEntry]

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var justSaved = false

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

                    if let latest = entries.first {
                        LatestFindCard(entry: latest)
                            .padding(.horizontal, 18)
                    } else {
                        emptyState
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

                    if justSaved { savedBanner }
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

    private var savedBanner: some View {
        VStack(spacing: 10) {
            Label("Saved to your Journal and planted in your Garden!", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button { selectedTab = 0 } label: {
                    Label("Water it", systemImage: "drop.fill").frame(maxWidth: .infinity)
                }
                Button { selectedTab = 2 } label: {
                    Label("Open Journal", systemImage: "list.bullet.clipboard.fill").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered).tint(.green)
        }
        .padding(.horizontal)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
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
        justSaved = false
        do {
            let info = try await identifier.identify(image: image)
            isLoading = false
            if info.isPlant {
                PlantRecorder.record(info: info, image: image, in: context)
                withAnimation(.snappy) { justSaved = true }
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

// MARK: - The latest find (one card, no swiping)

private struct LatestFindCard: View {
    let entry: JournalEntry

    var body: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottom) {
                Group {
                    if let image = entry.image {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        Color.green.opacity(0.12)
                    }
                }
                .frame(height: 235)
                .frame(maxWidth: .infinity)
                .clipped()

                Text("Latest find")
                    .font(.headline).foregroundStyle(.white)
                    .padding(10).background(.black.opacity(0.25), in: Capsule())
                    .padding(.bottom, 10)
            }
            .frame(height: 235)
            .clipShape(RoundedRectangle(cornerRadius: 28))

            Text(entry.name)
                .font(.title.bold())
                .multilineTextAlignment(.center)

            if let summary = entry.info?.summary, !summary.isEmpty {
                Text(summary)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            NavigationLink {
                JournalEntryDetailView(entry: entry)
            } label: {
                Label("See full details", systemImage: "chevron.right.circle.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(.green)
        }
        .padding(18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.10), radius: 12, y: 5)
    }
}
