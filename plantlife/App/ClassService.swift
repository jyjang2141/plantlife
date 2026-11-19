//
//  ClassService.swift
//  Classroom mode backed by Firebase (Firestore + Anonymous Auth).
//
//  Firestore layout:
//    classes/{CODE}                      -> ClassGroup     (CODE looks like "KLM-482")
//    classes/{CODE}/members/{uid}        -> Member
//    classes/{CODE}/entries/{autoID}     -> CareEntry
//

import Foundation
import Combine
import UIKit
import FirebaseAuth
import FirebaseFirestore

struct ClassGroup: Codable {
    var name: String
    var createdBy: String
    var createdAt: Date
}

struct Member: Codable, Identifiable {
    @DocumentID var id: String?
    var nickname: String
    var avatar: String
    var joinedAt: Date
}

struct CareEntry: Codable, Identifiable {
    enum Kind: String, Codable, CaseIterable {
        case water, move, repot, fertilize, photo, problem, reflection
    }

    @DocumentID var id: String?
    var authorID: String
    var authorNickname: String
    var plantName: String
    var kind: Kind
    var note: String
    var createdAt: Date
    var thumbnail: Data?
}

enum ClassError: LocalizedError {
    case notSignedIn, classNotFound, notInClass, couldNotMakeCode

    var errorDescription: String? {
        switch self {
        case .notSignedIn:      return "Couldn't sign in. Check your internet connection."
        case .classNotFound:    return "No class found with that code."
        case .notInClass:       return "Join a class first."
        case .couldNotMakeCode: return "Couldn't create a class code. Try again."
        }
    }
}

@MainActor
final class ClassService: ObservableObject {
    @Published private(set) var classCode: String?
    @Published private(set) var className: String?
    @Published private(set) var members: [Member] = []
    @Published private(set) var entries: [CareEntry] = []
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    private var retryTask: Task<Void, Never>?
    private let savedCodeKey = "savedClassCode"

    var uid: String? { Auth.auth().currentUser?.uid }
    var myNickname: String? { members.first { $0.id == uid }?.nickname }

    func signIn() async throws {
        if Auth.auth().currentUser == nil {
            _ = try await Auth.auth().signInAnonymously()
        }
    }

