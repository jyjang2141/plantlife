//
//  LearnView.swift
//  plantlife
//
//  The Learn tab: what plants need to grow.
//

import SwiftUI

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
