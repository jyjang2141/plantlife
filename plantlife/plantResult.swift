import SwiftUI

/// Shows what the AI found: the plant's name up top, then facts in small cards.
struct PlantResultView: View {
    let info: PlantInfo

    var body: some View {
        if info.isPlant {
            plantContent
        } else {
            notAPlant
        }
    }

    // MARK: Plant found

    private var plantContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            nameBlock

            if let summary = info.summary, !summary.isEmpty {
                Text(summary)
                    .font(.system(.body, design: .rounded))
                    .padding(.horizontal, 4)
            }

            if let fact = info.funFact, !fact.isEmpty {
                InfoCard(title: "Fun fact", icon: "sparkles", tint: Theme.sun) {
                    Text(fact)
                }
            }

            if let place = info.whereItGrows, !place.isEmpty {
                InfoCard(title: "Where it grows", icon: "globe.americas.fill", tint: Theme.leaf) {
                    Text(place)
                }
            }

            if let needs = info.needs {
                InfoCard(title: "What it needs", icon: "heart.fill", tint: Theme.leaf) {
                    VStack(alignment: .leading, spacing: 12) {
                        if let sunlight = needs.sunlight {
                            NeedRow(icon: "sun.max.fill", color: Theme.sun, label: "Sunlight", text: sunlight)
                        }
                        if let water = needs.water {
                            NeedRow(icon: "drop.fill", color: Theme.water, label: "Water", text: water)
                        }
                        if let soil = needs.soil {
                            NeedRow(icon: "mountain.2.fill", color: Theme.leaf, label: "Soil", text: soil)
                        }
                    }
                }
            }

            if let dangers = info.dangers, !dangers.isEmpty {
                InfoCard(title: "What can hurt it", icon: "cloud.bolt.rain.fill", tint: Theme.alert) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(dangers, id: \.self) { danger in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundStyle(Theme.alert)
                                Text(danger)
                            }
                        }
                    }
                }
            }

            if let note = info.safetyNote, !note.isEmpty {
                InfoCard(title: "Stay safe", icon: "hand.raised.fill", tint: .orange) {
                    Text(note)
                }
            }
        }
    }

    /// The one bold moment on the screen: the plant's name on a solid leaf-green block.
    private var nameBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(info.commonName ?? "Mystery plant")
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))

            if let scientific = info.scientificName, !scientific.isEmpty {
                Text(scientific)
                    .font(.system(.title3, design: .serif))
                    .italic()
                    .opacity(0.9)
            }

            Text(confidenceText)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.22))
                .clipShape(Capsule())
                .padding(.top, 6)
        }
        .foregroundStyle(Color.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Theme.leaf)
        .clipShape(Theme.cardShape)
    }

    private var confidenceText: String {
        switch info.confidence {
        case "high":   return "I'm pretty sure about this one"
        case "medium": return "I think this is right"
        default:       return "Not sure. Try a closer photo of a leaf or flower"
        }
    }

    // MARK: Not a plant

    private var notAPlant: some View {
        InfoCard(title: "I don't see a plant", icon: "questionmark.circle.fill", tint: Theme.water) {
            Text(info.message ?? "Try taking a photo where the plant fills more of the picture.")
        }
    }
}

// MARK: - Building blocks

private struct InfoCard<Content: View>: View {
    let title: String
    let icon: String
    let tint: Color
    let content: Content

    init(title: String, icon: String, tint: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(tint)
            content
                .font(.system(.body, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.card)
        .clipShape(Theme.cardShape)
    }
}

private struct NeedRow: View {
    let icon: String
    let color: Color
    let label: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                Text(text)
                    .font(.system(.subheadline, design: .rounded))
            }
        }
    }
}