    func restore() async {
        guard let code = UserDefaults.standard.string(forKey: savedCodeKey) else { return }
        do {
            try await signIn()
            try await enter(code: code)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createClass(name: String, nickname: String, avatar: String) async throws -> String {
        try await signIn()
        guard let uid else { throw ClassError.notSignedIn }

        for _ in 0..<5 {
            let code = Self.makeCode()
            let ref = db.collection("classes").document(code)
            if try await ref.getDocument().exists { continue }

            // Wait for each write to reach the server before listening,
            // so the security rules already see this student as a member.
            let group = ClassGroup(name: name, createdBy: uid, createdAt: .now)
            try await ref.setData(Firestore.Encoder().encode(group))
            try await addSelfAsMember(code: code, nickname: nickname, avatar: avatar)
            try await enter(code: code)
            return code
        }
        throw ClassError.couldNotMakeCode
    }

    func joinClass(code rawCode: String, nickname: String, avatar: String) async throws {
        try await signIn()
        let code = Self.formatCode(rawCode)

        let snapshot = try await db.collection("classes").document(code).getDocument()
        guard snapshot.exists else { throw ClassError.classNotFound }

        try await addSelfAsMember(code: code, nickname: nickname, avatar: avatar)
        try await enter(code: code)
    }

    func leaveClass() async {
        if let code = classCode, let uid {
            try? await db.collection("classes").document(code)
                .collection("members").document(uid).delete()
        }
        stopListening()
        classCode = nil
        className = nil
        members = []
        entries = []
        errorMessage = nil
        UserDefaults.standard.removeObject(forKey: savedCodeKey)
    }

    func addEntry(plantName: String, kind: CareEntry.Kind, note: String, photo: UIImage? = nil) throws {
        guard let code = classCode, let uid else { throw ClassError.notInClass }

        let entry = CareEntry(
            authorID: uid,
            authorNickname: myNickname ?? "Student",
            plantName: plantName,
            kind: kind,
            note: note,
            createdAt: .now,
            thumbnail: photo.flatMap(Self.makeThumbnail)
        )
        _ = try db.collection("classes").document(code)
            .collection("entries").addDocument(from: entry)
    }

    func entries(for memberID: String) -> [CareEntry] {
        entries.filter { $0.authorID == memberID }
    }

    private func addSelfAsMember(code: String, nickname: String, avatar: String) async throws {
        guard let uid else { throw ClassError.notSignedIn }
        let member = Member(nickname: nickname, avatar: avatar, joinedAt: .now)
        try await db.collection("classes").document(code)
            .collection("members").document(uid)
            .setData(Firestore.Encoder().encode(member))
    }

    private func enter(code: String) async throws {
        let snapshot = try await db.collection("classes").document(code).getDocument()
        guard snapshot.exists else {
            UserDefaults.standard.removeObject(forKey: savedCodeKey)
            throw ClassError.classNotFound
        }
        className = try? snapshot.data(as: ClassGroup.self).name
        classCode = code
        UserDefaults.standard.set(code, forKey: savedCodeKey)
        startListening(code: code)
    }

    // Live listeners: when anyone in the class posts, every phone updates.
    // If a listener is refused or drops, it reconnects automatically.
    private func startListening(code: String) {
        stopListening()
        let classRef = db.collection("classes").document(code)

        listeners.append(
            classRef.collection("members")
                .order(by: "joinedAt")
                .addSnapshotListener { [weak self] snapshot, error in
                    Task { @MainActor in
                        guard let self else { return }
                        if let error {
                            self.errorMessage = error.localizedDescription
                            self.retryListening(code: code)
                            return
                        }
                        self.errorMessage = nil
                        self.members = snapshot?.documents.compactMap { try? $0.data(as: Member.self) } ?? []
                    }
                }
        )

        listeners.append(
            classRef.collection("entries")
                .order(by: "createdAt", descending: true)
                .limit(to: 200)
                .addSnapshotListener { [weak self] snapshot, error in
                    Task { @MainActor in
                        guard let self else { return }
                        if let error {
                            self.errorMessage = error.localizedDescription
                            self.retryListening(code: code)
                            return
                        }
                        self.entries = snapshot?.documents.compactMap { try? $0.data(as: CareEntry.self) } ?? []
                    }
                }
        )
    }

    private func retryListening(code: String) {
        guard retryTask == nil else { return }
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self else { return }
            self.retryTask = nil
            if self.classCode == code { self.startListening(code: code) }
        }
    }

    private func stopListening() {
        retryTask?.cancel()
        retryTask = nil
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    // Codes look like "KLM-482": 3 letters with no vowels (so they can't spell words)
    // and 3 digits, skipping look-alikes like 0/O and 1/I.
    nonisolated static func makeCode() -> String {
        let letters = Array("BCDFGHJKLMNPQRSTVWXZ")
        let digits = Array("23456789")
        let blockedLetters: Set<String> = ["FCK", "FKK", "KKK", "WTF", "STD", "DCK", "CNT",
                                           "FGT", "NGR", "PNS", "SHT", "TTS", "KYS", "KMS",
                                           "CCK", "SXX", "XXX", "GTF", "PSS"]
        while true {
            let l = String((0..<3).map { _ in letters.randomElement()! })
            let d = String((0..<3).map { _ in digits.randomElement()! })
            if blockedLetters.contains(l) || d.contains("69") || d == "666" || d == "420" { continue }
            return l + "-" + d
        }
    }

    // Turns whatever a kid types ("klm482", "KLM 482", "klm-482") into "KLM-482".
    nonisolated static func formatCode(_ raw: String) -> String {
        let s = String(raw.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.prefix(6))
        return s.count > 3 ? String(s.prefix(3)) + "-" + String(s.dropFirst(3)) : s
    }

    static func makeThumbnail(_ image: UIImage) -> Data? {
        let maxSide: CGFloat = 480
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.6)
    }
}
