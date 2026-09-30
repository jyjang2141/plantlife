import SwiftUI
import PhotosUI
import Combine

// MARK: - Theme

enum Theme {
    static let leaf  = Color(red: 0.15, green: 0.47, blue: 0.25)
    static let sun   = Color(red: 0.80, green: 0.55, blue: 0.05)
    static let water = Color(red: 0.15, green: 0.45, blue: 0.75)
    static let alert = Color(red: 0.78, green: 0.30, blue: 0.20)

    static let background = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.06, green: 0.10, blue: 0.08, alpha: 1)
            : UIColor(red: 0.93, green: 0.97, blue: 0.94, alpha: 1)
    })

    static let card = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.17, blue: 0.14, alpha: 1)
            : UIColor.white
    })

    static let cardShape = RoundedRectangle(cornerRadius: 22, style: .continuous)
}

// MARK: - View model

@MainActor
final class ScanViewModel: ObservableObject {
    enum State {
        case idle
        case loading
        case result(PlantInfo)
        case failed(String)
    }

    @Published var image: UIImage?
    @Published var state: State = .idle

    private let identifier = PlantIdentifier()

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    /// Called when the student picks a photo from their library.
    func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else {
                state = .failed("Couldn't open that photo. Try a different one.")
                return
            }
            await scan(uiImage)
        } catch {
            state = .failed("Couldn't open that photo. Try a different one.")
        }
    }

    /// Shows the photo, sends it to the AI, and updates `state` with the answer.
    func scan(_ newImage: UIImage) async {
        image = newImage
        state = .loading
        do {
            let info = try await identifier.identify(image: newImage)
            state = .result(info)
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func retry() {
        guard let image else { return }
        Task { await scan(image) }
    }
}

// MARK: - Main screen

struct ContentView: View {
    @StateObject private var vm = ScanViewModel()
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false

    private let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                photoArea
                actionButtons
                resultArea
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(isPresented: $showCamera) { photo in
                Task { await vm.scan(photo) }
            }
            .ignoresSafeArea()
        }
        .task(id: photoItem) {
            await vm.loadPhoto(from: photoItem)
        }
    }

    // MARK: Pieces

    private var header: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Theme.leaf)
                Text("Plant Life")
            }
            .font(.system(.largeTitle, design: .rounded, weight: .bold))

            Text("Take a photo of a plant to find out what it is.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var photoArea: some View {
        // Color.clear fixes the size; the image overflows it and gets clipped,
        // so a wide photo can't push the layout past the screen edge.
        Color.clear
            .frame(height: 280)
            .overlay {
                if let image = vm.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "camera.macro")
                            .font(.system(size: 48))
                            .foregroundStyle(Theme.leaf)
                        Text("Your plant photo will show up here")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .background(Theme.card)
            .clipShape(Theme.cardShape)
            .overlay(
                Theme.cardShape.strokeBorder(
                    Theme.leaf.opacity(0.4),
                    style: StrokeStyle(lineWidth: 2, dash: vm.image == nil ? [8, 6] : [])
                )
            )
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    Label("Take photo", systemImage: "camera.fill")
                        .modifier(PillStyle(filled: true))
                }
                .disabled(!cameraAvailable || vm.isLoading)
                .opacity(!cameraAvailable || vm.isLoading ? 0.5 : 1)

                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Choose photo", systemImage: "photo.on.rectangle")
                        .modifier(PillStyle(filled: false))
                }
                .disabled(vm.isLoading)
                .opacity(vm.isLoading ? 0.5 : 1)
            }

            if !cameraAvailable {
                Text("This device has no camera (the Simulator never does). Use Choose photo instead.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder
    private var resultArea: some View {
        switch vm.state {
        case .idle:
            EmptyView()

        case .loading:
            HStack(spacing: 12) {
                ProgressView()
                Text("Looking closely at your plant...")
                    .font(.system(.body, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Theme.card)
            .clipShape(Theme.cardShape)

        case .result(let info):
            PlantResultView(info: info)

        case .failed(let message):
            VStack(alignment: .leading, spacing: 12) {
                Label("Something went wrong", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Theme.alert)
                Text(message)
                    .font(.system(.subheadline, design: .rounded))
                if vm.image != nil {
                    Button("Try again") { vm.retry() }
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.leaf)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Theme.card)
            .clipShape(Theme.cardShape)
        }
    }
}

// MARK: - Button look

struct PillStyle: ViewModifier {
    let filled: Bool

    func body(content: Content) -> some View {
        content
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(filled ? Color.white : Theme.leaf)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(filled ? Theme.leaf : Theme.card)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(Theme.leaf, lineWidth: filled ? 0 : 2)
            )
    }
}

#Preview {
    ContentView()
}
