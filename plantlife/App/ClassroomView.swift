import SwiftUI
import Combine
import PhotosUI

struct ClassroomView: View {
    @EnvironmentObject private var classService: ClassService

    var body: some View {
        NavigationStack {
            Group {
                if classService.classCode == nil {
                    JoinClassView()
                } else {
                    ClassFeedView()
                }
            }
            .navigationTitle(classService.className ?? "Classroom")
        }
    }
}

private let avatarChoices = ["🌱", "🌵", "🌻", "🌿", "🍄", "🌸", "🌳", "🪴"]

struct JoinClassView: View {
    @EnvironmentObject private var classService: ClassService

    enum Mode: String, CaseIterable, Identifiable {
        case join = "Join a class"
        case create = "Start a class"
        var id: Self { self }
    }

    @State private var mode: Mode = .join
    @AppStorage("classNickname") private var nickname = ""
    @AppStorage("classAvatar") private var avatar = "🌱"
    @State private var code = ""
    @State private var className = ""
    @State private var isWorking = false
    @State private var errorText: String?

    private var canSubmit: Bool {
        guard !isWorking, !nickname.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        switch mode {
        case .join:   return code.count == 7
        case .create: return !className.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    var body: some View {
        Form {
            Section {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section("You") {
                TextField("Nickname (no real names)", text: $nickname)
                    .textInputAutocapitalization(.words)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(avatarChoices, id: \.self) { choice in
                            Text(choice)
                                .font(.largeTitle)
                                .padding(6)
                                .background(Circle().fill(choice == avatar ? Color.green.opacity(0.25) : .clear))
                                .onTapGesture { avatar = choice }
                        }
                    }
                }
            }

            if mode == .join {
                Section("Class code") {
                    TextField("e.g. KLM-482", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.title2.monospaced())
                        .onChange(of: code) { _, newValue in
                            let cleaned = ClassService.formatCode(newValue)
                            if cleaned != newValue { code = cleaned }
                        }
                }
            } else {
                Section("Class name") {
                    TextField("e.g. Room 12 Plant Lab", text: $className)
                }
            }

            Section {
                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        Spacer()
                        if isWorking {
                            ProgressView()
                        } else {
                            Text(mode == .join ? "Join class" : "Create class").bold()
                        }
                        Spacer()
                    }
                }
                .disabled(!canSubmit)
            }
        }
        .alert("Something went wrong",
               isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
    }

    private func submit() async {
        isWorking = true
        defer { isWorking = false }
        let name = nickname.trimmingCharacters(in: .whitespaces)
        do {
            switch mode {
            case .join:
                try await classService.joinClass(code: code, nickname: name, avatar: avatar)
            case .create:
                _ = try await classService.createClass(
                    name: className.trimmingCharacters(in: .whitespaces),
                    nickname: name,
                    avatar: avatar
                )
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
}

struct ClassFeedView: View {
    @EnvironmentObject private var classService: ClassService
    @State private var showingNewEntry = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Class code")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text(classService.classCode ?? "")
                            .font(.system(.largeTitle, design: .monospaced).bold())
                        Spacer()
                        ShareLink(item: "Join my PlantLife class with code \(classService.classCode ?? "")") {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }

            Section("Classmates (\(classService.members.count))") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(classService.members) { member in
                            VStack {
                                Text(member.avatar).font(.largeTitle)
                                Text(member.nickname).font(.caption).lineLimit(1)
                            }
                            .frame(width: 64)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Class timeline") {
                Button {
                    showingNewEntry = true
                } label: {
                    Label("Share a plant update", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                if classService.entries.isEmpty {
                    Text("No posts yet. Be the first to share what you did for your plant.")
                        .foregroundStyle(.secondary)
                }
                ForEach(classService.entries) { entry in
                    EntryRow(entry: entry, avatar: avatar(for: entry))
                }
            }

            if let error = classService.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Leave class", role: .destructive) {
                    Task { await classService.leaveClass() }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewEntry = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Leave class", role: .destructive) {
                    Task { await classService.leaveClass() }
                }
            }
        }
        .sheet(isPresented: $showingNewEntry) {
            NewEntrySheet()
        }
    }

    private func avatar(for entry: CareEntry) -> String {
        classService.members.first { $0.id == entry.authorID }?.avatar ?? "🌱"
    }
}

struct EntryRow: View {
    let entry: CareEntry
    let avatar: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(avatar).font(.title)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.authorNickname).bold()
                    Spacer()
                    Text(entry.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Label("\(entry.kind.title) · \(entry.plantName)", systemImage: entry.kind.symbol)
                    .font(.subheadline)
                    .foregroundStyle(.green)
                if !entry.note.isEmpty {
                    Text(entry.note)
                }
                if let data = entry.thumbnail, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct NewEntrySheet: View {
    @EnvironmentObject private var classService: ClassService
    @Environment(\.dismiss) private var dismiss

    @AppStorage("lastPlantName") private var plantName = ""
    @State private var kind: CareEntry.Kind = .water
    @State private var note = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photo: UIImage?
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Plant") {
                    TextField("Plant name", text: $plantName)
                }

                Section("What happened?") {
                    Picker("Type", selection: $kind) {
                        ForEach(CareEntry.Kind.allCases, id: \.self) { kind in
                            Label(kind.title, systemImage: kind.symbol).tag(kind)
                        }
                    }
                    TextField(kind.prompt, text: $note, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Photo (optional)") {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(photo == nil ? "Add a photo of your plant" : "Change photo", systemImage: "photo")
                    }
                    if let photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                    }
                }

                if let errorText {
                    Text(errorText).foregroundStyle(.red)
                }
            }
            .navigationTitle("New post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { post() }
                        .disabled(plantName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: photoItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        photo = UIImage(data: data)
                    }
                }
            }
        }
    }

    private func post() {
        do {
            try classService.addEntry(
                plantName: plantName.trimmingCharacters(in: .whitespaces),
                kind: kind,
                note: note,
                photo: photo
            )
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

extension CareEntry.Kind {
    var title: String {
        switch self {
        case .water:      return "Watered"
        case .move:       return "Moved"
        case .repot:      return "Repotted"
        case .fertilize:  return "Fertilized"
        case .photo:      return "Photo"
        case .problem:    return "Problem"
        case .reflection: return "Reflection"
        }
    }

    var symbol: String {
        switch self {
        case .water:      return "drop.fill"
        case .move:       return "sun.max"
        case .repot:      return "shippingbox"
        case .fertilize:  return "leaf"
        case .photo:      return "camera"
        case .problem:    return "exclamationmark.triangle"
        case .reflection: return "text.bubble"
        }
    }

    var prompt: String {
        switch self {
        case .water:      return "Why did you water today? (e.g. soil was dry 2 cm down)"
        case .move:       return "Where did you move it, and why?"
        case .repot:      return "Why did it need a new pot?"
        case .fertilize:  return "What did you use, and why now?"
        case .photo:      return "What do you notice about your plant today?"
        case .problem:    return "What happened? What do you think caused it? What did you do?"
        case .reflection: return "What have you learned? What would you do differently?"
        }
    }
}
