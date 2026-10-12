//
//  DiscoverView.swift
//  plantlife
//
//  The Discover tab: snap or pick a photo, identify the plant, save it.
//

import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Discover: add a new plant
// Every scan is saved to the Journal and planted in the Garden, then the
// kid is sent straight to its Journal page to observe it before the reveal.

struct DiscoverView: View {
    @Binding var selectedTab: Int
    @Binding var journalPath: [JournalEntry]

    @Environment(\.modelContext) private var context

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
                    addPlantCard

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

    private var addPlantCard: some View {
        VStack(spacing: 14) {
            Text("🌱")
                .font(.system(size: 80))
            Text("Add a new plant")
                .font(.title2.bold())
            Text("Take a photo of a plant to add it to your journal.")
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
                let entry = PlantRecorder.record(info: info, image: image, in: context)
                // Jump straight to the new plant's Journal page.
                journalPath = [entry]
                selectedTab = 2
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
